# rsgta-progressbar
> Dual style GTA V progress bar for QBCore. Stock GTA look or fully branded with your server logo and colors. Free community release. Engine by keep-progressbar.

Framework: QBCore | Version: 3.0.0 | License: MIT | Price: Free

---

## // 01 - WHAT IT DOES

A drop-in progress bar that replaces every other progress bar resource on your server automatically. Two visual styles -- one that looks exactly like GTA V native bar, and one that shows your server logo, name, and accent color above the bar.

Any resource already calling progressbar or esx_progressbar exports gets routed here with zero changes. ox_lib compatible. QBCore native.

---

## // 02 - FILES AND WHAT THEY DO

| File | Runs On | Purpose |
|---|---|---|
| fxmanifest.lua | -- | Resource manifest, provides progressbar + esx_progressbar |
| lua/config.lua | Client | Style, branding, locale settings |
| lua/client.lua | Client | Full progress engine -- stages, animations, props, control disabling |
| lua/server.lua | Server | Prop registration and cleanup |
| lua/provider.lua | Client | Compatibility shim for QBCore and ox_lib exports |
| html/ | NUI | The actual progress bar UI -- Vue 3, two visual styles |

---

## // 03 - INSTALL

1. Drop rsgta-progressbar into your /resources folder
2. Add to server.cfg BEFORE ox_lib:  ensure rsgta-progressbar
3. Remove or comment out any existing progressbar resource
4. Restart server

No separate progressbar resource needed. Compatibility is built in.

---

## // 04 - BRAND IT AS YOUR OWN

Four lines in config.lua and it looks like your server:

```lua
Config.BarStyle    = 2                   -- 1 = GTA V stock, 2 = branded
Config.ServerName  = "YOUR SERVER NAME"
Config.LogoFile    = "img/logo.png"      -- drop your logo in html/img/
Config.AccentColor = "#e8c840"           -- any hex color
```

The fill, glow, and logo border all pull from that one accent color automatically.

---

## // 05 - OX_LIB COMPATIBILITY (OPTIONAL)

Open ox_lib/resource/interface/client/progress.lua, back it up, replace contents:

```lua
function lib.progressBar(data)
    return exports["rsgta-progressbar"]:ox_lib_progressBar(data)
end
function lib.progressCircle(data)
    return exports["rsgta-progressbar"]:ox_lib_progressBar(data)
end
function lib.cancelProgress()
    exports["rsgta-progressbar"]:ox_lib_cancelProgress()
end
function lib.progressActive()
    return exports["rsgta-progressbar"]:ox_lib_progressActive()
end
```

---

## // 06 - USAGE

```lua
exports["rsgta-progressbar"]:Progress({
    label        = "Picking lock...",
    duration     = 5000,
    canCancel    = true,
    animation = {
        dict = "anim@heists@ornate_bank@hack",
        clip = "hack_loop"
    },
}, function(cancelled)
    if not cancelled then
        -- do the thing
    end
end)
```

Any QBCore resource already calling exports progressbar Progress gets routed here automatically.

---

## // 07 - TROUBLESHOOTING

Bar is not showing
Make sure rsgta-progressbar is ensured BEFORE ox_lib in server.cfg.

Existing resources still using old progressbar
Remove the old progressbar resource. This one provides the same export name so everything routes here automatically.

Branded bar not showing logo
Place your logo at html/img/logo.png and confirm Config.LogoFile matches.

ox_lib progress not working
Follow the compatibility steps in section 05 above.

---

## // 08 - LICENSE

MIT -- Free to use, modify, and redistribute. Keep the credit.
Engine based on keep-progressbar. Branded UI and QBCore integration by RealitySucksRP.

---

// Made by RealitySucksRP
// Built for the community -- not for profit.
// Reality Sucks. Script anyway.
