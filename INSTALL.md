# RSGTA Modern Progressbar — Server Owner Quick Start

This is one framework-neutral build. Do not maintain separate Legacy, Enhanced, Qbox, QBCore or ESX copies.

## Required folder name

```text
progressbar
```

Current QBCore checks the `progressbar` resource and routes `QBCore.Functions.Progressbar(...)` through `exports['progressbar']`; Qbox keeps QB-compatible resources working through the same name. Renaming the server folder can therefore break otherwise-correct callers. ESX uses the `esx_progressbar` API name; this resource satisfies that separately through `provide 'esx_progressbar'` and the matching exports, so the physical server folder should still remain `progressbar`.

## Before installation

Stop/remove any other resource providing the same progress API. Common conflicts include the stock QBCore `progressbar`, a separate `esx_progressbar`, `qb-progressbar`, old RS progressbars, and other replacement providers.

## Recommended start order

### Qbox

```cfg
ensure ox_lib
ensure qbx_core
ensure progressbar
```

### QBCore

```cfg
ensure qb-core
ensure progressbar
```

### ESX

```cfg
ensure es_extended
ensure progressbar
```

### Standalone / custom framework

```cfg
ensure progressbar
```

The progressbar has no framework, inventory or rs_bridge dependency. It only needs to be running before a resource calls it.

## Qbox and ox_lib

Qbox's QB compatibility path can use this resource through `exports['progressbar']` / QBCore-style calls.

Hardcoded `lib.progressBar()` and `lib.progressCircle()` belong to ox_lib and are **not globally replaced by default**. This is intentional. If your server already works, leave ox_lib alone.

An optional adapter is included under `tools/ox_lib` for owners who specifically want those ox_lib calls routed through this UI. Read its README before touching ox_lib, and expect to reapply the adapter after ox_lib updates.

## First boot check

After a full restart, run in client F8:

```text
rsprogressdiag
```

Confirm the detected environment and make sure it does not report another progress provider running alongside this one.

## Smoke-test checklist

Before releasing to players, test:

- normal successful completion
- player cancellation
- `canCancel = false`
- animation and scenario actions
- attached props
- multi-stage actions
- your framework's wrapper (`QBCore.Functions.Progressbar`, `ESX.Progressbar`, etc.)
- resource restart while a progress action is active
- optional ox_lib adapter only if you intentionally installed it

For QBCore/Qbox callback verification, temporarily set `Config.devMode = true`, restart `progressbar`, run `rsfieldqbtest`, then return dev mode to false.

## Common problems

### QBCore says progressbar must be started

Verify the actual folder is named `progressbar` and that `ensure progressbar` runs before the resource making the call.

### Two progress UIs appear

Another provider is still running. Stop the duplicate and fully restart.

### Qbox resource still shows ox_lib progress

That resource probably calls `lib.progressBar()` directly. This progressbar does not hijack ox_lib globally by default.

### Progress completes visually but gameplay callback does not run

Run `rsfieldqbtest` with dev mode enabled. v4.3.0 keeps Lua-authoritative completion and a completion ledger specifically to protect QB-compatible callback paths.

### Player controls or inventory remain busy

The resource owns a watchdog and cleanup path. Capture the F8 output from `rsprogressdiag` and check for another progress provider or a resource that independently sets `inv_busy`.


### ESX says `esx_progressbar` is missing even though `progressbar` is installed

First verify the server is on a current artifact. FiveM Enhanced had a `provide` / `GetResourceState` regression that was fixed in the August 2026 Enhanced patches. On an older affected artifact, update the artifact. As a temporary compatibility workaround, starting `progressbar` before `es_extended` also ensures the provider is present before ESX caches addon availability.
