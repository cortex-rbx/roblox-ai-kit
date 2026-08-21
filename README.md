# Cortex — AI for any part of your Roblox game

One server-side HTTP request gives your game a brain: **dialogue, adaptive quests,
generated items & lore, chat moderation** — anything text-shaped. ~3 seconds a call.

- **Your key never touches the client.** All calls go from a server Script.
- **Pay in Robux** via a game pass. No cards, no backend to run.
- **Open beta — free keys for the first devs.** Grab one in the Discord.

## Install
1. Put `src/Cortex.lua` into **ServerStorage** as a ModuleScript named `Cortex`.
2. Turn on **Game Settings → Security → Allow HTTP Requests**.
3. Get a free beta key → **https://discord.gg/A3MSqwkvn7**

## Use (server Script only)
```lua
local Cortex = require(game.ServerStorage.Cortex)
local ai = Cortex.new("YOUR_KEY")

local line = ai:ask("You are a gruff blacksmith. One short line.", "forge me a sword?")
print(line) --> "Aye — hand over the ore and I'll hammer ye a blade."
```

`ask(instructions, input, tier?)` → `text, unitsLeft`.
Tiers: `osa-fast` (quick), `osa-smart` (richer), `osa-cheap` (bulk), `osa-auto` (picks for you).

See `examples/demo.server.lua` for dialogue, item text, quests and moderation.

## Links
- Demo & docs: https://cortex-rbx.github.io
- Beta key & support: https://discord.gg/A3MSqwkvn7

_Beta: free keys for testers, no 24/7 uptime guarantee yet._
