Config = Config or {}

-- Enable only while testing. Adds detailed console diagnostics and /rsfieldtest,
-- plus /rsfieldqbtest for the QBCore wrapper/callback path.
Config.devMode = false

-- Field Terminal visual theme.
Config.theme = 'default'
Config.locale = 'en'

-- Kept for compatibility with older Field Terminal configs.
Config.cancelKey = Config.cancelKey or 'X'

-- The Field Terminal UI already has its own Enhanced/Legacy scale shim.
-- The universal engine still sends neutral layout values; this UI ignores
-- location text unless a future theme chooses to display it.
Config.ui = {
    scale = 1.0,
    bottomOffset = 0,
    showLocation = false,
}

-- QBCore/Qbox inventory-busy compatibility. This state bag is harmless on
-- ESX/standalone and is only cleared when this resource acquired it itself.
Config.useInventoryBusyState = true

Config.cancel = {
    enabled = true,
    key = Config.cancelKey,
    legacyCommand = false,
}

-- Cancels a wedged action if the NUI never reports completion. This prevents
-- stuck controls, props, animations, or inventory busy state.
Config.watchdog = {
    enabled = true,
    graceMs = 5000,
}
