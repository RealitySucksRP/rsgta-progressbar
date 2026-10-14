# Changelog

## 4.3.0 — public multi-framework release hardening

- Removed deprecated `lua54 'yes'`; current FiveM uses Lua 5.4 automatically.
- Switched NUI callback registration to the current `RegisterNuiCallback` API.
- Fixed `center-top` placement so the documented option is now actually honored.
- Added ox-style `position = 'top'` mapping to `center-top`.
- Added a `Progressbar` alias alongside `Progress` for third-party compatibility.
- Added a `qb-progressbar` provided-resource/export alias for scripts using that non-official resource name.
- Added `/rsprogressdiag` with environment, NUI, ox_lib and duplicate-provider diagnostics.
- Rewrote README and installation notes for Qbox, QBCore, ESX, ox-style, standalone, Legacy and Enhanced owners.
- Preserved the working Qbox behavior, QBCore callback safety, ESX compatibility, server-side prop validation and UI design.
- No external `rs_bridge`, inventory or framework dependency was added.

## v4.2.0 — Universal Qbox/QBCore hardening

- Unified the runtime engine with the proven RS Blood Progressbar v4.2.1 compatibility core while preserving the Field Terminal NUI and artwork.
- Added once-only QBCore callable-reference callback handling and Lua-authoritative completion for standard QB progress calls.
- Added session IDs so stale NUI callbacks cannot finish a newer action.
- Added a completion watchdog, deterministic cleanup, and safer `inv_busy` ownership.
- Kept the extracted resource folder name `progressbar` for drop-in QBCore/Qbox configuration.
- Kept ESX and ox-style adapters plus the optional append-only ox_lib bridge.
- Added `/rsfieldqbtest` when `Config.devMode = true` to exercise the exact QBCore wrapper callback path.
- Removed the stale two-build warning; this is one universal Qbox/QBCore/ESX/standalone resource.

## v4.1.0 — Field Terminal Release Cleanup

- Rebranded the product and NUI as RS Field Terminal Progressbar.
- Removed the previous franchise-adjacent branding and old branded frame artwork.
- Rebuilt the rugged field-terminal housing in local HTML/CSS.
- Removed the hard dependency on rs_bridge; the resource is framework-agnostic.
- Added explicit QBCore, Qbox, ESX, Ox Core/ox_inventory, and standalone install instructions.
- Added `provide 'esx_progressbar'` for ESX replacement compatibility.
- Preserved `provide 'progressbar'` and standard QBCore progress exports/events.
- Preserved optional ox_lib routing while documenting that working Ox installations should remain untouched.
- Enforced `canCancel = false` for player key cancellation.
- Fixed cancellation state so callbacks receive cancelled actions correctly.
- Hardened server prop tracking with count, type, model, proximity, and network-owner validation.
- Corrected the prop cleanup event spelling while retaining an old-event compatibility listener.
- Removed browser-only preview/development fixture from the production NUI.

## v4.0.1

- Added developer API documentation and provider compatibility helpers.
- Added local NUI scaling support and release documentation.
