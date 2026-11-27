Config = Config or {}

-- Enable only while testing. Adds detailed console diagnostics and /rsfieldtest,
-- plus /rsfieldqbtest for the QBCore wrapper/callback path.
Config.devMode = false

-- Fallback accent theme if custom styles are disabled.
Config.theme = 'default'
Config.locale = 'en'

-- Ten player-selectable full-frame designs, including Pip-Boi 420.
-- Colors: default/theme-0 lime, theme-1 amber, theme-2 cyan,
-- theme-3 crimson, theme-4 violet, theme-5 electric blue, theme-6 rose.
Config.style = {
    allowPlayerCustomization = true,
    defaultFrame = 'streetglass',
    defaultTheme = 'theme-2',
    defaultBar = 'auto', -- auto adapts the bar to the selected frame
    defaultEffects = 'full', -- full, low or off (cosmetic only)
}



-- Kept for compatibility with older Field Terminal configs.
Config.cancelKey = Config.cancelKey or 'X'

-- Physical case and all CRT elements resize together. Enhanced/Legacy
-- scaling is automatic, and the display is clamped to fit the viewport.
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

-- Drop all vehicle photos into html/assets/vehicles/ (no indexing needed).
-- Example: adder.webp, sultanrs.png, police.jpg, myaddoncarmodel.webp
-- Filenames should match the vehicle spawn/model names (case-insensitive keys,
-- use lowercase filenames on disk). Supported formats are tried in this order.
Config.vehicleImages = {
    enabled = true,
    autoNearby = true, -- detects a vehicle near the player for car-related tasks
    nearbyRadius = 5.0, -- meters, used only if the caller didn't supply a vehicle
    extensions = { 'webp', 'png', 'jpg', 'jpeg', 'avif' },
    -- Optional: map a spawn name to a different image filename, without extension.
    -- aliases = { police3 = 'police_cruiser', },
    aliases = {},
}

-- Generic Pip-Boi live-image support. The UI can show item, tool, vehicle, or
-- category images depending on what the caller passes. Drop your images into the
-- matching html/assets folder and use lowercase filenames without spaces.
Config.assetImages = {
    enabled = true,
    extensions = { 'webp', 'png', 'jpg', 'jpeg', 'avif' },
    folders = {
        items = 'items',
        vehicles = 'vehicles',
        categories = 'categories',
    },
    -- Built-in smart presets cover common names like water, bandage,
    -- cigarette, joint, beer, lockpick, advancedlockpick, hotwirekit, etc.
    useSmartPresets = true,
    -- Optional explicit aliases for item/tool/custom asset names.
    -- These override the smart presets when keys overlap.
    -- aliases = { water = 'water_bottle', firstaid = 'bandage' },
    aliases = {},
    -- Optional fallback image names inside html/assets/categories/.
    categoryDefaults = {
        consume = 'consume',
        food = 'food',
        drink = 'drink',
        medical = 'medical',
        drug = 'drug',
        alcohol = 'alcohol',
        ammo = 'ammo',
        smoke = 'smoke',
        tool = 'tool',
        vehicle = 'vehicle',
        craft = 'craft',
        gather = 'gather',
        carry = 'carry',
        search = 'search',
        misc = 'misc',
        general = 'general',
    },
}
