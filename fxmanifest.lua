fx_version 'cerulean'
game 'gta5'
name 'RS Progressbar Studio'
author 'RealitySucksRP / William Brito'
description 'Universal multi-frame progress system for QBCore, Qbox, ESX, ox-style integrations, and standalone FiveM resources.'
rs_field_terminal_progressbar 'yes'
version '4.4.17'

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
    'html/assets/pipboi-420-shell.webp',
    'html/assets/rs-logo.png',
    'html/assets/frames/*.webp',
    'html/assets/vehicles/*',
    'html/assets/items/*',
    'html/assets/categories/*',
    'html/style.css',
    'html/themes.css',
    'html/frames.css',
    'html/customizer.css',
    'html/customizer.js',
    'html/script.js',
    'html/effects.css',
    'html/effects.js',
}

-- Keep the extracted folder named exactly `progressbar` for maximum compatibility.
-- These aliases cover older RS/ESX dependency names without requiring a second resource.
provide 'rsfield-progressbar'
provide 'esx_progressbar'
provide 'qb-progressbar'
