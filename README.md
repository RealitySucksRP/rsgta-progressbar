# rsgta-progressbar

Dual style progress bar for FiveM. Style 1 is clean GTA V stock � flat, no branding, looks native. Style 2 is branded with your server logo, name, and accent color above the bar. Free release by RealitySucksRP.

---

## License

MIT License  Copyright (c) 2026 William Brito. Do whatever you want with it, just keep the credit. "Reality Sucks RP"

---

## Install

Drop the folder into your resources and add it to server.cfg before ox_lib:
No separate progressbar resource needed compatibility is built in.

---

## Branding it as your own

Four lines in config.lua and it is yours:

```lua
Config.BarStyle    = 2                  -- 1 = GTA V stock, 2 = branded
Config.ServerName  = "YOUR SERVER NAME"
Config.LogoFile    = "img/logo.png"     -- drop your logo in html/img/
Config.AccentColor = "#e8c840"          -- any hex color
```

The fill, glow, logo border all pull from that one color automatically.

---

## ox_lib (optional)

Open ox_lib/resource/interface/client/progress.lua, back it up, replace contents:

```lua
function lib.progressBar(data)
    return exports['rsgta-progressbar']:ox_lib_progressBar(data)
end
function lib.progressCircle(data)
    return exports['rsgta-progressbar']:ox_lib_progressBar(data)
end
function lib.cancelProgress()
    exports['rsgta-progressbar']:ox_lib_cancelProgress()
end
function lib.progressActive()
    return exports['rsgta-progressbar']:ox_lib_progressActive()
end
```

---

## Usage

```lua
exports['rsgta-progressbar']:Progress({
    label        = 'Picking lock...',
    duration     = 5000,
    canCancel    = true,
    cancelOnMove = false,
    animation = {
        dict = 'anim@heists@ornate_bank@hack',
        clip = 'hack_loop'
    },
}, function(cancelled)
    if not cancelled then
        -- do the thing
    end
end)
```

Any QBCore resource already calling exports progressbar Progress gets routed here automatically.

---

## Built-in actions

| Key       | Action                         |
|-----------|--------------------------------|
| U         | Toggle hands up                |
| G         | Revive nearest downed ped (3m) |
| BACKSPACE | Cancel active bar              |

All keys configurable in config.lua.

---

## Changelog

### 2.0.0
Rebuilt the callback system. Callbacks now fire correctly regardless of how the bar gets called QBCore native, direct export, ox_lib, all of it. Shim folder removed, compatibility lives inside the resource.

### 1.0.0
Initial release.
