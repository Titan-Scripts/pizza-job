--[[
    Titan Scripts - Pizza Delivery Job
    Configuration file
    https://github.com/titan-scripts/titan-pizzadelivery
]]

Config = {}

-- ═══════════════════════════════════════════════════════════════════
-- GENERAL
-- ═══════════════════════════════════════════════════════════════════

Config.Debug = false

-- ═══════════════════════════════════════════════════════════════════
-- JOB START LOCATION (NPC that starts/ends the job)
-- ═══════════════════════════════════════════════════════════════════

Config.JobLocation = {
    coords = vec3(-619.59, -230.68, 38.06),   -- Pizza This That, Vespucci
    heading = 300.0,
    pedModel = `a_m_m_bevhills_01`,
    blip = {
        sprite = 314,
        color = 2,
        scale = 0.8,
        label = 'Pizza Delivery Job'
    }
}

-- ═══════════════════════════════════════════════════════════════════
-- DELIVERY VEHICLE
-- ═══════════════════════════════════════════════════════════════════

Config.Vehicle = {
    model = `pizzaboy`,
    plateTag = 'PIZZA',                        -- appended with the player's server id
    fuel = 100,
    spawnOffset = vec4(-624.75, -234.13, 37.86, 300.0)
}

-- ═══════════════════════════════════════════════════════════════════
-- DELIVERY LOCATIONS
-- The server randomly picks from this pool for every job. Never expose
-- the full pool logic to the client - only the currently active target
-- is ever sent down.
-- ═══════════════════════════════════════════════════════════════════

Config.DeliveryLocations = {
    { coords = vec3(-1358.16, -1272.68, 4.32),  heading = 180.0 },
    { coords = vec3(-1420.62, -536.02, 33.62),  heading = 260.0 },
    { coords = vec3(-269.66, -963.28, 31.22),   heading = 90.0  },
    { coords = vec3(120.19, -1290.55, 29.27),   heading = 200.0 },
    { coords = vec3(376.51, -1084.68, 29.29),   heading = 45.0  },
    { coords = vec3(-1077.65, -1445.65, 4.78),  heading = 310.0 },
    { coords = vec3(-1489.86, -430.61, 35.85),  heading = 130.0 },
    { coords = vec3(155.86, -1710.06, 29.29),   heading = 250.0 },
    { coords = vec3(-536.34, -205.71, 37.68),   heading = 160.0 },
    { coords = vec3(-1226.05, -906.85, 12.33),  heading = 30.0  }
}

Config.DeliveryPedModel = `a_f_y_beach_01`

-- ═══════════════════════════════════════════════════════════════════
-- SERVER-SIDE VALIDATION DISTANCES (metres)
-- ═══════════════════════════════════════════════════════════════════

Config.Distances = {
    startJob = 2.5,
    deliver = 2.5,
    returnVehicle = 4.0,
    vehicleEnter = 15.0   -- max distance the vehicle can be from the shop when finishing
}

-- Anti-abuse timers
Config.MaxJobTime = 20 * 60 * 1000            -- 20 minutes - job auto-cancels past this
Config.MinDeliveryInterval = 12 * 1000        -- fastest a delivery can be completed after the previous one

-- ═══════════════════════════════════════════════════════════════════
-- ITEMS (must also be registered in ox_inventory, see data/items.lua)
-- ═══════════════════════════════════════════════════════════════════

Config.Item = {
    pizzaBox = 'pizza_box'
}

-- ═══════════════════════════════════════════════════════════════════
-- LEVELING SYSTEM
-- pizzas          -> deliveries required to complete the job at this level
-- moneyPerDelivery-> cash paid instantly per successful delivery
-- xpPerDelivery   -> base XP earned per successful delivery
-- xpToNext        -> total XP required to reach the next level (nil = max level)
-- ═══════════════════════════════════════════════════════════════════

Config.Levels = {
    [1]  = { pizzas = 3,  moneyPerDelivery = 45,  xpPerDelivery = 20, xpToNext = 100  },
    [2]  = { pizzas = 4,  moneyPerDelivery = 55,  xpPerDelivery = 25, xpToNext = 250  },
    [3]  = { pizzas = 5,  moneyPerDelivery = 65,  xpPerDelivery = 30, xpToNext = 450  },
    [4]  = { pizzas = 6,  moneyPerDelivery = 75,  xpPerDelivery = 35, xpToNext = 700  },
    [5]  = { pizzas = 7,  moneyPerDelivery = 85,  xpPerDelivery = 40, xpToNext = 1000 },
    [6]  = { pizzas = 8,  moneyPerDelivery = 95,  xpPerDelivery = 45, xpToNext = 1400 },
    [7]  = { pizzas = 9,  moneyPerDelivery = 105, xpPerDelivery = 50, xpToNext = 1900 },
    [8]  = { pizzas = 10, moneyPerDelivery = 115, xpPerDelivery = 55, xpToNext = 2500 },
    [9]  = { pizzas = 11, moneyPerDelivery = 125, xpPerDelivery = 60, xpToNext = 3200 },
    [10] = { pizzas = 12, moneyPerDelivery = 140, xpPerDelivery = 70, xpToNext = nil  } -- max level
}

-- Reward players who deliver quickly after receiving a target
Config.SpeedBonus = {
    enabled = true,
    timeLimit = 90 * 1000,  -- 90 seconds
    bonusXp = 10
}
