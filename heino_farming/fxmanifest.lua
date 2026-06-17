fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Heino'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.json',
}

client_script 'client/main.lua'

server_scripts {
    'server/server.lua',
    'server/loka.lua',
}