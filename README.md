# RS Progressbar Studio

<a href="https://reality-sucks-rp-webstore.tebex.io/package/7667590"><img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/77c4b63355f6f0a2fea03ca8c9504cef74cf9b3c.png" width="100%" alt="RS Progressbar Studio – 10 immersive frames"></a>

**Free | Full source | FiveM Legacy and Enhanced | Qbox, QBCore, ESX and Standalone**

A customizable FiveM progress interface with ten device-inspired frames, animated progress effects, a live customization studio and action-specific imagery. Built for roleplay, survival and standalone servers.

[Free on Tebex](https://reality-sucks-rp-webstore.tebex.io/package/7667590) | [Website](https://realitysucksrp.github.io/) | [Discord](https://discord.gg/e9V3rPHySx) | [YouTube](https://www.youtube.com/@RealitySucksRP) | [All free scripts](https://reality-sucks-rp-webstore.tebex.io/category/free-scripts)

> **Version:** 4.4.17. The GitHub source matches the supplied Studio package.

## Frame Studio

- Ten selectable frames with eight accent choices and five manual progress styles plus automatic selection.
- Live preview, playback, saved cosmetic preferences and adjustable scaling.
- Full, Low and Off visual effects settings.
- Action-specific imagery for vehicle and item interactions, with percentage and remaining-time indicators.

## Screenshots

<img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/e3ee449660250a55f3ad8589ed9f654d0a5a4079.png" width="100%" alt="Pip-Boi 420 Frame Studio">

<img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/707a9521f283eecd37ce09bc9047006114245e17.png" width="100%" alt="Tactical Grid live preview">

<img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/a99743657e20a4dca5600d73f5d727bcdfa23e76.png" width="100%" alt="Street Glass customization">

<img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/3a6870b30e3f25f13c83eeafa3d537c2e8e4e442.png" width="100%" alt="Medical interaction">

<img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/2773c2633da8bdf02575c9981c0c92d13fe7574e.png" width="100%" alt="Violet Syndicate">

<img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/08fc0bdb8fcbdba2c38ca31f9ff38320b2ba5b9a.png" width="100%" alt="Neon Runner">

## Progress engine

- Single-stage and multi-stage actions, animations and scenarios.
- Up to five validated attached props per action.
- Configurable cancellation and control restrictions.
- Lua-authoritative completion handling, watchdog recovery and resource-stop cleanup.
- No required framework, inventory or database dependency.

## Installation and compatibility

Keep the resource folder named `progressbar`. Run only one provider for the same progress API. Start your framework (if used) before the progressbar and start its consumers afterward.

```cfg
ensure progressbar
```

QBCore and Qbox support QB-compatible progress calls; ESX supports the ESX progress interface. Direct exports support standalone and custom integrations. Native ox_lib calls require the optional adapter if you intend to redirect them.

Run `rsprogressdiag` from client F8 to check the installed version and provider state.

[Installation guide](INSTALL.md) | [Developer API](DEVELOPER-API.md) | [Download ZIP](https://github.com/RealitySucksRP/rsgta-progressbar/releases/latest/download/progressbar.zip) | [GitHub releases](https://github.com/RealitySucksRP/rsgta-progressbar/releases)

## License

GPL-3.0-only, derived in part from swkeep/keep-progressbar. See [license](LICENSE.md), [COPYING](COPYING) and [third-party notices](THIRD_PARTY_NOTICES.md). 
