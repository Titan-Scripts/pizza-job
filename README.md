<div align="center">

# 🍕 Titan Pizza Delivery
### by **Titan Scripts**

A free, server-authoritative Pizza Delivery job for FiveM — built on **ox_lib**, **ox_inventory**, and **ox_target**.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![FiveM](https://img.shields.io/badge/platform-FiveM-orange.svg)](https://fivem.net)
[![Standalone](https://img.shields.io/badge/framework-standalone-brightgreen.svg)](#-requirements)
[![Free](https://img.shields.io/badge/price-FREE-success.svg)](#)

[Features](#-features) • [Requirements](#-requirements) • [Installation](#-installation) • [Configuration](#%EF%B8%8F-configuration) • [Commands](#-commands) • [Security](#-security--anti-cheat) • [Support](#-support)

</div>

---

## 📖 About

**Titan Pizza Delivery** is a complete pizza delivery job for your FiveM server. Players start a shift at the pizzeria, grab a delivery vehicle, drive to a series of customers, hand off the pizza, and return the vehicle to get paid and level up.

It's built to be **safe to run on a live server**: every payout, delivery target, and item transaction is decided and verified on the server, never trusted from the client. It's also built to be **easy to read and extend** — clean, commented code with everything gameplay-related centralized in one config file.

This resource is **released for free** by Titan Scripts. Use it, modify it, and drop it into your server — no purchase, key, or escrow required.

---

## ✨ Features

- 🎯 **NPC-driven job flow** — talk to the pizzeria NPC to start, get handed a delivery vehicle and your pizzas.
- 📦 **Sequential deliveries** — drive to each customer, hand off the pizza via `ox_target`, get paid instantly, and the NPC despawns to reveal the next stop.
- 🚗 **Vehicle return** — bring the delivery vehicle back to the shop to wrap up the shift and bank your XP.
- 📈 **Persistent leveling system** — XP and levels are saved to MySQL. Higher levels mean more deliveries per shift, more money per delivery, and more XP per delivery.
- ⚡ **Speed bonus XP** — reward players who deliver quickly after receiving a target.
- 🧾 **Real inventory item** — pizza boxes are a genuine `ox_inventory` item players can carry, trade, or give away.
- 🧹 **Automatic cleanup** — leftover pizza boxes and the delivery vehicle are always cleaned up, whether the player finishes normally, cancels manually, disconnects mid-shift, or goes AFK past the time limit.
- 🛡️ **Server-authoritative by design** — see [Security & Anti-Cheat](#-security--anti-cheat) below.
- ⚙️ **Fully configurable** — locations, vehicle, leveling curve, distances, and timers all live in a single `config.lua`.

---

## 📋 Requirements

This resource is **standalone** — it does not require ESX, QBCore, or any other framework. It only needs:

| Dependency | Purpose | Link |
|---|---|---|
| **ox_lib** | Callbacks, notifications, progress bars | [overextended/ox_lib](https://github.com/overextended/ox_lib) |
| **ox_inventory** | Item storage, weight, trading | [overextended/ox_inventory](https://github.com/overextended/ox_inventory) |
| **ox_target** | Interaction targeting (peds/vehicles) | [overextended/ox_target](https://github.com/overextended/ox_target) |
| **oxmysql** | MySQL access for persistent leveling data | [overextended/oxmysql](https://github.com/overextended/oxmysql) |

> 💡 Running ESX or QBCore alongside these is fine — the script doesn't call into either framework directly. See [Adapting to your framework](#adapting-to-your-framework) if you'd rather pay out through your framework's bank system instead of `ox_inventory`'s `money` item.

---

## 📦 Installation

1. **Download** this repository (or `git clone`) into your server's `resources` folder.
2. **Rename** the folder to `titan-pizzadelivery` if it isn't already (this should match the folder name used in step 5).
3. **Import the database table** — run the contents of [`sql/install.sql`](sql/install.sql) against your database. This creates the `pizza_delivery_players` table used to store levels and XP.
4. **Register the item** — copy the item definition from [`data/items.lua`](data/items.lua) into your `ox_inventory/data/items.lua` (or a split item file, if your `ox_inventory` build supports the `data/items/` folder).
5. **Add it to your `server.cfg`**, after `ox_lib`, `ox_inventory`, `ox_target`, and `oxmysql`:

   ```cfg
   ensure ox_lib
   ensure ox_inventory
   ensure ox_target
   ensure oxmysql
   ensure titan-pizzadelivery
   ```

6. **Restart your server** (or `refresh` + `ensure titan-pizzadelivery` on a live server).
7. **Adjust `config.lua`** to match your map and economy — see [Configuration](#%EF%B8%8F-configuration) below. The default coordinates are placeholders in Los Santos and should be moved to wherever you want your pizzeria to live.

---

## ⚙️ Configuration

Everything gameplay-related lives in [`config.lua`](config.lua):

| Section | What it controls |
|---|---|
| `Config.JobLocation` | Where the job starts/ends — coordinates, ped model, and blip. |
| `Config.Vehicle` | Delivery vehicle model, spawn point/heading, and plate prefix. |
| `Config.DeliveryLocations` | Pool of possible delivery stops. The server randomly picks a subset per shift — add as many locations as you like. |
| `Config.DeliveryPedModel` | Ped model used for each customer. |
| `Config.Distances` | Server-side interaction distances (start job, deliver, return vehicle, etc.). |
| `Config.MaxJobTime` | How long a shift can run before it's auto-cancelled and cleaned up. |
| `Config.MinDeliveryInterval` | Minimum time allowed between two deliveries (anti-macro). |
| `Config.Item.pizzaBox` | The `ox_inventory` item name used for pizzas. |
| `Config.Levels` | The full leveling table — deliveries required, money per delivery, XP per delivery, and XP needed for the next level. Add as many levels as you want. |
| `Config.SpeedBonus` | Optional bonus XP for fast deliveries. |

Example of a level entry:

```lua
[1] = { pizzas = 3, moneyPerDelivery = 45, xpPerDelivery = 20, xpToNext = 100 },
```

This means: at level 1, a shift requires 3 deliveries, each pays $45 and 20 XP, and the player needs 100 total XP to reach level 2.

### Adapting to your framework

Money is paid out through `ox_inventory`'s `money` item by default. If your server uses ESX, QBCore, or another framework's bank/cash system instead, open `server/main.lua` and edit the single `AddMoney(src, amount)` function — every payout in the script routes through it, so that's the only place you need to change.

Player identity uses the FiveM `license` identifier by default. If you need a different identifier (e.g. a framework's citizen ID), adjust `getIdentifier()` in `server/main.lua`.

---

## 🎮 Commands

| Command | Description |
|---|---|
| `/pizzastats` | Shows your current level, XP, XP needed for the next level, total deliveries, and total lifetime earnings. |
| `/canceldelivery` | Manually cancels an active shift — returns/despawns the vehicle and clears any pizza boxes from your inventory. Useful if you get stuck (e.g. the vehicle is lost or destroyed). |

---

## 🔒 Security & Anti-Cheat

This script assumes the client can't be trusted with anything that touches money or progression. Specifically:

- **Delivery targets are chosen server-side**, randomly, from the configured location pool, and stored per-player. The client only ever receives the *current* target — never the full route.
- **Every distance check is re-verified on the server** using the player's actual networked position, not anything the client claims about itself.
- **Money and XP values never come from the client.** Every payout is looked up from `Config.Levels` server-side and paid through a single, auditable `AddMoney` function.
- **The pizza item is consumed server-side** before any payout — a client can't claim credit for a delivery it doesn't actually hold the item for.
- **The delivery vehicle is validated server-side**: the server checks the model of the vehicle the client claims to have spawned before trusting it as "the job vehicle."
- **A minimum delivery interval** blocks scripted/macro spam of the delivery callback.
- **A max shift duration** auto-cancels stale sessions, deleting the vehicle and clearing any pizza boxes so nothing can be farmed by leaving a shift open indefinitely.
- **Guaranteed inventory cleanup** — pizza boxes are stripped from the player's inventory whenever a shift ends without being completed properly: manual cancel, disconnect mid-shift, or timeout.

---

## 🗂️ File Structure

```
titan-pizzadelivery/
├── fxmanifest.lua        -- resource manifest & dependencies
├── config.lua             -- all tunable settings (locations, vehicle, leveling, timers)
├── client/
│   └── main.lua            -- peds, blips, vehicle spawning, target options, UI feedback
├── server/
│   └── main.lua            -- sessions, validation, payouts, persistence, cleanup
├── data/
│   └── items.lua            -- ox_inventory item definition to copy in
├── sql/
│   └── install.sql          -- database table for persistent levels/XP
├── LICENSE
└── README.md
```

---

## 🤝 Contributing

Issues and pull requests are welcome. If you find a bug or have an improvement, feel free to open an issue or submit a PR.

## 📜 License

Released under the [MIT License](LICENSE) — free to use, modify, and redistribute, including in commercial server setups. Attribution to **Titan Scripts** is appreciated but not required.

## 💬 Support

This is a free, community-support resource — there's no paid support ticket system. Please use the repository's **Issues** tab for bug reports and questions.

---

<div align="center">

Made with 🍕 by **Titan Scripts**

</div>
