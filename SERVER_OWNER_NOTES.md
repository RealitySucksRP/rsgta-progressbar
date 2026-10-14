# Server Owner Notes

## What this resource is

A progress provider and UI. It deliberately does not own player money, items, jobs, framework data or mission rewards.

## What `framework-agnostic` means

The core engine does not need Qbox, QBCore or ESX. Compatibility adapters expose the APIs those ecosystems commonly expect. Custom resources can always call the direct exports.

## Supported public paths

- Qbox: QB-compatible `progressbar` calls and direct exports.
- QBCore: official `QBCore.Functions.Progressbar` / `exports['progressbar']` shape.
- ESX: current `ESX.Progressbar` → `esx_progressbar` export shape.
- Ox-style: direct progressbar exports; hardcoded `lib.progressBar()` stays ox_lib unless the optional adapter is installed.
- Standalone/custom: direct exports.

## Resource name and compatibility aliases

Keep the physical server folder named exactly:

```text
progressbar
```

This is not cosmetic. Current QBCore checks the `progressbar` resource and routes `QBCore.Functions.Progressbar(...)` through `exports['progressbar']`. Qbox preserves QB-compatible consumers that expect that same resource/export name. Do not deploy this as `progressbar(1)`, `rsgta-progressbar`, or another renamed folder if you expect drop-in QB compatibility.

ESX is different: its normal wrapper uses the `esx_progressbar` provider/API name. This resource keeps the real folder named `progressbar` and declares `provide 'esx_progressbar'`, while also exposing the expected `Progressbar` / `CancelProgressbar` exports. Do not install a second `esx_progressbar` beside it.

## Do not run duplicates

Only one provider should own a given progress API. Duplicate providers can cause double UI, callbacks resolving twice, stuck busy states or one resource hiding another.

## Support information to collect

If reporting an install issue, include:

1. `rsprogressdiag` output from client F8.
2. Framework and version.
3. Name of the calling resource.
4. The exact export/function it calls.
5. Whether ox_lib is installed.
6. Whether another progress provider is running.
7. Client F8 and server-console errors.


## Enhanced `provide` compatibility

Current FiveM Enhanced builds include the August 2026 fix that restored correct `GetResourceState` behavior for resources satisfied through `provide`. Keep server artifacts current, especially when ESX resources check `esx_progressbar` by name.
