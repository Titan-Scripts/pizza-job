--[[
    Titan Scripts - Pizza Delivery Job
    Client-side logic
    https://github.com/titan-scripts/titan-pizzadelivery
    ---------------------------------------------------------------------
    Purely presentational: spawns peds/vehicles/blips and asks the server
    whether an action is allowed. No money or XP values are ever decided
    here - everything shown to the player comes back from a server
    callback response.
]]

local jobPed = nil
local jobBlip = nil
local jobVehicle = nil
local deliveryPed = nil
local deliveryBlip = nil

local inJob = false
local pizzasRequired = 0
local deliveriesDone = 0

local function notify(msg, type)
    lib.notify({ description = msg, type = type or 'inform' })
end

local function loadModel(model)
    lib.requestModel(model, 10000)
    return model
end

-- ═══════════════════════════════════════════════════════════════════
-- JOB NPC + BLIP (created once on resource start)
-- ═══════════════════════════════════════════════════════════════════

local function createJobPed()
    if DoesEntityExist(jobPed) then return end

    local model = loadModel(Config.JobLocation.pedModel)
    local c = Config.JobLocation.coords

    jobPed = CreatePed(4, model, c.x, c.y, c.z - 1.0, Config.JobLocation.heading, false, true)
    SetEntityAsMissionEntity(jobPed, true, true)
    FreezeEntityPosition(jobPed, true)
    SetEntityInvincible(jobPed, true)
    SetBlockingOfNonTemporaryEvents(jobPed, true)
    TaskStartScenarioInPlace(jobPed, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    exports.ox_target:addLocalEntity(jobPed, {
        {
            name = 'pizza_start_job',
            icon = 'fas fa-pizza-slice',
            label = 'Start Delivery Job',
            distance = 2.5,
            canInteract = function() return not inJob end,
            onSelect = function() StartJob() end
        },
        {
            name = 'pizza_finish_job',
            icon = 'fas fa-box',
            label = 'Return Vehicle & Finish',
            distance = 2.5,
            canInteract = function() return inJob and deliveriesDone >= pizzasRequired and pizzasRequired > 0 end,
            onSelect = function() FinishJob() end
        }
    })
end

local function createJobBlip()
    local c = Config.JobLocation.coords
    jobBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(jobBlip, Config.JobLocation.blip.sprite)
    SetBlipColour(jobBlip, Config.JobLocation.blip.color)
    SetBlipScale(jobBlip, Config.JobLocation.blip.scale)
    SetBlipAsShortRange(jobBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.JobLocation.blip.label)
    EndTextCommandSetBlipName(jobBlip)
end

CreateThread(function()
    createJobPed()
    createJobBlip()
end)

-- ═══════════════════════════════════════════════════════════════════
-- START JOB
-- ═══════════════════════════════════════════════════════════════════

function StartJob()
    local ok, result = lib.callback.await('pizza:startJob', false)
    if not ok then
        notify(result or 'Unable to start the job.', 'error')
        return
    end

    inJob = true
    pizzasRequired = result.pizzasRequired
    deliveriesDone = 0

    notify(('New job: deliver %d pizza(s). Grab the delivery vehicle!'):format(pizzasRequired), 'success')

    SpawnVehicle(result.vehicleModel)
    CreateDeliveryPoint(result.firstDelivery, result.firstHeading)
end

function SpawnVehicle(modelHash)
    loadModel(modelHash)
    local sp = Config.Vehicle.spawnOffset

    jobVehicle = CreateVehicle(modelHash, sp.x, sp.y, sp.z, sp.w, true, false)
    SetEntityAsMissionEntity(jobVehicle, true, true)
    SetVehicleFuelLevel(jobVehicle, Config.Vehicle.fuel + 0.0)
    SetVehicleDirtLevel(jobVehicle, 0.0)
    SetVehicleOnGroundProperly(jobVehicle)
    SetVehicleEngineOn(jobVehicle, true, true, false)

    local netId = NetworkGetNetworkIdFromEntity(jobVehicle)
    TriggerServerEvent('pizza:confirmVehicle', netId)

    exports.ox_target:addLocalEntity(jobVehicle, {
        {
            name = 'pizza_enter_delivery_vehicle',
            icon = 'fas fa-key',
            label = 'Enter Delivery Vehicle',
            distance = 3.0,
            onSelect = function()
                TaskEnterVehicle(PlayerPedId(), jobVehicle, 5000, -1, 1.0, 1, 0)
            end
        }
    })
end

-- ═══════════════════════════════════════════════════════════════════
-- DELIVERY POINT (single active NPC/blip at a time)
-- ═══════════════════════════════════════════════════════════════════

function CreateDeliveryPoint(coords, heading)
    if DoesEntityExist(deliveryPed) then
        exports.ox_target:removeLocalEntity(deliveryPed)
        DeleteEntity(deliveryPed)
        deliveryPed = nil
    end
    if deliveryBlip then RemoveBlip(deliveryBlip) deliveryBlip = nil end

    local model = loadModel(Config.DeliveryPedModel)
    deliveryPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, heading, false, true)
    SetEntityAsMissionEntity(deliveryPed, true, true)
    FreezeEntityPosition(deliveryPed, true)
    SetEntityInvincible(deliveryPed, true)
    SetBlockingOfNonTemporaryEvents(deliveryPed, true)
    TaskStartScenarioInPlace(deliveryPed, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    deliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipColour(deliveryBlip, 5)
    SetBlipRoute(deliveryBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Pizza Delivery')
    EndTextCommandSetBlipName(deliveryBlip)

    exports.ox_target:addLocalEntity(deliveryPed, {
        {
            name = 'pizza_deliver',
            icon = 'fas fa-pizza-slice',
            label = 'Deliver Pizza',
            distance = 2.5,
            onSelect = function() DeliverPizza() end
        }
    })
end

function DeliverPizza()
    local completed = lib.progressBar({
        duration = 3000,
        label = 'Delivering pizza...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mp_common', clip = 'givetake1_a' }
    })
    if not completed then return end

    local ok, data = lib.callback.await('pizza:deliverPizza', false)
    if not ok then
        notify(data or 'Delivery failed.', 'error')
        return
    end

    deliveriesDone = data.deliveriesDone

    local msg = ('Delivered! +$%d, +%d XP'):format(data.moneyEarned, data.xpEarned)
    if data.speedBonus then msg = msg .. ' (speed bonus!)' end
    notify(msg, 'success')

    if data.done then
        if DoesEntityExist(deliveryPed) then
            exports.ox_target:removeLocalEntity(deliveryPed)
            DeleteEntity(deliveryPed)
            deliveryPed = nil
        end
        if deliveryBlip then RemoveBlip(deliveryBlip) deliveryBlip = nil end
        if jobBlip then SetBlipRoute(jobBlip, true) end
        notify('All pizzas delivered! Return the vehicle to the shop.', 'success')
    else
        CreateDeliveryPoint(data.nextCoords, data.nextHeading)
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- FINISH JOB
-- ═══════════════════════════════════════════════════════════════════

function FinishJob()
    local ok, result = lib.callback.await('pizza:finishJob', false)
    if not ok then
        notify(result or 'Could not finish the job.', 'error')
        return
    end

    inJob = false
    pizzasRequired = 0
    deliveriesDone = 0

    if DoesEntityExist(jobVehicle) then
        exports.ox_target:removeLocalEntity(jobVehicle)
        -- entity is deleted server-side (networked), just drop the reference
        jobVehicle = nil
    end
    if jobBlip then SetBlipRoute(jobBlip, false) end

    local msg = ('Job complete! %d deliveries, +$%d, +%d XP'):format(result.deliveriesDone, result.moneyGained, result.xpGained)
    if result.leveledUp then
        msg = msg .. (' -- LEVEL UP! You are now level %d'):format(result.newLevel)
    end
    notify(msg, 'success')
end

RegisterNetEvent('pizza:jobTimedOut', function()
    inJob = false
    pizzasRequired = 0
    deliveriesDone = 0

    if DoesEntityExist(deliveryPed) then
        exports.ox_target:removeLocalEntity(deliveryPed)
        DeleteEntity(deliveryPed)
        deliveryPed = nil
    end
    if deliveryBlip then RemoveBlip(deliveryBlip) deliveryBlip = nil end

    if DoesEntityExist(jobVehicle) then
        exports.ox_target:removeLocalEntity(jobVehicle)
        jobVehicle = nil
    end

    if jobBlip then SetBlipRoute(jobBlip, false) end

    notify('Your delivery job was cancelled.', 'error')
end)

-- ═══════════════════════════════════════════════════════════════════
-- UTILITY COMMANDS
-- ═══════════════════════════════════════════════════════════════════

RegisterCommand('pizzastats', function()
    local stats = lib.callback.await('pizza:getStats', false)
    if not stats then return end

    local xpNext = stats.xpToNext and (' / ' .. stats.xpToNext) or ' (MAX LEVEL)'
    lib.notify({
        description = ('Level %d -- XP: %d%s\nTotal deliveries: %d\nTotal earned: $%d')
            :format(stats.level, stats.xp, xpNext, stats.totalDeliveries, stats.totalEarned),
        type = 'inform',
        duration = 8000
    })
end, false)

-- cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for _, ent in ipairs({ jobPed, deliveryPed, jobVehicle }) do
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    if jobBlip then RemoveBlip(jobBlip) end
    if deliveryBlip then RemoveBlip(deliveryBlip) end
end)
