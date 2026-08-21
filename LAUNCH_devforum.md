<!-- Paste this into DevForum → Community Resources once you hit Member trust level.
     Title suggestion below, then the body. -->

TITLE: [Open Beta] Cortex — give any part of your Roblox game a brain (dialogue, quests, moderation) with one server request

---

Hey devs — I've been building **Cortex** and I'm opening a free beta.

**What it is:** one server-side HTTP request that lets your game run a neural net. Use it for anything that needs to think or write:

- NPCs / characters that reply **in-character** to what the player actually typed
- quests and missions that **adapt** to the player
- item names, lore and descriptions generated on the fly
- **chat moderation by meaning** (not a word list)
- an in-game assistant / guide

**Why it's safe:** your key **never touches the client** — every call goes from a server Script. (I've seen AI tools here leak their provider key in client code; Cortex is built so that can't happen.) No backend to run, no card — you **pay in Robux** via a game pass when you're ready.

**One request:**
```lua
local Cortex = require(game.ServerStorage.Cortex)
local ai = Cortex.new("YOUR_KEY")
print(ai:ask("You are a gruff blacksmith. One short line.", "forge me a sword?"))
--> "Aye — hand over the ore and I'll hammer ye a blade."
```

**Free open-source kit:** https://github.com/cortex-rbx/roblox-ai-kit
**Demo & docs:** https://cortex-rbx.github.io

🎁 **Beta rewards** — first testers get free keys now, a **permanent founder discount** when it goes paid, and a **Robux reward + your game featured** if you ship it in a live game and share feedback. Refer another dev who tests it → bonus for both.

It's an early beta (no 24/7 uptime guarantee yet) and I'll personally help you wire it in. Grab a key and say hi: https://discord.gg/A3MSqwkvn7

Would love feedback on the API and what you'd want it to generate.
