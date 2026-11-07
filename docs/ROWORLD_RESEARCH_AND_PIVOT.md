# World PvP Pivot — Research & Direction

**Project direction:** replace the turn-based colour-grid game with an original Roblox real-time world-conquest strategy game inspired by the broad gameplay loop of RoWorld [World PvP] / OpenFront.

**Status (2026-11-07):** research completed; new server-independent Luau simulation foundation added under `shared/WorldPvP/`. The existing M0–M7 Island Dominion game is still the currently wired runtime; the new simulation is not yet connected to the Roblox remotes or client UI. Do not describe the pivot as playable until that integration and Studio QA are complete.

## 1. What RoWorld is

The official Roblox listing describes RoWorld as real-time territory conquest: start as a nation, expand into neighbors, build cities, ports and factories, form alliances, launch nukes, and win at 80% world control. It lists a 55-player server cap. The listing credits “OpenFront and Contributors” and says it was modified by Snick.

Sources:
- Official Roblox listing: https://www.roblox.com/games/137151641329864/RoWorld
- Official upstream project: https://github.com/openfrontio/OpenFrontIO
- OpenFront overview: https://github.com/openfrontio/OpenFrontIO/blob/main/README.md
- RoWorld overview and history: https://rofront.net/game/

The Roblox-specific place source for RoWorld is not published in the official listing. This repository therefore cannot honestly claim to contain an exact copy of RoWorld's Roblox scripts, server logic, or private assets.

## 2. Target gameplay loop

1. Join a live world and select an unoccupied starting nation.
2. Expand from owned land into adjacent neutral or hostile land in real time.
3. Manage gold, population/troop capacity, and available army.
4. Build economic and defensive structures: City, Port, Factory, Defense Post, Missile Silo and SAM.
5. Use diplomacy: propose/accept alliances, coordinate borders, and handle betrayal.
6. Use land and naval routes to reach distant fronts.
7. Use missiles/nuclear weapons as late-game strategic options.
8. Win by controlling at least 80% of the eligible land; be eliminated at zero land.

This describes the intended systems, not a claim that all of them are implemented yet.

## 3. Roblox implementation direction

The game must be rebuilt as a Roblox-native Luau experience. The upstream OpenFront browser client is TypeScript/web code; it is not a drop-in Roblox Studio project.

- Server authoritative: clients request actions; the server validates ownership, adjacency, costs, cooldowns and match state.
- Real-time simulation: fixed server tick, independent of client frame rate.
- Data-first world: map cells, nation ownership, structures and units are plain state; rendering is a separate client concern.
- Map: use a properly licensed geographic dataset and convert it into a compact cell/region representation. The initial Luau map helper currently supports row-based maps for simulation tests; it is not the final Earth map.
- Multiplayer: design around the RoWorld reference cap of 55 players, but load-test Roblox replication and map update bandwidth before adopting that cap.
- UI: country selection → full-screen world map → live HUD (gold, troops, world share, diplomacy, build/action panels) → end-of-match results.

## 4. Licensing and attribution guardrails

OpenFront's repository states that its source code is licensed under **AGPL-3.0**. If code is copied or adapted from that repository, the resulting covered work must comply with the AGPL, including the source-availability and notice requirements that apply to the distribution/deployment model. Do not copy code into this project without intentionally accepting those obligations.

OpenFront's separate asset notice says:
- files in `/resources` are CC BY-SA 4.0 and require attribution;
- files in `/proprietary` are all rights reserved and cannot be reused outside the complete OpenFront software package;
- externally hosted/CDN/database/premium assets are not included in the open asset license.

This pivot starts with independently written Luau logic and original Roblox UI. It does not copy RoWorld's private Roblox source or OpenFront's proprietary assets. Any later reuse of OpenFront code or CC BY-SA assets must be reviewed and attributed explicitly.

References:
- https://github.com/openfrontio/OpenFrontIO/blob/main/LICENSE
- https://github.com/openfrontio/OpenFrontIO/blob/main/LICENSE-ASSETS
- https://github.com/openfrontio/OpenFrontIO/blob/main/README.md

## 5. Migration plan

| Milestone | Scope | Exit criteria |
|---|---|---|
| W0 | Pivot, research, license and architecture baseline | This document and the initial simulation modules are committed |
| W1 | Geographic world map + nation/tribe data | Real map loads, land/water and country ownership validate |
| W2 | Real-time core simulation | Expansion, army, economy, elimination and 80% victory work server-side |
| W3 | Country selection and world-map UI | Player can select a valid nation and see all map state |
| W4 | Buildings and economy | Cities, ports, factories and defense structures have tested effects |
| W5 | Diplomacy and combat | Alliances, troop allocation, border combat and betrayal rules work |
| W6 | Naval and strategic weapons | Transport, warships, missile silos, SAM and nuclear actions are server validated |
| W7 | AI nations and multiplayer scale | NPC nations, 55-player target load tests, anti-exploit and replication budgets |
| W8 | Release QA | Device tests, performance, persistence, moderation and final release checklist |

## 6. Explicitly retired design assumptions

The following Island Dominion concepts are legacy and must not drive the new design:
- colour-pick turns / turn timers;
- Flood-It-style connected colour capture;
- a 10×10 board as the actual game world;
- the previous three-team fixed turn order;
- six colour-shift / turn-based powers as the core combat loop.

The old implementation remains in history until the new runtime is integrated and verified. Do not delete it prematurely.
