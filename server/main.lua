--[[
    Titan Scripts - Pizza Delivery Job
    Server-side logic
    https://github.com/titan-scripts/titan-pizzadelivery
    ---------------------------------------------------------------------
    Every fact that matters for progression or payout is decided and
    stored here, never on the client:

      - which delivery locations are active for a session (randomised
        server-side, client only ever receives the current target)
      - whether the player is actually close enough to interact
      - how much money/XP is paid (comes from Config, never from a
        client-supplied number)
      - whether the pizza item is actually consumed from the inventory
      - level/XP persistence in MySQL

    The client is only responsible for visuals: spawning the vehicle/ped,
    playing animations, and asking the server "can I do this now?".
]]

local Sessions = {}     -- [source] = session table, see startJob callback
local PlayerData = {}   -- [source] = cached row from pizza_delivery_players

-- ═══════════════════════════════════════════════════════════════════
-- MONEY HANDLING (isolated in one place - swap this out if your
-- framework uses ESX/QBCore bank functions instead of an inventory item)
-- ═══════════════════════════════════════════════════════════════════

local function AddMoney(src, amount)
    exports.ox_inventory:AddItem(src, 'money', amount)
end

-- ═══════════════════════════════════════════════════════════════════
-- PERSISTENCE
-- ═══════════════════════════════════════════════════════════════════

local function getIdentifier(src)
    return GetPlayerIdentifierByType(src, 'license') or ('src:' .. src)
end

local function loadPlayer(src)
    local identifier = getIdentifier(src)
    local result = MySQL.single.await('SELECT * FROM pizza_delivery_players WHERE identifier = ?', { identifier })

    if not result then
        MySQL.insert.await('INSERT INTO pizza_delivery_players (identifier, level, xp, total_deliveries, total_earned) VALUES (?, 1, 0, 0, 0)', { identifier })
        result = { identifier = identifier, level = 1, xp = 0, total_deliveries = 0, total_earned = 0 }
    end

    PlayerData[src] = result
end

local function getPlayerData(src)
    if not PlayerData[src] then
        loadPlayer(src)
    end
    return PlayerData[src]
end

local function savePlayer(src)
    local pdata = PlayerData[src]
    if not pdata then return end
    MySQL.update.await(
        'UPDATE pizza_delivery_players SET level = ?, xp = ?, total_deliveries = ?, total_earned = ? WHERE identifier = ?',
        { pdata.level, pdata.xp, pdata.total_deliveries, pdata.total_earned, pdata.identifier }
    )
end

-- ═══════════════════════════════════════════════════════════════════
-- VALIDATION HELPERS
-- ═══════════════════════════════════════════════════════════════════

local function getPedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function isNear(src, coords, maxDist)
    local pedCoords = getPedCoords(src)
    if not pedCoords then return false end
    return #(pedCoords - coords) <= maxDist
end

local function cleanupVehicle(session)
    if not session or not session.vehicleNetId then return end
    local veh = NetworkGetEntityFromNetworkId(session.vehicleNetId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- ITEM CLEANUP
-- Universal helper for ending an in-progress job that was not
-- completed properly (manual cancel, disconnect, or timeout). Checks
-- how many pizza boxes the player is currently holding and strips all
-- of them, so no delivery items are ever left behind once a session
-- is torn down.
-- ═══════════════════════════════════════════════════════════════════

local function removeAllPizzaBoxes(src)
    local count = exports.ox_inventory:GetItemCount(src, Config.Item.pizzaBox)
    if not count or count < 1 then return end

    exports.ox_inventory:RemoveItem(src, Config.Item.pizzaBox, count)
end

-- ═══════════════════════════════════════════════════════════════════
-- CALLBACK: START JOB
-- ═══════════════════════════════════════════════════════════════════

lib.callback.register('pizza:startJob', function(source)
    local src = source

    if Sessions[src] then
        return false, 'You already have an active delivery job.'
    end

    if not isNear(src, Config.JobLocation.coords, Config.Distances.startJob + 1.0) then
        return false, 'You are too far away to start the job.'
    end

    local pdata = getPlayerData(src)
    local levelCfg = Config.Levels[pdata.level] or Config.Levels[1]

    -- shuffle the location pool and take however many pizzas this level requires
    local pool = {}
    for i, loc in ipairs(Config.DeliveryLocations) do pool[i] = loc end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local count = math.min(levelCfg.pizzas, #pool)
    local queue = {}
    for i = 1, count do queue[i] = pool[i] end

    Sessions[src] = {
        level = pdata.level,
        pizzasRequired = count,
        deliveriesDone = 0,
        queue = queue,
        currentIndex = 1,
        vehicleNetId = nil,
        phase = 'awaiting_vehicle',
        jobStartTime = GetGameTimer(),
        deliveryIssuedTime = nil,
        sessionXp = 0,
        sessionMoney = 0
    }

    exports.ox_inventory:AddItem(src, Config.Item.pizzaBox, count)

    return true, {
        vehicleModel = Config.Vehicle.model,
        spawnCoords = Config.Vehicle.spawnOffset,
        pizzasRequired = count,
        firstDelivery = queue[1].coords,
        firstHeading = queue[1].heading
    }
end)

-- ═══════════════════════════════════════════════════════════════════
-- VEHICLE CONFIRMATION
-- Client tells us the netId of the vehicle it spawned; we validate the
-- model matches what we authorised before trusting it as "the job vehicle".
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('pizza:confirmVehicle', function(netId)
    local src = source
    local session = Sessions[src]
    if not session or session.phase ~= 'awaiting_vehicle' then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end

    if GetEntityModel(veh) ~= Config.Vehicle.model then
        print(('[titan-pizzadelivery] Player %s tried to confirm an invalid vehicle model, cancelling job.'):format(src))
        Sessions[src] = nil
        TriggerClientEvent('pizza:jobTimedOut', src)
        return
    end

    session.vehicleNetId = netId
    session.phase = 'delivering'
    session.deliveryIssuedTime = GetGameTimer()
    SetVehicleNumberPlateText(veh, Config.Vehicle.plateTag .. tostring(src))
end)

-- ═══════════════════════════════════════════════════════════════════
-- CALLBACK: DELIVER PIZZA
-- ═══════════════════════════════════════════════════════════════════

lib.callback.register('pizza:deliverPizza', function(source)
    local src = source
    local session = Sessions[src]

    if not session or session.phase ~= 'delivering' then
        return false, 'You do not have an active delivery.'
    end

    local currentLoc = session.queue[session.currentIndex]
    if not currentLoc then
        return false, 'Delivery data error, please cancel the job.'
    end

    if not isNear(src, currentLoc.coords, Config.Distances.deliver + 1.0) then
        return false, 'You are not at the correct delivery location.'
    end

    local now = GetGameTimer()
    if session.deliveryIssuedTime and (now - session.deliveryIssuedTime) < Config.MinDeliveryInterval then
        return false, 'Slow down, that was too fast.'
    end

    -- the pizza is only ever consumed server-side - the client cannot
    -- fake having delivered something it does not actually hold
    local removed = exports.ox_inventory:RemoveItem(src, Config.Item.pizzaBox, 1)
    if not removed then
        return false, 'You do not have a pizza to deliver.'
    end

    local levelCfg = Config.Levels[session.level] or Config.Levels[1]
    local xpGain = levelCfg.xpPerDelivery
    local speedBonus = false

    if Config.SpeedBonus.enabled and session.deliveryIssuedTime and (now - session.deliveryIssuedTime) <= Config.SpeedBonus.timeLimit then
        xpGain = xpGain + Config.SpeedBonus.bonusXp
        speedBonus = true
    end

    AddMoney(src, levelCfg.moneyPerDelivery)

    session.deliveriesDone = session.deliveriesDone + 1
    session.sessionXp = session.sessionXp + xpGain
    session.sessionMoney = session.sessionMoney + levelCfg.moneyPerDelivery
    session.currentIndex = session.currentIndex + 1
    session.deliveryIssuedTime = now

    local nextLoc = session.queue[session.currentIndex]
    local done = nextLoc == nil

    if done then
        session.phase = 'returning'
    end

    return true, {
        done = done,
        nextCoords = nextLoc and nextLoc.coords or nil,
        nextHeading = nextLoc and nextLoc.heading or nil,
        moneyEarned = levelCfg.moneyPerDelivery,
        xpEarned = xpGain,
        speedBonus = speedBonus,
        deliveriesDone = session.deliveriesDone,
        pizzasRequired = session.pizzasRequired
    }
end)

-- ═══════════════════════════════════════════════════════════════════
-- CALLBACK: FINISH JOB
-- ═══════════════════════════════════════════════════════════════════

lib.callback.register('pizza:finishJob', function(source)
    local src = source
    local session = Sessions[src]

    if not session or session.phase ~= 'returning' then
        return false, 'You still have deliveries remaining.'
    end

    if not isNear(src, Config.JobLocation.coords, Config.Distances.returnVehicle + 1.0) then
        return false, 'Return to the pizza shop first.'
    end

    if session.vehicleNetId then
        local veh = NetworkGetEntityFromNetworkId(session.vehicleNetId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local vehCoords = GetEntityCoords(veh)
            if #(vehCoords - Config.JobLocation.coords) > Config.Distances.vehicleEnter then
                return false, 'The delivery vehicle needs to be brought back to the shop.'
            end
            DeleteEntity(veh)
        end
    end

    local pdata = getPlayerData(src)
    pdata.xp = pdata.xp + session.sessionXp
    pdata.total_deliveries = pdata.total_deliveries + session.deliveriesDone
    pdata.total_earned = pdata.total_earned + session.sessionMoney

    local leveledUp = false
    local levelCfg = Config.Levels[pdata.level]

    while levelCfg and levelCfg.xpToNext and pdata.xp >= levelCfg.xpToNext do
        pdata.xp = pdata.xp - levelCfg.xpToNext
        pdata.level = pdata.level + 1
        leveledUp = true
        levelCfg = Config.Levels[pdata.level]
    end

    savePlayer(src)

    local summary = {
        deliveriesDone = session.deliveriesDone,
        xpGained = session.sessionXp,
        moneyGained = session.sessionMoney,
        leveledUp = leveledUp,
        newLevel = pdata.level
    }

    Sessions[src] = nil
    return true, summary
end)

-- ═══════════════════════════════════════════════════════════════════
-- CALLBACK: STATS
-- ═══════════════════════════════════════════════════════════════════

lib.callback.register('pizza:getStats', function(source)
    local pdata = getPlayerData(source)
    local levelCfg = Config.Levels[pdata.level]

    return {
        level = pdata.level,
        xp = pdata.xp,
        xpToNext = levelCfg and levelCfg.xpToNext or nil,
        totalDeliveries = pdata.total_deliveries,
        totalEarned = pdata.total_earned
    }
end)

-- ═══════════════════════════════════════════════════════════════════
-- SELF-SERVICE CANCEL (in case a player gets stuck, e.g. lost vehicle)
-- ═══════════════════════════════════════════════════════════════════

RegisterCommand('canceldelivery', function(source)
    local src = source
    local session = Sessions[src]
    if not session then return end

    cleanupVehicle(session)
    removeAllPizzaBoxes(src)
    Sessions[src] = nil
    TriggerClientEvent('pizza:jobTimedOut', src)
end, false)

-- ═══════════════════════════════════════════════════════════════════
-- CLEANUP: disconnects and stale/abandoned jobs
-- ═══════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function()
    local src = source
    if Sessions[src] then
        cleanupVehicle(Sessions[src])
        removeAllPizzaBoxes(src)
        Sessions[src] = nil
    end
    PlayerData[src] = nil
end)

CreateThread(function()
    while true do
        Wait(60000)
        local now = GetGameTimer()
        for src, session in pairs(Sessions) do
            if (now - session.jobStartTime) > Config.MaxJobTime then
                cleanupVehicle(session)
                removeAllPizzaBoxes(src)
                TriggerClientEvent('pizza:jobTimedOut', src)
                Sessions[src] = nil
            end
        end
    end
end)
