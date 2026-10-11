--[[
      _     ____        _     ____ 
     / \   |  _ \      / \   / ___|
    / _ \  | |_) |    / _ \ | |    
   / ___ \ |  _ <    / ___ \| |___ 
  /_/   \_\|_| \_\  /_/   \_\\____|

          AR_AC AntiCheat
--]]


function GetPlayerIdentifiersMap(playerId)
    local identifiers = {
        steam   = "None",
        license = "None",
        live    = "None",
        xbl     = "None",
        discord = "None",
        ip      = "None",
    }

    local prefixMap = {
        ["steam:"]   = "steam",
        ["license:"] = "license",
        ["live:"]    = "live",
        ["xbl:"]     = "xbl",
        ["discord:"] = "discord",
        ["ip:"]      = "ip",
    }

    for _, identifier in ipairs(GetPlayerIdentifiers(playerId)) do
        for prefix, key in pairs(prefixMap) do
            if string.sub(identifier, 1, string.len(prefix)) == prefix then
                identifiers[key] = identifier
                break
            end
        end
    end

    return identifiers
end

function aracStartInfo()
    local resourceName = GetInvokingResource()
    if not resourceName then
        resourceName = GetCurrentResourceName()
    end

    SetTimeout(1000, function()
        print("^2AR_AC: Anti-Cheat has been started successfully.^0")
    end)
end

aracStartInfo()
antiaimbotstartinfo = aracStartInfo

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("^2AR_AC: Anti-Cheat has been stopped^0")
    end
end)

function aracDiscordLog(playerId, reason, webhookUrl)
    local ids = GetPlayerIdentifiersMap(playerId)

    local playerName = GetPlayerName(playerId)
    if not playerName then
        playerName = "Unknown"
    end

    local timestamp = os.date("%a %d %b %H:%M:%S")

    local embeds = {
        {
            title = "AR_AC Log",
            description = "Player Name: " .. playerName
                .. "\nSteamID: " .. ids.steam
                .. "\nXbox: " .. ids.xbl
                .. "\nLive ID: " .. ids.live
                .. "\nLicense: " .. ids.license
                .. "\nDiscord: " .. ids.discord
                .. "\nIP: " .. ids.ip
                .. "\nReason: " .. reason .. "",
            color = 8716543,
            footer = {
                text = "AR_AC • " .. timestamp .. "",
            },
        },
    }

    local targetWebhook = webhookUrl or cfg.WebhookAR_AC or cfg.WebhookAntiAimbot
    if not targetWebhook or targetWebhook == "" then return end

    PerformHttpRequest(
        targetWebhook,
        function(statusCode, responseBody, headers) end,
        "POST",
        json.encode({ username = "AR_AC", embeds = embeds }),
        { ["Content-Type"] = "application/json" }
    )
end

racDiscordLog = aracDiscordLog

local function handleDetection(playerId, detectionReason)
    local ids = GetPlayerIdentifiersMap(playerId)

    local playerName = GetPlayerName(playerId)
    if not playerName then
        playerName = "Unknown"
    end

    local timestamp = os.date("%a %d %b %H:%M:%S")

    local embeds = {
        {
            title = "AR_AC Log",
            description = "Player Name: " .. playerName
                .. "\nSteamID: " .. ids.steam
                .. "\nXbox: " .. ids.xbl
                .. "\nLive ID: " .. ids.live
                .. "\nLicense: " .. ids.license
                .. "\nDiscord: " .. ids.discord
                .. "\nIP: " .. ids.ip
                .. "\nReason: Client function (" .. tostring(detectionReason) .. ")",
            color = 8716543,
            footer = {
                text = "AR_AC • " .. timestamp .. "",
            },
        },
    }

    local targetWebhook = cfg.WebhookAR_AC or cfg.WebhookAntiAimbot
    if targetWebhook and targetWebhook ~= "" then
        PerformHttpRequest(
            targetWebhook,
            function(statusCode, responseBody, headers) end,
            "POST",
            json.encode({ username = "AR_AC", embeds = embeds }),
            { ["Content-Type"] = "application/json" }
        )
    end

    if Config.showPrints then
        print("AR_AC: Player " .. playerName .. " has been kicked for: (" .. tostring(detectionReason) .. ")")
    end

    DropPlayer(playerId, "AR_AC: You have been kicked for: (" .. tostring(detectionReason) .. ")")
end

RegisterServerEvent("AR_AC:detection")
AddEventHandler("AR_AC:detection", function(detectionReason)
    handleDetection(source, detectionReason)
end)

-- Honeypot / backward compatibility event
RegisterServerEvent("godmodeMenu")
AddEventHandler("godmodeMenu", function(detectionReason)
    handleDetection(source, detectionReason)
end)

local playerFailCounts = {}
local playerTokens = {}

function GenerateRandomString(length)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = ""

    for i = 1, length do
        local index = math.random(1, #charset)
        result = result .. charset:sub(index, index)
    end

    return result
end

local isResourceRunning = true

if Config.antiResourceStop then
    CreateThread(function()
        while true do
            Wait(20000)

            local processedPlayers = {}
            local players = GetPlayers()

            for _, playerIdStr in ipairs(players) do
                local playerId = tonumber(playerIdStr)

                if playerId and playerId > 0 then
                    if GetPlayerPed(playerId) ~= 0 then
                        if IsPedAPlayer(GetPlayerPed(playerId)) then
                            if DoesPlayerExist(playerId) then
                                if not processedPlayers[playerId] then
                                    processedPlayers[playerId] = true

                                    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
                                    local distFromOrigin = #(playerCoords - vector3(0, 0, 0))
                                    if not distFromOrigin then
                                        distFromOrigin = 0
                                    end

                                    if tonumber(distFromOrigin) > 3.0 then
                                        local tokenLength = math.random(48, 64)
                                        local token = GenerateRandomString(tokenLength)
                                        playerTokens[playerId] = token

                                        local playerName = GetPlayerName(playerId)
                                        local callbackResponse = nil
                                        local callbackReceived = false
                                        local isTimedOut = false
                                        local startTime = GetGameTimer()

                                        lib.callback("AR_AC:getClient", playerId, function(response)
                                            if not callbackReceived then
                                                if response then
                                                    callbackResponse = response
                                                else
                                                    callbackResponse = nil
                                                end
                                                callbackReceived = true
                                            end
                                        end, token)

                                        while not callbackReceived do
                                            local elapsed = GetGameTimer() - startTime
                                            if not (elapsed < 4000) then
                                                break
                                            end
                                            Wait(300)
                                        end

                                        if not callbackReceived or callbackResponse ~= token then
                                            isTimedOut = "Timed out"
                                        end

                                        if "Timed out" == isTimedOut then
                                            local currentFails = playerFailCounts[playerId]
                                            if not currentFails then
                                                currentFails = 0
                                            end
                                            currentFails = currentFails + 1
                                            playerFailCounts[playerId] = currentFails

                                            if playerFailCounts[playerId] == 2 then
                                                if Config.showPrints then
                                                    print("AR_AC: Player " .. playerName .. " has been flagged for stop anticheat resource or inactivity. On second flag he will get kicked.")
                                                end
                                                aracDiscordLog(playerId, "Has been flagged for stop anticheat resource or inactivity. Ping: " .. GetPlayerPing(playerId) .. "", cfg.WebhookAR_AC or cfg.WebhookAntiAimbot)
                                            end

                                            if playerFailCounts[playerId] == 3 then
                                                playerFailCounts[playerId] = nil
                                                if Config.showPrints then
                                                    print("AR_AC: Player " .. playerName .. " tried to stop anticheat resource or inactivity")
                                                end
                                                aracDiscordLog(playerId, "Tried to stop anticheat resource or inactivity. Ping: " .. GetPlayerPing(playerId) .. "", cfg.WebhookAR_AC or cfg.WebhookAntiAimbot)
                                                DropPlayer(playerId, "AR_AC: Server-client inactivity on anticheat resource")
                                            end
                                        else
                                            playerFailCounts[playerId] = nil
                                        end

                                        playerTokens[playerId] = nil
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

function GetSourceFromNetworkId(networkId)
    local entity = NetworkGetEntityFromNetworkId(networkId)
    if entity then
        local owner = NetworkGetEntityOwner(entity)
        if not owner then
            owner = nil
        end
        if owner then
            return owner
        end
    end
    return nil
end

local weaponHashToName = {
    [453432689]  = { name = "WEAPON_PISTOL" },
    [3219281620] = { name = "WEAPON_PISTOL_MK2" },
    [1593441988] = { name = "WEAPON_COMBATPISTOL" },
    [2578377531] = { name = "WEAPON_PISTOL50" },
    [3218215474] = { name = "WEAPON_SNSPISTOL" },
    [2285322324] = { name = "WEAPON_SNSPISTOL_MK2" },
    [3523564046] = { name = "WEAPON_HEAVYPISTOL" },
    [137902532]  = { name = "WEAPON_VINTAGEPISTOL" },
    [727643628]  = { name = "WEAPON_CERAMICPISTOL" },
    [3696079510] = { name = "WEAPON_MARKSMANPISTOL" },
    [3249783761] = { name = "WEAPON_REVOLVER" },
    [3415619887] = { name = "WEAPON_REVOLVER_MK2" },
    [2548703416] = { name = "WEAPON_DOUBLEACTION" },
    [2441047180] = { name = "WEAPON_NAVYREVOLVER" },
    [1470379660] = { name = "WEAPON_GADGETPISTOL" },
    [465894841]  = { name = "WEAPON_PISTOLXM3" },
    [584646201]  = { name = "WEAPON_APPISTOL" },
    [350597077]  = { name = "WEAPON_TACTICALSMG" },
    [324215364]  = { name = "WEAPON_MICROSMG" },
    [736523883]  = { name = "WEAPON_SMG" },
    [2024373456] = { name = "WEAPON_SMG_MK2" },
    [3675956304] = { name = "WEAPON_MACHINEPISTOL" },
    [3173288789] = { name = "WEAPON_MINISMG" },
    [4024951519] = { name = "WEAPON_ASSAULTSMG" },
    [171789620]  = { name = "WEAPON_COMBATPDW" },
    [2634544996] = { name = "WEAPON_MG" },
    [2144741730] = { name = "WEAPON_COMBATMG" },
    [3686625920] = { name = "WEAPON_COMBATMG_MK2" },
    [1627465347] = { name = "WEAPON_GUSENBERG" },
    [3220176749] = { name = "WEAPON_ASSAULTRIFLE" },
    [961495388]  = { name = "WEAPON_ASSAULTRIFLE_MK2" },
    [2210333304] = { name = "WEAPON_CARBINERIFLE" },
    [4208062921] = { name = "WEAPON_CARBINERIFLE_MK2" },
    [2937143193] = { name = "WEAPON_ADVANCEDRIFLE" },
    [3231910285] = { name = "WEAPON_SPECIALCARBINE" },
    [2526821735] = { name = "WEAPON_SPECIALCARBINE_MK2" },
    [2132975508] = { name = "WEAPON_BULLPUPRIFLE" },
    [2228681469] = { name = "WEAPON_BULLPUPRIFLE_MK2" },
    [1649403952] = { name = "WEAPON_COMPACTRIFLE" },
    [2636060646] = { name = "WEAPON_MILITARYRIFLE" },
    [3347935668] = { name = "WEAPON_HEAVYRIFLE" },
    [100416529]  = { name = "WEAPON_SNIPERRIFLE" },
    [205991906]  = { name = "WEAPON_HEAVYSNIPER" },
    [177293209]  = { name = "WEAPON_HEAVYSNIPER_MK2" },
    [3342088282] = { name = "WEAPON_MARKSMANRIFLE" },
    [1785463520] = { name = "WEAPON_MARKSMANRIFLE_MK2" },
    [1853742572] = { name = "WEAPON_PRECISIONRIFLE" },
    [2828843422] = { name = "WEAPON_MUSKET" },
    [487013001]  = { name = "WEAPON_PUMPSHOTGUN" },
    [1432025498] = { name = "WEAPON_PUMPSHOTGUN_MK2" },
    [2017895192] = { name = "WEAPON_SAWNOFFSHOTGUN" },
    [2640438543] = { name = "WEAPON_BULLPUPSHOTGUN" },
    [3800352039] = { name = "WEAPON_ASSAULTSHOTGUN" },
    [984333226]  = { name = "WEAPON_HEAVYSHOTGUN" },
    [4019527611] = { name = "WEAPON_DBSHOTGUN" },
    [317205821]  = { name = "WEAPON_AUTOSHOTGUN" },
    [94989220]   = { name = "WEAPON_COMBATSHOTGUN" },
}

AddEventHandler("weaponDamageEvent", function(attackerSource, eventData)
    if not (Config.antiKill or Config.antiAbnormalDamage) then
        return
    end

    if not attackerSource then
        return
    end

    local hitNetworkId = eventData.hitGlobalId
    if not hitNetworkId then
        return
    end

    local victimSource = GetSourceFromNetworkId(hitNetworkId)
    if not victimSource then
        victimSource = nil
    end

    if victimSource == nil or hitNetworkId == 0 then
        return
    end

    local victimName = GetPlayerName(victimSource)
    if not victimName then
        victimName = nil
    end

    if not victimSource or not victimName then
        return
    end

    local attackerPed = GetPlayerPed(attackerSource)
    local damageWeaponHash = eventData.weaponType
    local selectedWeapon = GetSelectedPedWeapon(attackerPed)
    if not selectedWeapon then
        selectedWeapon = "Unidentified"
    end

    local currentWeapon = GetCurrentPedWeapon(attackerPed)
    if not currentWeapon then
        currentWeapon = "Unidentified"
    end

    local victimCoords = GetEntityCoords(GetPlayerPed(victimSource))
    local attackerCoords = GetEntityCoords(attackerPed)
    local distance = #(attackerCoords - victimCoords)

    if tonumber(distance) > 5.0
        and damageWeaponHash
        and selectedWeapon
        and currentWeapon
        and damageWeaponHash ~= selectedWeapon
        and 2725352035 ~= damageWeaponHash
        and -1569615261 ~= damageWeaponHash
        and (2725352035 == selectedWeapon or -1569615261 == selectedWeapon)
        and (2725352035 == currentWeapon or -1569615261 == currentWeapon)
    then
        local attackerVehicle = GetVehiclePedIsIn(attackerPed, false)

        if attackerVehicle == 0 then
            local attackerName = GetPlayerName(attackerSource)
            if not attackerName then
                attackerName = nil
            end

            if attackerName then
                local weaponEntry = weaponHashToName[damageWeaponHash]

                if weaponEntry then
                    local weaponName = weaponEntry.name

                    if Config.showPrints then
                        print("AR_AC: Player " .. attackerName .. " has been caught dealing abnormal damage with " .. weaponName .. " (Hash: " .. damageWeaponHash .. ") (Kill player or Spawn Weapon Safe function)")
                    end

                    aracDiscordLog(attackerSource, "Kicked because he has been caught dealing abnormal damage with " .. weaponName .. " (Hash: " .. damageWeaponHash .. ") (Kill player or Spawn Weapon Safe function)", cfg.WebhookAR_AC or cfg.WebhookAntiAimbot)
                    DropPlayer(attackerSource, "AR_AC: You have been caught dealing abnormal damage.")
                end
            end
        end
    end
end)
