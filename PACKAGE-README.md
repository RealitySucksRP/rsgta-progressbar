# RS Progressbar Studio 4.4.16

**Full source | GPL-3.0-only | FiveM**

RS Progressbar Studio is RealitySucksRP's multi-frame progress interface system for FiveM. The engine is **framework-agnostic**: one `progressbar` resource can serve Qbox, QBCore, ESX, ox-style callers, custom frameworks and standalone resources without any external integration bridge or inventory dependency.

> **Important:** keep the extracted folder named exactly `progressbar`. Current QBCore checks the `progressbar` resource and routes its wrapper through `exports['progressbar']`; Qbox keeps QB-compatible callers working through the same resource name. ESX uses the separate `esx_progressbar` API name, which this resource satisfies through `provide 'esx_progressbar'` plus the expected exports.

## Compatibility

| Environment | Supported path |
| --- | --- |
| Qbox / `qbx_core` | QB-compatible `exports['progressbar']` callers and direct exports |
| QBCore / `qb-core` | Current `QBCore.Functions.Progressbar` → `exports['progressbar']:Progress(...)` |
| ESX / `es_extended` | `ESX.Progressbar` / `exports['esx_progressbar']:Progressbar(...)` |
| Ox-style resources | Direct `progressBar`, `progressCircle`, `progressActive`, `cancelProgress` exports |
| Standalone / custom | Direct `exports['progressbar']` API |
| Legacy / Enhanced | Same resource design; verify on your server |

Qbox's QB compatibility layer lets QB-style resources continue using the familiar QBCore path. Resources hardcoded to `lib.progressBar()` still use ox_lib's own progress UI unless the **optional** ox_lib bridge in `tools/ox_lib` is intentionally installed.

## Why one build works across frameworks

The progressbar does not own jobs, money, inventory or framework state. It only owns progress presentation, animation/prop lifecycle, control disabling, cancellation and completion callbacks. That keeps framework-specific business logic in the calling resource and makes this resource portable.

## Features

The original field-terminal frame uses a foreground bezel that masks the lower live display.

- Pip-Boi 420 case artwork with a live, screen-contained CRT interface
- Single-stage and multi-stage actions
- Lua-authoritative completion safety
- QBCore/Qbox compatible callbacks
- ESX compatibility alias
- Third-party `qb-progressbar` compatibility alias
- Ox-style direct exports
- Standalone direct API
- Animations, scenarios and sequential animation stages
- Up to five validated network props per action
- Player cancellation with configurable key mapping
- Control disabling
- Dead/ragdoll/swimming/cuffed/falling handling for ox-style semantics
- Completion ledger and watchdog recovery
- Resource-stop cleanup
- Server-side prop ownership/model validation
- Ten selectable frames, eight accent choices (including Default), five manual bar styles plus automatic selection
- Frame Studio with live preview, playback and saved cosmetic preferences
- Full, Low and Off visual effect settings
- Live percentage, remaining time, phases, animated signal graph and cancel prompt
- Responsive hardware-and-screen scaling for smaller screens and GTA V Enhanced
- Transparent outer frame and no startup NUI
- `center-bottom`, `center`, and `center-top` placement
- Built-in `/rsprogressdiag` installation diagnostic

## Installation

1. Stop/remove the progressbar resource you are replacing.
2. Extract this package so the folder is exactly `progressbar`.
3. Ensure it **before resources that call its exports**.
4. Do not run two progress providers for the same API at the same time.
5. Fully restart the server after replacing an existing provider.
6. Run `/rsprogressdiag` in client F8 and confirm the detected environment.

### Qbox

```cfg
ensure ox_lib
ensure qbx_core
ensure progressbar
# resources that use progress after this
```

No Qbox edits are required for QB-compatible callers. If a resource calls `lib.progressBar()` directly, it continues to use ox_lib unless you deliberately install the optional adapter under `tools/ox_lib`.

### QBCore

```cfg
ensure qb-core
ensure progressbar
# resources that use QBCore.Functions.Progressbar after this
```

No edits to `qb-core` are required. Current QBCore's wrapper calls the `progressbar` export this resource implements.

### ESX

```cfg
ensure es_extended
ensure progressbar
# ESX resources after this
```

Do not also start a separate `esx_progressbar`. This resource declares `provide 'esx_progressbar'` and exposes the expected `Progressbar` and `CancelProgressbar` exports.

### Standalone / custom framework

```cfg
ensure progressbar
```

Then call the direct exports shown below.

## QBCore-compatible example

```lua
exports['progressbar']:Progress({
    name = 'repair_vehicle',
    label = 'Repairing Vehicle',
    duration = 5000,
    useWhileDead = false,
    canCancel = true,
    controlDisables = {
        disableMovement = true,
        disableCombat = true,
    },
}, function(cancelled)
    if cancelled then return end
    print('Repair complete')
end)
```

## ESX example

```lua
ESX.Progressbar('Repairing Vehicle', 5000, {
    FreezePlayer = true,
    onFinish = function()
        print('Repair complete')
    end,
    onCancel = function()
        print('Repair cancelled')
    end,
})
```

## Direct / custom-framework example

```lua
local started = exports['progressbar']:Start({
    label = 'Searching Vehicle',
    duration = 5000,
    canCancel = true,
}, function(cancelled)
    print('cancelled:', cancelled)
end)
```

## Multi-stage example

```lua
exports['progressbar']:Progress({
    label = 'Inspecting Vehicle',
    canCancel = true,
    stages = {
        { message = 'Checking exterior', duration = 1500 },
        { message = 'Scanning electrical system', duration = 2500 },
        { message = 'Finishing inspection', duration = 1500 },
    },
}, function(cancelled)
    print('cancelled:', cancelled)
end)
```

## Diagnostics

Run in client F8:

```text
rsprogressdiag
```

The diagnostic reports the package version, resource folder, detected Qbox/QBCore/ESX/Standalone environment, ox_lib state, NUI readiness, active state and obvious duplicate progress providers.

For QBCore/Qbox wrapper testing, temporarily set `Config.devMode = true` and run:

```text
rsfieldqbtest
```

Turn dev mode back off afterward.

## Automatic vehicle images (922 included)

The package contains 922 vehicle images. To add or replace images, use `html/assets/vehicles/` and lowercase **vehicle spawn names** as filenames:

```text
progressbar/html/assets/vehicles/adder.webp
progressbar/html/assets/vehicles/sultanrs.png
progressbar/html/assets/vehicles/police.jpg
progressbar/html/assets/vehicles/mycustommodel.webp
```

No image manifest, individual Lua registrations, or vehicle count setting is
required. The FiveM manifest automatically includes the files you place there.
Restart the resource after adding images so FiveM can package them for clients.

On a vehicle-related progress action (hotwire, lockpick, car key search, repair,
vehicle search), the client checks the supplied target vehicle or the nearest
vehicle within 5 meters, finds its **registered model spawn name**, and sends
that safe model key to the Pip-Boi NUI. The NUI tries the configured image
extensions. With no match, the UI displays a message, **not a silhouette**.

If the image filename differs from the spawn code, set an alias in
`lua/config.lua`: `aliases = { police3 = 'police_cruiser' }`.

For scripts with a known target, prevent nearest-car ambiguity by passing the
actual entity/model in the existing progress data object:

```lua
exports['progressbar']:Progress({
    name = 'lockpick',
    label = 'Searching for the car keys...',
    duration = 8000,
    vehicleEntity = targetVehicle, -- preferred: real vehicle handle on this client
    -- or: vehicleModel = 'sultanrs',
    -- or: vehicleNetId = NetworkGetNetworkIdFromEntity(targetVehicle),
}, function(cancelled) end)
```

Only vehicle-related progress actions show a vehicle image; ordinary item,
medical, crafting, and generic actions retain their normal scanner view.
Customize radius, extensions and aliases via `Config.vehicleImages`.

## Server-owner configuration

`lua/config.lua` controls `Config.ui.scale` (0.60–1.25), `Config.ui.bottomOffset`, the default CRT color theme, and cancel key. The hardware shell, header, live text and telemetry always scale together inside the original screen. At the start of a task, the UI automatically clamps to the available display size.

## Server-owner notes

- **Folder name matters:** use `progressbar`, not `progressbar(1)` or `rsgta-progressbar` on the server.
- **One provider only:** do not leave the stock QBCore progressbar, a separate ESX progressbar and this resource running together.
- **No inventory dependency:** ox_inventory, qb-inventory and other inventories do not need modification for this resource.
- **Self-contained:** no external integration bridge resource is required.
- **Qbox note:** QB-compatible callers route here; hardcoded `lib.progressBar()` is still an ox_lib call unless you intentionally install the optional adapter.
- **Full restart recommended:** especially after replacing another provider with the same resource/export name.
- **Live smoke test:** test complete, cancel, non-cancellable, animation, prop and framework-wrapper actions before opening the server to players.
- **Enhanced artifact note:** current FiveM Enhanced builds include the August 2026 fix for `provide`/`GetResourceState`. If ESX reports `esx_progressbar` as missing despite this resource being installed, update the server artifact first.

See [`INSTALL.md`](INSTALL.md) for a longer installation checklist and [`DEVELOPER-API.md`](DEVELOPER-API.md) for the complete API.

## License

This is a **GPL-3.0-only** full-source release because it is derived in part from `swkeep/keep-progressbar`. See `LICENSE.md`, `COPYING`, and `THIRD_PARTY_NOTICES.md`.

The GPL license permits use, modification and redistribution, including for a fee, under its terms. Purchasing a copy does not remove any of those rights.

## Upstream/API references

- QBCore progressbar: https://github.com/qbcore-fivem/progressbar
- QBCore client wrapper: https://github.com/qbcore-framework/qb-core/blob/main/client/functions.lua
- Qbox compatibility documentation: https://docs.qbox.re/faq
- ESX progressbar integration: https://github.com/esx-framework/esx_core
- Cfx resource manifests: https://docs.fivem.net/docs/scripting-reference/resource-manifest/
- Cfx NUI callbacks: https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/


## Universal live image assets

The Pip-Boi can now resolve **item, tool, vehicle, and category images**.
Use any combination of these task fields when calling the progressbar:

```lua
item = 'water_bottle'
tool = 'advancedlockpick'
category = 'drink' -- or food, medical, drug, alcohol, ammo, smoke, tool, vehicle, search, craft
asset = 'custom_file_name' -- explicit image stem override
assetFolder = 'items'       -- items, vehicles, or categories
assetCandidates = { 'water_bottle', 'water' }
useVehicleImage = true      -- prefer actual vehicle art when the action targets a vehicle
vehicleEntity = vehicle     -- optional actual target vehicle
```

Folder layout:

```text
progressbar/html/assets/items/
progressbar/html/assets/vehicles/
progressbar/html/assets/categories/
```

Resolution order is explicit asset override → item/tool image → vehicle image → category fallback → text fallback.
If no matching image exists, the Pip-Boi shows a clean fallback message instead of a broken image.


## Built-in smart presets

Version 4.3.5 adds built-in fallback candidates for common item and tool names so server owners do not have to alias every basic consumable manually.
Examples include `water`, `bandage`, `firstaid`, `medkit`, `cigarette`, `joint`, `beer`, `whiskey`, `vodka`, `lockpick`, `advancedlockpick`, and `hotwirekit`.
Server-owner aliases in `Config.assetImages.aliases` still override these defaults.

Doctor/EMS treatment, trauma, CPR and defibrillator labels select the medical category.
With smart presets enabled, treatment without a supplied item image shows the bundled
`ifaks` trauma kit, falling back to first aid/medkit artwork and then the medical category image.
Explicit asset, item and tool images still take priority.
