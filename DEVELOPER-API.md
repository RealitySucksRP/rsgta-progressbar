# RSGTA Modern Progressbar — Developer API

The recommended resource folder name is `progressbar`.

## Direct / QBCore-compatible exports

```lua
exports['progressbar']:Start(data, callback)
exports['progressbar']:Progress(data, callback)
exports['progressbar']:Progressbar(data, callback) -- third-party alias
exports['progressbar']:Cancel()
exports['progressbar']:isActive()
exports['progressbar']:isDoingSomething()
exports['progressbar']:ProgressWithStartEvent(data, onStart, onFinish)
exports['progressbar']:ProgressWithTickEvent(data, onTick, onFinish)
exports['progressbar']:ProgressWithStartAndTick(data, onStart, onTick, onFinish)
```

Standard progressbar events are also registered:

```lua
TriggerEvent('progressbar:client:cancel')
TriggerEvent('progressbar:client:progress', data, callback)
TriggerEvent('progressbar:client:ProgressWithStartEvent', data, onStart, onFinish)
TriggerEvent('progressbar:client:ProgressWithTickEvent', data, onTick, onFinish)
TriggerEvent('progressbar:client:ProgressWithStartAndTick', data, onStart, onTick, onFinish)
```

## Common task fields

| Field | Purpose |
|---|---|
| `label` | Main live task text |
| `duration` | Duration in milliseconds |
| `canCancel` | Allows player key cancellation; defaults to true |
| `useWhileDead` | Allows the action to continue while dead |
| `theme` | `default`, `theme-1`, `theme-2`, or `theme-3` |
| `position` | `center-bottom`, `center`, or `center-top` |
| `controlDisables` | Disable movement, mouse, sprint, vehicle controls, or combat |
| `animation` | Single animation or scenario |
| `animations` | Sequential animation list |
| `prop`, `propTwo`, `props` | Attached props; maximum five |
| `stages` | Multi-stage progress data with messages and durations |
| `onStart` | Task start callback |
| `on_finish` | Completion callback receiving `(cancelled, minigameResult)` |

## QBCore

Current QBCore's `QBCore.Functions.Progressbar(...)` wrapper uses `exports['progressbar']:Progress(...)`, so no core edit is required when this resource is installed as `progressbar`.

## Qbox

QB-compatible progressbar consumers can use the same `exports['progressbar']` API. Qbox/ox_lib resources that call `lib.progressBar()` directly use ox_lib unless the optional bridge is installed.

## ESX

```lua
exports['esx_progressbar']:Progressbar(message, duration, options)
exports['esx_progressbar']:CancelProgressbar()
```

The same functions are available from the actual resource:

```lua
exports['progressbar']:Progressbar(message, duration, options)
exports['progressbar']:CancelProgressbar()
```

## Ox-style adapters

```lua
exports['progressbar']:progressBar(data)
exports['progressbar']:progressCircle(data)
exports['progressbar']:progressActive()
exports['progressbar']:cancelProgress()
```

Legacy aliases are also available:

```lua
exports['progressbar']:ox_lib_progressBar(data)
exports['progressbar']:ox_lib_progressCircle(data)
exports['progressbar']:ox_lib_progressActive()
exports['progressbar']:ox_lib_cancelProgress()
```

These exports do not automatically replace ox_lib's global `lib.progressBar`. See `tools/ox_lib/README.md`.


## Framework design rule

Do not put framework money, inventory, job, reward, or mission authority inside the progressbar. The calling resource should validate and own gameplay state; the progressbar should only present and settle the timed interaction.

## Installation diagnostic

Server owners can run `rsprogressdiag` in client F8 to verify the detected environment and obvious duplicate progress providers.
