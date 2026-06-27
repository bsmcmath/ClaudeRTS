# Claude RTS

A small real-time-strategy game built with Vulkan and deterministic lockstep
rollback netcode. This repository holds the ready-to-play Windows build — the
files here are kept up to date with each new release.

## Play

1. Download this folder (green **Code → Download ZIP**, or clone it).
2. Run **`game.exe`**.

From the main menu:
- **Practice** – solo sandbox against no opponent.
- **Private Lobby** – play online against a friend (share a lobby name), or pick
  **Play vs Computer** for an offline match.
- **Settings** – username, aspect ratio, window mode, etc.

Other launchers:
- **`play2p.bat`** – local two-player test on one PC.
- **`startserver.bat`** – run the matchmaking server (for hosting online play).

## Requirements

- Windows with a Vulkan-capable GPU.
- The Visual C++ runtime DLLs are bundled, so no separate install is needed.

## Controls (in match)

- Left-drag to select bots; right-click to move / attack / gather.
- Hotkeys: **A** attack-move, **S** stop, **H** hold, **B** build, **C** return ore.
- With a building selected, right-click sets its rally point (right-click an enemy
  to rally as an attack-move). **Esc** opens the menu.
