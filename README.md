# rsgta-progressbar

> Dual-style GTA V progress bar for QBCore. Stock GTA look or fully branded with your server logo and colors. Free community release. Engine by keep-progressbar.

<p align="center">
  <a href="https://reality-sucks-rp-webstore.tebex.io/category/free-scripts"><img src="https://img.shields.io/badge/BROWSE-FREE%20SCRIPTS-ff6a00?style=for-the-badge" alt="Browse RealitySucksRP free scripts on Tebex"></a>
  <a href="https://reality-sucks-rp-webstore.tebex.io/"><img src="https://img.shields.io/badge/SHOP-FULL%20TEBEX%20STORE-111111?style=for-the-badge" alt="Browse RealitySucksRP Tebex Store"></a>
  <a href="https://discord.gg/e9V3rPHySx"><img src="https://img.shields.io/badge/JOIN-DISCORD-5865F2?style=for-the-badge" alt="Join RealitySucksRP Discord"></a>
</p>

> I build my own FiveM systems and complete server setups: UI, phones, shops, weapons, racing, LS Customs, garages, dealerships, zombie apocalypse systems, warfare and Phantom encounters.

Framework: QBCore | License: MIT | Price: Free

## // 01 - WHAT IT DOES

A drop-in progress bar that replaces other progress bar resources automatically. Two visual styles: one that looks like a GTA V native bar, and one that shows your server name, logo and accent colors.

Any resource already calling progressbar or esx_progressbar exports can be routed here with zero changes. ox_lib compatible. QBCore native.

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

1. Drop rsgta-progressbar into your `/resources` folder.
2. Add it to `server.cfg` BEFORE ox_lib: `ensure rsgta-progressbar`
3. Remove or comment out any existing progressbar resource.
4. Restart the server.

No separate progressbar resource is needed. Compatibility is built in.

---

## // 04 - BRAND IT AS YOUR OWN

Four lines in `config.lua` and it looks like your server:

```lua
Config.BarStyle    = 2
Config.ServerName  = "YOUR SERVER NAME"
Config.LogoFile    = "img/logo.png"
Config.AccentColor = "#e8c840"
```

The fill, glow and logo border all pull from that one accent color automatically.

---

## // 05 - OX_LIB COMPATIBILITY (OPTIONAL)

Open `ox_lib/resource/interface/client/progress.lua`, back it up, replace contents:

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
    label = "Picking lock...",
    duration = 5000,
    canCancel = true,
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

Any QBCore resource already calling the progressbar `Progress` export can be routed here automatically.

---

## // 07 - TROUBLESHOOTING

**Bar is not showing**  
Make sure `rsgta-progressbar` is ensured BEFORE ox_lib in `server.cfg`.

**Existing resources still using old progressbar**  
Remove the old progressbar resource. This one provides the same export name so everything routes here automatically.

**Branded bar not showing logo**  
Place your logo at `html/img/logo.png` and confirm `Config.LogoFile` matches.

**ox_lib progress not working**  
Follow the compatibility steps in section 05 above.

---

## More From RealitySucksRP

**Tebex:** https://reality-sucks-rp-webstore.tebex.io/

**Website:** https://realitysucksrp.github.io/

**Discord:** https://discord.gg/e9V3rPHySx

## // 08 - LICENSE

MIT -- Free to use, modify and redistribute. Keep the credit.
Engine based on keep-progressbar. Branded UI and QBCore integration by RealitySucksRP.

---

// Made by RealitySucksRP  
// Reality Sucks. Script anyway.