fx_version 'cerulean'
game 'gta5'
name 'RS Field Terminal Progressbar'
author 'RealitySucksRP / William Brito'
description 'Universal field-terminal progress system for QBCore, Qbox, ESX, ox-style integrations, and standalone FiveM resources.'
rs_field_terminal_progressbar 'yes'
version '4.3.0'

ui_page 'html/index.html'

client_scripts {
    'lua/config.lua',
    'lua/client.lua',
    'lua/locales/*.lua',
    'lua/provider.lua',
}

server_script 'lua/server.lua'

files {
    'html/index.html',
    'html/rs-uiscale.js',
    'html/style.css',
    'html/themes.css',
    'html/script.js',
}

-- Keep the extracted folder named exactly `progressbar` for maximum compatibility.
-- These aliases cover older RS/ESX dependency names without requiring a second resource.
provide 'rsfield-progressbar'
provide 'esx_progressbar'
provide 'qb-progressbar'
