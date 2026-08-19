fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'titan-pizzadelivery'
author 'Titan Scripts'
description '[Titan Scripts] Pizza Delivery Job - server-authoritative, ox_lib/ox_inventory/ox_target'
version '1.0.0'
repository 'https://github.com/titan-scripts/titan-pizzadelivery'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}
