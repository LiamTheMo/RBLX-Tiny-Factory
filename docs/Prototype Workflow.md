# Tiny Factory prototype

The island factory has a dropper area, three processor areas and a dedicated Seller Bay. The belt, rails, machine models, and moving cubes share one conveyor elevation setting, while the plot and ground stay at their original height. The cube route now takes 1.15 seconds per logical segment. Clicking a machine area opens only owned droppers or upgraders suitable for that area; clicking the Seller Bay opens only owned sellers. The Inventory button has a Machines tab with Droppers, Upgraders, and Sellers sections and a Boosters tab for collected item modifiers.

Players roll machines for free every three seconds, buy limited capacity with Coins, and pick up world boosters by Humanoid touch. Pickups go into a bounded, saved booster inventory; players choose when to use a Coin or temporary Luck booster from the Boosters tab. The server validates both pickup and use. New booster definitions and effects belong in `BoosterConfig` and the server effect dispatcher.

## Build and test

1. Run `rojo build default.project.json --output TinyFactory.rbxlx`.
2. Open the built place in Roblox Studio, or use `rojo serve default.project.json` for live code and Workspace synchronization.
3. Playtest the loop: roll, wait for cooldown, click machine areas and the Seller Bay, place or move a machine, confirm the raised conveyor is in view, watch cubes fall onto the rollers and reach the Seller, buy capacity, run over Coin and Luck boosters, use one from the Boosters tab, and reconnect to check persistence.
4. Test desktop, phone, and two-player Studio sessions before publishing. The server owns cooldowns, machine grants, booster selection, placement, and rewards.

The schema v2 to v3 migration moves any seller saved in an earlier machine area into the dedicated Seller Bay and starts a saved booster inventory. The preceding v1.02 migration compresses five-area layouts into four areas and returns a displaced processor to inventory.

World boosters use a downward raycast to find a collidable land surface. The placeholder plot models are excluded from the ray so drops land on the terrain beneath them; water and steep side faces are skipped. Each booster appears above the surface, fades in while falling, and only becomes touch-pickable after landing.

tests/studio/PrototypeSmoke.luau is a repeatable local Studio playtest for the built place. Run it with Studio's RunScript command-line task and --localPlaceFile TinyFactory.rbxlx. It checks inventory ownership, contextual placement UI, roll odds and rarity, free rolls and cooldown, Seller Bay replacement and placement restrictions, production and sale, recycling, capacity, timed Luck, all four physical click areas, the temporary Dropper model, booster landing, Humanoid touch pickup, inventory use, and duplicate-claim protection. The regular GitHub runner cannot execute this Studio-only test.

The roll reveal uses transparent full-screen presentation labels with no filled card; the idle Roll control retains its button style, then becomes text-only while rolling. The event presentation registry is in src/client/Controllers/EffectsController.luau. Server systems announce moments through EffectService.fire(player, eventName, payload). Add a new visual or short cutscene by registering an event handler in the client controller. These effects are cosmetic; the server owns inventory, RNG, loot rewards, production, and Coins. The ultra-rare roll presentation is configured in EconomyConfig; its odds threshold and duration can be changed without modifying the roll algorithm. Studio smoke tests exercise the cutscene event with synthetic 1/10,001 odds so no extremely rare live machine is required.

## Workspace and 3D assets

default.project.json includes Workspace and src/workspace. The Rojo project includes IslandWorldBuilder and IslandWorldConfig; the server creates the six-island scene before gameplay starts. The prototype baseplate and spawn have been replaced. See v1.00/Island-Map-Validation.md for Studio evidence and remaining acceptance checks. Future Studio-exported .rbxm or .rbxmx models can go in src/workspace and will be included by Rojo and the main-only publish workflow.

Raw .obj files are source art, not Rojo place instances. Roblox Studio's Importer accepts OBJ, while Roblox Open Cloud Model uploads accept FBX, GLTF, and GLB. For a Git-managed custom model, import it in Studio and commit its Roblox model export, or convert OBJ to GLB and use a separately validated asset-upload step. Mesh assets still need Roblox ownership, moderation, and usable IDs. The current prototype does not load the optional 3D showcase or require imported custom models to publish.

The GitHub workflow validates only pushes to `main` and permanent major branches named `vX.XX`; it does not run jobs for pull requests or temporary/minor branches. Manual dispatch jobs are gated to `main`. Version-branch pushes validate only, while `main` pushes validate and publish. Publishing needs the existing ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, and ROBLOX_PLACE_ID secrets.
