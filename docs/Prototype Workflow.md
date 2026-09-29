# Tiny Factory prototype

This branch keeps the first playable factory loop on a temporary baseplate. A dropper sends visible items along four clickable machine positions and a fixed fifth seller. Players can roll machines for free every three seconds, place or recycle them, buy capacity with Coins, and collect public Coin or temporary Luck boosters that spawn randomly around factory plots and activate on Humanoid touch.

## Build and test

1. Run `rojo build default.project.json --output TinyFactory.rbxlx`.
2. Open the built place in Roblox Studio, or use `rojo serve default.project.json` for live code and Workspace synchronization.
3. Playtest the full loop: roll, wait for cooldown, click a conveyor slot then choose a rolled machine (and also test machine-first placement), watch an item reach the seller, buy capacity, run over Coin and Luck boosters, and reconnect to check persistence.
4. Test desktop, phone, and two-player Studio sessions before publishing. The roll button stays at the bottom center, while the server owns cooldowns, machine grants, booster selection, and rewards.

`tests/studio/PrototypeSmoke.luau` is a repeatable local Studio playtest for the built place. Run it with Studio's `RunScript` command-line task and `--localPlaceFile TinyFactory.rbxlx`. It checks per-machine inventory and reveal odds, chance-derived rarities, free roll and cooldown, placement, production and sale, recycling, capacity, timed Luck, physical slot markers, Humanoid touch pickup, and duplicate-claim protection. The regular GitHub runner cannot execute this Studio-only test.

The event presentation registry is in `src/client/Controllers/EffectsController.luau`. Server systems announce moments through `EffectService.fire(player, eventName, payload)`. Add a new visual or short cutscene by registering an event handler in the client controller. These effects are cosmetic; the server owns inventory, RNG, loot rewards, production, and Coins. The ultra-rare roll presentation is configured in `EconomyConfig`; its odds threshold and duration can be changed without modifying the roll algorithm. Studio smoke tests exercise the cutscene event with synthetic 1/10,001 odds so no extremely rare live machine is required.

## Workspace and 3D assets

`default.project.json` now includes `Workspace` and `src/workspace`. The baseplate and spawn are in the Rojo project, so a built place contains them without relying on a manually saved Studio scene. Future Studio-exported `.rbxm` or `.rbxmx` models can go in `src/workspace` and will be included by Rojo and the main-only publish workflow.

Raw `.obj` files are source art, not Rojo place instances. Roblox Studio's Importer accepts OBJ, while Roblox Open Cloud Model uploads accept FBX, GLTF, and GLB. For a Git-managed custom model, import it in Studio and commit its Roblox model export, or convert OBJ to GLB and use a separately validated asset-upload step. Mesh assets still need Roblox ownership, moderation, and usable IDs. The current prototype does not load the optional 3D showcase or require imported custom models to publish.

The GitHub workflow validates pull requests and version-branch pushes, but builds/publishes only from `main`. Publishing needs the existing `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`, and `ROBLOX_PLACE_ID` secrets.
