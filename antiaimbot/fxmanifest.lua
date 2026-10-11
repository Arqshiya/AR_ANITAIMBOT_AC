--[[
      _     ____        _     ____ 
     / \   |  _ \      / \   / ___|
    / _ \  | |_) |    / _ \ | |    
   / ___ \ |  _ <    / ___ \| |___ 
  /_/   \_\|_| \_\  /_/   \_\\____|

          AR_AC AntiCheat
--]]

fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'AR_AC'
author 'AR_AC'
description 'AR_AC AntiCheat System'
version '1.0.0'

client_scripts {
    "source/client.lua",
}

server_scripts {
    "source/server.lua",
    "webhook.lua",
}

shared_script {'config.lua'}

escrow_ignore {
    'config.lua',  
    'webhook.lua',  
}

shared_scripts {
    "@ox_lib/init.lua",
}

dependencies {
    'ox_lib',
}

