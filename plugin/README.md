# Cortex Studio — AI coding terminal (plugin skeleton v1)

A Roblox Studio plugin: a dark terminal panel that reads the script you have
selected, sends your request to Cortex, prints the reply, and can write the
change back into the script. This is the v1 skeleton — the whole loop works.

## Install (on your computer, once)
1. Open Roblox Studio.
2. Explorer → right-click → Insert Object → **Script**.
3. Open `plugin/CortexStudio.lua` from this repo, copy **all** of it, paste into that Script.
4. Right-click the Script in Explorer → **"Save as Local Plugin…"** → Save.
5. A **Cortex** button appears in the **Plugins** toolbar. Click it — the panel docks on the right.

## First run
- In the terminal type: `/key YOUR_BETA_KEY` (stored locally, once).
- Select a Script / ModuleScript in the Explorer.
- Type a request, e.g. *"add a header comment explaining this script"* → Send.
- Type `/apply` to write the returned code into the selected script.

## Commands
- `/key <key>` — save your beta key locally
- `/new` — clear the terminal
- `/apply` — write the last ```lua block into the selected script

## Works offline
No key or backend down? It falls back to a mock reply so the UI + Studio
integration still demo cleanly.

## Notes
- Model button (bottom-left) cycles the named models — display only for now.
- Backend `/npc` currently routes cheaper models; frontier routing
  (Opus / Sonnet / Qwen3-Coder) is the next backend step. The pipe is real.
