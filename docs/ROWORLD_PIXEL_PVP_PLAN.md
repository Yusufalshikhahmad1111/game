# RoWorld / OpenFront-inspired World PvP Pivot

## Goal

Replace the previous country-selection prototype with a real-time pixel/tile territory-conquest game.

1. Enter directly into the world map — no gameplay lobby.
2. Click an unclaimed land pixel to spawn.
3. Start with a small connected territory.
4. Choose an attack ratio.
5. Click an enemy or neutral pixel.
6. The server sends that fraction of current troops.
7. Land attacks expand from the frontier tile by tile.
8. Coastal players can launch naval attacks against coastal targets.
9. Captured pixels immediately change ownership/color.
10. Cities, factories, ports and defense posts affect the economy/war loop.
11. Nuclear strikes provide an expensive area attack.
12. Control 80% of land to win.

## Research basis

RoWorld's public description describes real-time territory conquest with a single-nation start, neighboring attacks, cities, ports, factories, alliances, nukes, 88 player nations, hundreds of tribes and an 80% world-control victory condition. Current public listings report a 55-player server cap and credit OpenFront and Contributors.

The OpenFront source was reviewed for the mechanics that matter here:

- AttackExecution: attacks hold a troop amount, discover the attack frontier from owned border tiles, conquer progressively, apply terrain/defender-dependent losses, and retreat/refund survivors.
- PlayerActionHandler: normal attacks use attackRatio * player.troops().
- TransportShipExecution: naval attacks target a map tile, find a transport spawn and water route, then create a beachhead attack on arrival.
- SpawnExecution: spawning is a clicked map tile followed by a compact starting area.
- EngineConfig: attack speed/loss depends on terrain, troop ratio and defender density.
- PlayerExecution: troops and gold regenerate continuously.

Roblox EditableImage documentation confirms that a runtime EditableImage can be displayed through ImageLabel.ImageContent and updated with a pixel buffer. The current map uses that mechanism.

## Architecture implemented

### World

shared/WorldPvP/CountryMapData.lua
- Natural Earth public-domain country outlines.
- Used as the land mask, not as ownership units.

shared/WorldPvP/TileMap.lua
- Converts the geographic mask to a 256x128 tile world.
- Each land tile has owner, terrain, neighbors and optional building.
- Water is explicit.
- Coastal tiles are detected.

shared/WorldPvP/PixelWorldState.lua
- Direct real-time simulation.
- Human spawn.
- Per-tile ownership.
- Troop-ratio frontier attacks.
- Coastal/naval attacks.
- AI nations and tribes.
- Troop/gold regeneration.
- Buildings.
- Protection timer.
- Nuclear area attacks.
- 80% victory detection.

### Client

client_worldpvp/WorldPvPClient.client.lua
- Full-screen pixel map.
- Pixelated rendering.
- Direct click-to-spawn.
- Direct click-to-attack.
- Attack-ratio presets.
- Troop/gold/territory HUD.
- Building controls.
- Nuke control.
- Winner display.

### Server

server_worldpvp/WorldPvPGame.server.lua
- CharacterAutoLoads=false.
- No gameplay lobby.
- Authoritative simulation.
- Remote validation for spawn/attack/build/nuke.
- Snapshot broadcasting.

## Intentional differences

This project does not copy proprietary RoWorld assets, private map files, UI artwork, or closed source. It independently implements the researched gameplay model and uses public-domain geographic data.

## Next production pass

1. Dirty-tile updates instead of full-map redraw.
2. Camera pan/zoom.
3. Visible attack arrows/front lines.
4. Animated naval transports.
5. Alliances and diplomacy panel.
6. Proper defense posts, SAMs and warships.
7. Deeper city/factory/port progression.
8. Elimination and 80% victory screens.
9. DataStore/progression after combat is stable.
10. Full Studio QA before release.

## Acceptance test

A correct first playtest must show:
- No avatar death.
- No gameplay lobby.
- World map immediately.
- Click free land -> player territory appears.
- Click enemy/neutral tile -> selected troop ratio is sent.
- Territory grows tile-by-tile rather than whole-country teleportation.
- Coastal enemy attacks can use a naval route.
- Gold and troops regenerate.
- Buildings only work on owned tiles.
- 80% control produces a winner.
