# Optional ox_lib bridge

## Do not install this if your Ox setup already works

If Ox Core + ox_inventory is already displaying RS Field Terminal Progressbar correctly for the resources you care about, leave ox_lib unchanged.

This bridge is only for servers that deliberately want hardcoded:

```lua
lib.progressBar(data)
lib.progressCircle(data)
```

to render through RS Field Terminal Progressbar.

## Install

1. Start from the original `ox_lib/resource/interface/client/progress.lua` for the exact ox_lib version you run.
2. Do not delete or replace ox_lib's original progress functions.
3. Open `RS-FIELD-TERMINAL-OX-BRIDGE.lua`.
4. Append the complete bridge block to the very bottom of ox_lib's original `progress.lua`.
5. Ensure `progressbar` is started.
6. Fully restart the server.

The bridge stores ox_lib's original functions as fallback and uses the normal ox_lib implementation whenever RS Field Terminal Progressbar is unavailable.

An ox_lib update may replace `progress.lua`; if you use this optional bridge, reapply it to the new original file after updating.
