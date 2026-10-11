--[[
      _     ____        _     ____ 
     / \   |  _ \      / \   / ___|
    / _ \  | |_) |    / _ \ | |    
   / ___ \ |  _ <    / ___ \| |___ 
  /_/   \_\|_| \_\  /_/   \_\____|

          AR_AC AntiCheat
--]]


local SCOPED_WEAPON_HASHES = {
    [205991906]  = true,  
    [177293209]  = true,  
    [-952879014] = true,  
    [1785463520] = true,  
    [100416529]  = true,  
    [1853742572] = true,  
}

function IsScopedWeapon(weaponHash)
    return SCOPED_WEAPON_HASHES[weaponHash] == true
end

function CorrectCameraAim()
    local currentWeapon = GetSelectedPedWeapon(PlayerPedId())
    if IsScopedWeapon(currentWeapon) then
        return
    end

    local heading = GetGameplayCamRelativeHeading()
    local camRot = GetGameplayCamRot(0)
    local pitch = GetGameplayCamRelativePitch()

    SetGameplayCamRelativePitch(pitch - 0.0, 0.0)
    SetGameplayCamRelativeHeading(heading)
end

if Config.showPrints then
    print("^0AR_AC: Anti-Cheat has been started ^2successfully^0.")
end

Citizen.CreateThread(function()
    while true do
        if IsPedArmed(PlayerPedId(), 4) then
            Citizen.Wait(0)

            if Config.antiAimbotRpf then
                startAntiController()
                startAntiAimbotRpf()
            end

            if true == Config.antiAimbot1 then
                if false == Config.antiAimbot2 then
                    startAntiAimbot1()
                end
            end

            if Config.antiAimbot2 then
                startAntiAimbot2()
            end

            if Config.antiSilentAim then
                startAntiSilentAimbot()
            end

            if Config.antiTriggerbot then
                startAntiTriggerbot2()
                startAntiTriggerbot3()
            end

            if IsPedArmed(PlayerPedId(), 4) then
                goto continue
            end

            if Config.antiAimbot1 or Config.antiAimbot2 then
                SetPedConfigFlag(PlayerPedId(), 43, false)
                SetPlayerLockon(PlayerId(), true)
                SetPlayerLockonRangeOverride(PlayerId(), 3.0)
            end

            if Config.antiSilentAim then
                resetDamageModifierAntiSilentAimbot()
            end

            Citizen.Wait(500)
        else
            Citizen.Wait(500)
        end
        ::continue::
    end
end)

function startAntiController()
    SetPlayerTargetingMode(3)
    NetworkResetBodyTracker()
end

function startAntiAimbotRpf()
    SetPedConfigFlag(PlayerPedId(), 43, true)

    local lockOnDistance = GetLockonDistanceOfCurrentPedWeapon(PlayerPedId())
    if lockOnDistance > 500.0 then
        SetPlayerLockon(PlayerId(), false)
        SetPlayerLockonRangeOverride(PlayerId(), -1.0)
    end
end

local isFirstAim = true

function startAntiAimbot1()
    if IsAimCamActive() then
        if isFirstAim then
            Wait(350)
            CorrectCameraAim()
            isFirstAim = false
        else
            CorrectCameraAim()
        end
    else
        isFirstAim = true
    end
end

function startAntiAimbot2()
    if not IsAimCamActive() then
        if not IsControlPressed(0, 25) then
            return
        end
    end

    CorrectCameraAim()
end

local weaponDamageCache = {}
local lastDamageModifier = 0.0

function startAntiSilentAimbot()
    local playerPed = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(playerPed)
    local currentDamageModifier = GetWeaponDamageModifier(currentWeapon)

    if weaponDamageCache[currentWeapon] == nil then
        if tonumber(currentDamageModifier) > 0 then
            weaponDamageCache[currentWeapon] = currentDamageModifier
        end
    end

    local cachedModifier = weaponDamageCache[currentWeapon]
    if not cachedModifier then
        return
    end

    local newModifier = nil
    local isFreeAiming, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())

    if isFreeAiming and 0 ~= targetEntity then
        if IsEntityAPed(targetEntity) then
            newModifier = weaponDamageCache[currentWeapon]
            lastDamageModifier = newModifier
        end
    else
        newModifier = 0.0
    end

    SetPlayerWeaponDamageModifier(PlayerId(), newModifier)
    SetAiWeaponDamageModifier(newModifier)
    SetWeaponDamageModifier(currentWeapon, newModifier)
end

function resetDamageModifierAntiSilentAimbot()
    for weaponHash, modifier in pairs(weaponDamageCache) do
        SetWeaponDamageModifier(weaponHash, modifier)
    end
end

if Config.antiSilentAim then
    AddEventHandler("onResourceStop", function(resourceName)
        for weaponHash, modifier in pairs(weaponDamageCache) do
            SetWeaponDamageModifier(weaponHash, modifier)
        end
    end)
end

if Config.antiAimbot1 or Config.antiAimbot2 then
    AddEventHandler("CEventGunShot", function(entities, eventEntity, args)
        local playerPed = PlayerPedId()
        if eventEntity ~= playerPed then
            return
        end

        if not IsPedArmed(PlayerPedId(), 4) then
            return
        end

        local currentWeapon = GetSelectedPedWeapon(PlayerPedId())
        if IsScopedWeapon(currentWeapon) then
            return
        end

        if not IsPedInAnyVehicle(PlayerPedId()) then
            local heading = GetEntityHeading(PlayerId())
            local camRot = GetGameplayCamRot(0)
            local pitch = GetGameplayCamRelativePitch()

            SetGameplayCamRelativePitch(pitch - 0.0, 0.0)
            SetGameplayCamRelativeHeading(heading - camRot.y)
        else
            local heading = GetEntityHeading(PlayerId())
            local camRot = GetGameplayCamRot(0)
            local pitch = GetGameplayCamRelativePitch()

            SetGameplayCamRelativePitch(pitch - 0.0, 0.0)
        end
    end)
end

local triggerbotCounter1 = 0

if Config.antiTriggerbot then
    AddEventHandler("CEventGunShot", function(entities, eventEntity, args)
        if eventEntity ~= PlayerPedId() then
            return
        end

        if IsPedShooting(PlayerPedId()) then
            triggerbotCounter1 = 0
        else
            triggerbotCounter1 = triggerbotCounter1 + 1
            if triggerbotCounter1 >= 5 then
                if Config.antiTriggerbot then
                    print("AR_AC: You have been detected with trigger bot #1")
                    TriggerServerEvent("AR_AC:detection", "Trigger bot #1")
                    ForceSocialClubUpdate()
                end
            end
        end
    end)
end

local shootControls = {24, 257}
local triggerbotCounter2 = 0

function startAntiTriggerbot2()
    local isShootButtonPressed = false

    if not IsPedShooting(PlayerPedId()) then
        return
    end

    if not HasPlayerDamagedAtLeastOnePed(PlayerId()) then
        return
    end

    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return
    end

    local isFreeAiming, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if not isFreeAiming or targetEntity == 0 then
        return
    end

    if not IsEntityAPed(targetEntity) then
        return
    end

    if not GetEntityCanBeDamaged(targetEntity) then
        return
    end

    if GetPlayerInvincible(targetEntity) then
        return
    end

    for _, controlId in ipairs(shootControls) do
        if IsControlPressed(0, controlId) or IsControlJustPressed(0, controlId) then
            isShootButtonPressed = true
            break
        end
    end

    if not isShootButtonPressed then
        triggerbotCounter2 = triggerbotCounter2 + 1
        if triggerbotCounter2 >= 3 then
            if Config.antiTriggerbot then
                print("AR_AC: You have been detected with trigger bot #2")
                TriggerServerEvent("AR_AC:detection", "Trigger bot #2")
                ForceSocialClubUpdate()
            end
        end
    else
        triggerbotCounter2 = 0
    end
end

local triggerbotCounter3 = 0

function startAntiTriggerbot3()
    if not IsPedShooting(PlayerPedId()) then
        return
    end

    if not HasPlayerDamagedAtLeastOnePed(PlayerId()) then
        return
    end

    local isFreeAiming, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if not isFreeAiming or targetEntity == 0 then
        return
    end

    if not IsEntityAPed(targetEntity) then
        return
    end

    if not GetEntityCanBeDamaged(targetEntity) then
        return
    end

    if GetPlayerInvincible(targetEntity) then
        return
    end

    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)

    local direction = vector3(
        -math.sin(math.rad(camRot.z)),
        math.cos(math.rad(camRot.z)),
        math.sin(math.rad(camRot.x))
    )

    local endCoord = camCoord + direction * 100.0

    local rayHandle = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z,
        endCoord.x, endCoord.y, endCoord.z,
        8, PlayerPedId(), 0
    )

    local _, didHit, hitCoord, _, hitEntity = GetShapeTestResult(rayHandle)

    if didHit and hitEntity == targetEntity then
        local headCoord = GetPedBoneCoords(targetEntity, 31086, 0.0, 0.0, 0.0)
        local distanceFromHead = #(hitCoord - headCoord)

        local wasHeadshot, damageBone = GetPedLastDamageBone(targetEntity)

        if wasHeadshot and damageBone == 31086 then
            if distanceFromHead >= 0.4 then
                triggerbotCounter3 = triggerbotCounter3 + 1
                if triggerbotCounter3 >= 3 then
                    if Config.antiTriggerbot then
                        print("AR_AC: You have been detected with trigger bot #3")
                        TriggerServerEvent("AR_AC:detection", "Trigger bot #3. Distance from the head: " .. distanceFromHead .. "m.")
                        ForceSocialClubUpdate()
                    end
                end
            else
                triggerbotCounter3 = 0
            end
        end
    end
end

local spawnWeaponCounter1 = 0
local SPAWN_WEAPON_THRESHOLD = 5

AddEventHandler("CEventGunShot", function(entities, eventEntity, args)
    if not Config.antiSpawnWeaponSafe then
        return
    end

    if eventEntity ~= PlayerPedId() then
        return
    end

    if IsPedArmed(PlayerPedId(), 1) or IsPedArmed(PlayerPedId(), 2) or IsPedArmed(PlayerPedId(), 4) then
        spawnWeaponCounter1 = 0
        return
    end

    spawnWeaponCounter1 = spawnWeaponCounter1 + 1
    if spawnWeaponCounter1 > SPAWN_WEAPON_THRESHOLD then
        print("AR_AC: You have been caught with a spawned safe weapon")
        spawnWeaponCounter1 = 0
        SetCurrentPedWeapon(PlayerPedId(), GetHashKey("WEAPON_UNARMED"), true)
        Wait(5000)
        TriggerServerEvent("AR_AC:detection", "Spawned safe weapon #1")
        ForceSocialClubUpdate()
    end
end)

local spawnWeaponCounter2 = 0
local SPAWN_WEAPON_THRESHOLD_2 = 5

AddEventHandler("CEventGunShot", function(entities, eventEntity, args)
    if not Config.antiSpawnWeaponSafe then
        return
    end

    if eventEntity ~= PlayerPedId() then
        return
    end

    local currentWeapon = GetSelectedPedWeapon(PlayerPedId())
    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
        spawnWeaponCounter2 = 0
        return
    end

    spawnWeaponCounter2 = spawnWeaponCounter2 + 1
    if spawnWeaponCounter2 > SPAWN_WEAPON_THRESHOLD_2 then
        print("AR_AC: You have been caught with a spawned safe weapon")
        spawnWeaponCounter2 = 0
        SetCurrentPedWeapon(PlayerPedId(), GetHashKey("WEAPON_UNARMED"), true)
        Wait(5000)
        TriggerServerEvent("AR_AC:detection", "Spawned safe weapon #2")
        ForceSocialClubUpdate()
    end
end)

function RemoveWeaponPickups()
    local pickupNames = {
        "PICKUP_ARMOUR_STANDARD",
        "PICKUP_CAMERA",
        "PICKUP_CUSTOM_SCRIPT",
        "PICKUP_GANG_ATTACK_MONEY",
        "PICKUP_HEALTH_SNACK",
        "PICKUP_HEALTH_STANDARD",
        "PICKUP_MONEY_CASE",
        "PICKUP_MONEY_DEP_BAG",
        "PICKUP_MONEY_MED_BAG",
        "PICKUP_MONEY_PAPER_BAG",
        "PICKUP_MONEY_PURSE",
        "PICKUP_MONEY_SECURITY_CASE",
        "PICKUP_MONEY_VARIABLE",
        "PICKUP_MONEY_WALLET",
        "PICKUP_PARACHUTE",
        "PICKUP_PORTABLE_CRATE_FIXED_INCAR",
        "PICKUP_PORTABLE_CRATE_UNFIXED_INCAR_SMALL",
        "PICKUP_PORTABLE_CRATE_UNFIXED_INCAR",
        "PICKUP_PORTABLE_CRATE_UNFIXED_LOW_GLOW",
        "PICKUP_PORTABLE_CRATE_UNFIXED",
        "PICKUP_PORTABLE_DLC_VEHICLE_PACKAGE",
        "PICKUP_PORTABLE_PACKAGE",
        "PICKUP_SUBMARINE",
        "PICKUP_VEHICLE_ARMOUR_STANDARD",
        "PICKUP_VEHICLE_CUSTOM_SCRIPT_LOW_GLOW",
        "PICKUP_VEHICLE_CUSTOM_SCRIPT",
        "PICKUP_VEHICLE_HEALTH_STANDARD_LOW_GLOW",
        "PICKUP_VEHICLE_HEALTH_STANDARD",
        "PICKUP_VEHICLE_MONEY_VARIABLE",
        "PICKUP_VEHICLE_WEAPON_APPISTOL",
        "PICKUP_VEHICLE_WEAPON_ASSAULTRIFLE",
        "PICKUP_VEHICLE_WEAPON_ASSAULTSMG",
        "PICKUP_VEHICLE_WEAPON_COMBATPISTOL",
        "PICKUP_VEHICLE_WEAPON_GRENADE",
        "PICKUP_VEHICLE_WEAPON_MICROSMG",
        "PICKUP_VEHICLE_WEAPON_MOLOTOV",
        "PICKUP_VEHICLE_WEAPON_PISTOL",
        "PICKUP_VEHICLE_WEAPON_PISTOL50",
        "PICKUP_VEHICLE_WEAPON_SAWNOFF",
        "PICKUP_VEHICLE_WEAPON_SMG",
        "PICKUP_VEHICLE_WEAPON_SMOKEGRENADE",
        "PICKUP_VEHICLE_WEAPON_STICKYBOMB",
        "PICKUP_WEAPON_ASSAULTRIFLE_MK2",
        "PICKUP_WEAPON_BULLPUPRIFLE_MK2",
        "PICKUP_WEAPON_CARBINERIFLE_MK2",
        "PICKUP_WEAPON_COMBATMG_MK2",
        "PICKUP_WEAPON_DOUBLEACTION",
        "PICKUP_WEAPON_GolfClub",
        "PICKUP_WEAPON_GOLFCLUB",
        "PICKUP_WEAPON_HEAVYSNIPER_MK2",
        "PICKUP_WEAPON_MARKSMANRIFLE_MK2",
        "PICKUP_WEAPON_PISTOL_MK2",
        "PICKUP_WEAPON_PUMPSHOTGUN_MK2",
        "PICKUP_WEAPON_RAYCARBIN",
        "PICKUP_WEAPON_RAYCARBINE",
        "PICKUP_WEAPON_RAYMINIGUN",
        "PICKUP_WEAPON_RAYPISTOL",
        "PICKUP_WEAPON_REVOLVER_MK2",
        "PICKUP_WEAPON_SMG_MK2",
        "PICKUP_WEAPON_SNSPISTOL_MK2",
        "PICKUP_WEAPON_SPECIALCARBINE_MK2",
        "PICKUP_WEAPON_STONE_HATCHET",
        "PICKUP_WEAPON_WRENC",
        "PICKUP_WEAPON_WRENCH",
        "PICKUP_VEHICLE_WEAPON_ASSAULTRIFLE",
        "PICKUP_ARMOUR_STANDARD",
        "PICKUP_CAMERA",
        "PICKUP_CUSTOM_SCRIPT",
        "PICKUP_GANG_ATTACK_MONEY",
        "PICKUP_HEALTH_SNACK",
        "PICKUP_HEALTH_STANDARD",
        "PICKUP_MONEY_CASE",
        "PICKUP_MONEY_DEP_BAG",
        "PICKUP_MONEY_MED_BAG",
        "PICKUP_MONEY_PAPER_BAG",
        "PICKUP_MONEY_PURSE",
        "PICKUP_MONEY_SECURITY_CASE",
        "PICKUP_MONEY_VARIABLE",
        "PICKUP_MONEY_WALLET",
        "PICKUP_PARACHUTE",
        "PICKUP_PORTABLE_CRATE_FIXED_INCAR",
        "PICKUP_PORTABLE_CRATE_UNFIXED",
        "PICKUP_PORTABLE_CRATE_UNFIXED_INCAR",
        "PICKUP_PORTABLE_CRATE_UNFIXED_INCAR_SMALL",
        "PICKUP_PORTABLE_CRATE_UNFIXED_LOW_GLOW",
        "PICKUP_PORTABLE_DLC_VEHICLE_PACKAGE",
        "PICKUP_PORTABLE_PACKAGE",
        "PICKUP_SUBMARINE",
        "PICKUP_VEHICLE_ARMOUR_STANDARD",
        "PICKUP_VEHICLE_CUSTOM_SCRIPT",
        "PICKUP_VEHICLE_CUSTOM_SCRIPT_LOW_GLOW",
        "PICKUP_VEHICLE_HEALTH_STANDARD",
        "PICKUP_VEHICLE_HEALTH_STANDARD_LOW_GLOW",
        "PICKUP_VEHICLE_MONEY_VARIABLE",
        "PICKUP_VEHICLE_WEAPON_APPISTOL",
        "PICKUP_VEHICLE_WEAPON_ASSAULTSMG",
        "PICKUP_VEHICLE_WEAPON_COMBATPISTOL",
        "PICKUP_VEHICLE_WEAPON_GRENADE",
        "PICKUP_VEHICLE_WEAPON_MICROSMG",
        "PICKUP_VEHICLE_WEAPON_MOLOTOV",
        "PICKUP_VEHICLE_WEAPON_PISTOL",
        "PICKUP_VEHICLE_WEAPON_PISTOL50",
        "PICKUP_VEHICLE_WEAPON_SAWNOFF",
        "PICKUP_VEHICLE_WEAPON_SMG",
        "PICKUP_VEHICLE_WEAPON_SMOKEGRENADE",
        "PICKUP_VEHICLE_WEAPON_STICKYBOMB",
        "PICKUP_WEAPON_ADVANCEDRIFLE",
        "PICKUP_WEAPON_APPISTOL",
        "PICKUP_WEAPON_ASSAULTRIFLE",
        "PICKUP_WEAPON_ASSAULTSHOTGUN",
        "PICKUP_WEAPON_ASSAULTSMG",
        "PICKUP_WEAPON_AUTOSHOTGUN",
        "PICKUP_WEAPON_BAT",
        "PICKUP_WEAPON_BATTLEAXE",
        "PICKUP_WEAPON_BOTTLE",
        "PICKUP_WEAPON_BULLPUPRIFLE",
        "PICKUP_WEAPON_BULLPUPSHOTGUN",
        "PICKUP_WEAPON_CARBINERIFLE",
        "PICKUP_WEAPON_COMBATMG",
        "PICKUP_WEAPON_COMBATPDW",
        "PICKUP_WEAPON_COMBATPISTOL",
        "PICKUP_WEAPON_COMPACTLAUNCHER",
        "PICKUP_WEAPON_COMPACTRIFLE",
        "PICKUP_WEAPON_CROWBAR",
        "PICKUP_WEAPON_DAGGER",
        "PICKUP_WEAPON_DBSHOTGUN",
        "PICKUP_WEAPON_FIREWORK",
        "PICKUP_WEAPON_FLAREGUN",
        "PICKUP_WEAPON_FLASHLIGHT",
        "PICKUP_WEAPON_GRENADE",
        "PICKUP_WEAPON_GRENADELAUNCHER",
        "PICKUP_WEAPON_GUSENBERG",
        "PICKUP_WEAPON_GOLFCLUB",
        "PICKUP_WEAPON_HAMMER",
        "PICKUP_WEAPON_HATCHET",
        "PICKUP_WEAPON_HEAVYPISTOL",
        "PICKUP_WEAPON_HEAVYSHOTGUN",
        "PICKUP_WEAPON_HEAVYSNIPER",
        "PICKUP_WEAPON_HOMINGLAUNCHER",
        "PICKUP_WEAPON_KNIFE",
        "PICKUP_WEAPON_KNUCKLE",
        "PICKUP_WEAPON_MACHETE",
        "PICKUP_WEAPON_MACHINEPISTOL",
        "PICKUP_WEAPON_MARKSMANPISTOL",
        "PICKUP_WEAPON_MARKSMANRIFLE",
        "PICKUP_WEAPON_MG",
        "PICKUP_WEAPON_MICROSMG",
        "PICKUP_WEAPON_MINIGUN",
        "PICKUP_WEAPON_MINISMG",
        "PICKUP_WEAPON_MOLOTOV",
        "PICKUP_WEAPON_MUSKET",
        "PICKUP_WEAPON_NIGHTSTICK",
        "PICKUP_WEAPON_PETROLCAN",
        "PICKUP_WEAPON_PIPEBOMB",
        "PICKUP_WEAPON_PISTOL",
        "PICKUP_WEAPON_PISTOL50",
        "PICKUP_WEAPON_POOLCUE",
        "PICKUP_WEAPON_PROXMINE",
        "PICKUP_WEAPON_PUMPSHOTGUN",
        "PICKUP_WEAPON_RAILGUN",
        "PICKUP_WEAPON_REVOLVER",
        "PICKUP_WEAPON_RPG",
        "PICKUP_WEAPON_SAWNOFFSHOTGUN",
        "PICKUP_WEAPON_SMG",
        "PICKUP_WEAPON_SMOKEGRENADE",
        "PICKUP_WEAPON_SNIPERRIFLE",
        "PICKUP_WEAPON_SNSPISTOL",
        "PICKUP_WEAPON_SPECIALCARBINE",
        "PICKUP_WEAPON_STICKYBOMB",
        "PICKUP_WEAPON_STUNGUN",
        "PICKUP_WEAPON_SWITCHBLADE",
        "PICKUP_WEAPON_VINTAGEPISTOL",
        "PICKUP_WEAPON_WRENCH",
        "PICKUP_WEAPON_RAYCARBINE",
        "PICKUP_WEAPON_GADGETPISTOL",
        "PICKUP_WEAPON_COMBATSHOTGUN",
        "PICKUP_AMMO_BULLET_MP",
        "PICKUP_AMMO_FIREWORK",
        "PICKUP_AMMO_FLAREGUN",
        "PICKUP_AMMO_GRENADELAUNCHER",
        "PICKUP_AMMO_GRENADELAUNCHER_MP",
        "PICKUP_AMMO_HOMINGLAUNCHER",
        "PICKUP_AMMO_MG",
        "PICKUP_AMMO_MINIGUN",
        "PICKUP_AMMO_MISSILE_MP",
        "PICKUP_AMMO_PISTOL",
        "PICKUP_AMMO_RIFLE",
        "PICKUP_AMMO_RPG",
        "PICKUP_AMMO_SHOTGUN",
        "PICKUP_AMMO_SMG",
        "PICKUP_AMMO_SNIPER",
        "PICKUP_AMMO_FIREWORK_MP",
        "PICKUP_AMMO_BULLET_MP",
        "PICKUP_AMMO_FIREWORK",
        "PICKUP_AMMO_FLARE",
        "PICKUP_AMMO_GRENADELAUNCHER_MP",
        "PICKUP_AMMO_GRENADELAUNCHER",
        "PICKUP_AMMO_HOMINGLAUNCHER",
        "PICKUP_AMMO_MG",
        "PICKUP_AMMO_MINIGUN",
        "PICKUP_AMMO_MISSILE_MP",
        "PICKUP_AMMO_PISTOL",
        "PICKUP_AMMO_RIFLE",
        "PICKUP_AMMO_RPG",
        "PICKUP_AMMO_SHOTGUN",
        "PICKUP_AMMO_SMG",
        "PICKUP_AMMO_SNIPER",
        "PICKUP_WEAPON_KNIFE_AMMO",
        "PICKUP_WEAPON_NIGHTSTICK_AMMO",
        "PICKUP_WEAPON_HAMMER_AMMO",
        "PICKUP_WEAPON_BAT_AMMO",
        "PICKUP_WEAPON_GOLFCLUB_AMMO",
        "PICKUP_WEAPON_CROWBAR_AMMO",
        "PICKUP_WEAPON_PISTOL_AMMO",
        "PICKUP_WEAPON_COMBATPISTOL_AMMO",
        "PICKUP_WEAPON_APPISTOL_AMMO",
        "PICKUP_WEAPON_MICROSMG_AMMO",
        "PICKUP_WEAPON_SMG_AMMO",
        "PICKUP_WEAPON_ASSAULTSMG_AMMO",
        "PICKUP_WEAPON_ASSAULTRIFLE_AMMO",
        "PICKUP_WEAPON_CARBINERIFLE_AMMO",
        "PICKUP_WEAPON_ADVANCEDRIFLE_AMMO",
        "PICKUP_WEAPON_MG_AMMO",
        "PICKUP_WEAPON_COMBATMG_AMMO",
        "PICKUP_WEAPON_PUMPSHOTGUN_AMMO",
        "PICKUP_WEAPON_SAWNOFFSHOTGUN_AMMO",
        "PICKUP_WEAPON_ASSAULTSHOTGUN_AMMO",
        "PICKUP_WEAPON_BULLPUPSHOTGUN_AMMO",
        "PICKUP_WEAPON_SNIPERRIFLE_AMMO",
        "PICKUP_WEAPON_HEAVYSNIPER_AMMO",
        "PICKUP_WEAPON_REMOTESNIPER_AMMO",
        "PICKUP_WEAPON_GRENADELAUNCHER_AMMO",
        "PICKUP_WEAPON_RPG_AMMO",
        "PICKUP_WEAPON_MINIGUN_AMMO",
        "PICKUP_WEAPON_GRENADE_AMMO",
        "PICKUP_WEAPON_STICKYBOMB_AMMO",
        "PICKUP_WEAPON_SMOKEGRENADE_AMMO",
        "PICKUP_WEAPON_MOLOTOV_AMMO",
        "PICKUP_WEAPON_FIREEXTINGUISHER_AMMO",
        "PICKUP_WEAPON_PETROLCAN_AMMO",
        "PICKUP_WEAPON_BALL_AMMO",
        "PICKUP_WEAPON_FLARE_AMMO",
        "PICKUP_WEAPON_SNSPISTOL_AMMO",
        "PICKUP_WEAPON_BOTTLE_AMMO",
        "PICKUP_WEAPON_GUSENBERG_AMMO",
        "PICKUP_WEAPON_SPECIALCARBINE_AMMO",
        "PICKUP_WEAPON_HEAVYPISTOL_AMMO",
        "PICKUP_WEAPON_BULLPUPRIFLE_AMMO",
        "PICKUP_WEAPON_DAGGER_AMMO",
        "PICKUP_WEAPON_VINTAGEPISTOL_AMMO",
        "PICKUP_WEAPON_FIREWORK_AMMO",
        "PICKUP_WEAPON_MUSKET_AMMO",
        "PICKUP_WEAPON_HEAVYSHOTGUN_AMMO",
        "PICKUP_WEAPON_MARKSMANRIFLE_AMMO",
        "PICKUP_WEAPON_HOMINGLAUNCHER_AMMO",
        "PICKUP_WEAPON_PROXMINE_AMMO",
        "PICKUP_WEAPON_SNOWBALL_AMMO",
        "PICKUP_WEAPON_FLAREGUN_AMMO",
        "PICKUP_WEAPON_GARBAGEBAG_AMMO",
        "PICKUP_WEAPON_HANDCUFFS_AMMO",
        "PICKUP_WEAPON_COMBATPDW_AMMO",
        "PICKUP_WEAPON_MARKSMANPISTOL_AMMO",
        "PICKUP_WEAPON_KNUCKLE_AMMO",
        "PICKUP_WEAPON_HATCHET_AMMO",
        "PICKUP_WEAPON_RAILGUN_AMMO",
        "PICKUP_WEAPON_MACHETE_AMMO",
        "PICKUP_WEAPON_MACHINEPISTOL_AMMO",
        "PICKUP_WEAPON_SWITCHBLADE_AMMO",
        "PICKUP_WEAPON_REVOLVER_AMMO",
        "PICKUP_WEAPON_BATTLEAXE_AMMO",
        "PICKUP_WEAPON_DBSHOTGUN_AMMO",
        "PICKUP_WEAPON_COMPACTRIFLE_AMMO",
        "PICKUP_WEAPON_AUTOSHOTGUN_AMMO",
        "PICKUP_WEAPON_POOLCUE_AMMO",
        "PICKUP_WEAPON_COMPACTLAUNCHER_AMMO",
        "PICKUP_WEAPON_MINISMG_AMMO",
        "PICKUP_WEAPON_PIPEBOMB_AMMO",
        "PICKUP_WEAPON_WRENCH_AMMO",
        "PICKUP_WEAPON_GRENADELAUNCHER_SMOKE_AMMO",
        "PICKUP_WEAPON_RAYMINIGUN_AMMO",
        "PICKUP_WEAPON_EMPLAUNCHER_AMMO",
        "PICKUP_WEAPON_RAILGUNXM3_AMMO",
        "PICKUP_WEAPON_BZGAS_AMMO",
        "PICKUP_WEAPON_ACIDPACKAGE_AMMO",
        "PICKUP_WEAPON_HEAVYSNIPER_MK2_AMMO",
        "PICKUP_WEAPON_MARKSMANRIFLE_MK2_AMMO",
        "PICKUP_WEAPON_PRECISIONRIFLE_AMMO",
        "PICKUP_WEAPON_COMBATMG_MK2_AMMO",
        "PICKUP_WEAPON_TACTICALRIFLE_AMMO",
        "PICKUP_WEAPON_HEAVYRIFLE_AMMO",
        "PICKUP_WEAPON_MILITARYRIFLE_AMMO",
        "PICKUP_WEAPON_BULLPUPRIFLE_MK2_AMMO",
        "PICKUP_WEAPON_SPECIALCARBINE_MK2_AMMO",
        "PICKUP_WEAPON_CARBINERIFLE_MK2_AMMO",
        "PICKUP_WEAPON_ASSAULTRIFLE_MK2_AMMO",
        "PICKUP_WEAPON_COMBATSHOTGUN_AMMO",
        "PICKUP_WEAPON_PUMPSHOTGUN_MK2_AMMO",
        "PICKUP_WEAPON_TECPISTOL_AMMO",
        "PICKUP_WEAPON_RAYCARBINE_AMMO",
        "PICKUP_WEAPON_SMG_MK2_AMMO",
        "PICKUP_WEAPON_PISTOLXM3_AMMO",
        "PICKUP_WEAPON_STUNGUN_AMMO",
        "PICKUP_WEAPON_STUNGUN_MP_AMMO",
        "PICKUP_WEAPON_GADGETPISTOL_AMMO",
        "PICKUP_WEAPON_NAVYREVOLVER_AMMO",
        "PICKUP_WEAPON_CERAMICPISTOL_AMMO",
        "PICKUP_WEAPON_RAYPISTOL_AMMO",
        "PICKUP_WEAPON_DOUBLEACTION_AMMO",
        "PICKUP_WEAPON_REVOLVER_MK2_AMMO",
        "PICKUP_WEAPON_SNSPISTOL_MK2_AMMO",
        "PICKUP_WEAPON_PISTOL50_AMMO",
        "PICKUP_WEAPON_PISTOL_MK2_AMMO",
        "PICKUP_WEAPON_CANDYCANE_AMMO",
        "PICKUP_WEAPON_STONE_HATCHET_AMMO",
        "PICKUP_WEAPON_FLASHLIGHT_AMMO",
        "PICKUP_PORTABLE_CRATE_FIXED_INCAR_SMALL",
        "PICKUP_PORTABLE_CRATE_FIXED_INCAR_WITH_PASSENGERS",
        "PICKUP_PORTABLE_CRATE_UNFIXED_INAIRVEHICLE_WITH_PASSENGERS",
        "PICKUP_PORTABLE_CRATE_UNFIXED_INCAR_WITH_PASSENGERS",
        "PICKUP_VEHICLE_CUSTOM_SCRIPT_NO_ROTATE",
        "PICKUP_WEAPON_DOUBLEBARRELSHOTGUN",
        "PICKUP_WEAPON_FIREEXTINGUISHER",
        "PICKUP_WEAPON_SWEEPERSHOTGUN",
        "PICKUP_WEAPON_REMOTESNIPER",
        "PICKUP_WEAPON_FIREEXTINGUISHER",
        "PICKUP_WEAPON_BALL",
        "PICKUP_WEAPON_FLARE",
        "PICKUP_WEAPON_SNOWBALL",
        "PICKUP_WEAPON_GARBAGEBAG",
        "PICKUP_WEAPON_HANDCUFFS",
        "PICKUP_WEAPON_GRENADELAUNCHER_SMOKE",
        "PICKUP_WEAPON_EMPLAUNCHER",
        "PICKUP_WEAPON_RAILGUNXM3",
        "PICKUP_WEAPON_BZGAS",
        "PICKUP_WEAPON_ACIDPACKAGE",
        "PICKUP_WEAPON_PRECISIONRIFLE",
        "PICKUP_WEAPON_TACTICALRIFLE",
        "PICKUP_WEAPON_HEAVYRIFLE",
        "PICKUP_WEAPON_MILITARYRIFLE",
        "PICKUP_WEAPON_TECPISTOL",
        "PICKUP_WEAPON_PISTOLXM3",
        "PICKUP_WEAPON_STUNGUN_MP",
        "PICKUP_WEAPON_NAVYREVOLVER",
        "PICKUP_WEAPON_CERAMICPISTOL",
        "PICKUP_WEAPON_CANDYCANE",
    }

    local playerId = _ENV["PlayerId"]()

    for i = 1, #pickupNames do
        local pickupHash = _ENV["GetHashKey"](pickupNames[i])
        if pickupHash then
            _ENV["N_0x616093ec6b139dd9"](playerId, _ENV["GetHashKey"](pickupNames[i]), false)
            _ENV["RemoveAllPickupsOfType"](_ENV["GetHashKey"](pickupNames[i]))
        end
    end
end

Citizen.CreateThread(function()
    if Config.antiSpawnWeaponSafe then
        RemoveWeaponPickups()
    end
end)

AddEventHandler("playerSpawned", function()
    Wait(5000)
    if Config.antiSpawnWeaponSafe then
        RemoveWeaponPickups()
    end
end)

local heartbeatCounter = 1
local lastHeartbeat = 1
local lastServerToken = nil

lib.callback.register("AR_AC:getClient", function(token)
    if heartbeatCounter == lastHeartbeat then
        return false
    end

    lastHeartbeat = heartbeatCounter
    Citizen.Wait(1)
    Wait(1)
    lastServerToken = token
    return lastServerToken
end)

CreateThread(function()
    while true do
        Wait(5000)
        heartbeatCounter = heartbeatCounter + 1
    end
end)

function StartAntiESP()
    Wait(5000)

    CreateThread(function()
        while true do
            Wait(2000)
            local myCoords = GetEntityCoords(PlayerPedId())

            for _, playerId in ipairs(GetActivePlayers()) do
                local otherPed = GetPlayerPed(playerId)
                if otherPed ~= PlayerPedId() then
                    if IsPedInAnyVehicle(otherPed, false) then
                        local otherCoords = GetEntityCoords(otherPed)
                        SetPedCanBeKnockedOffVehicle(otherPed, 2)
                        SetPedConfigFlag(otherPed, 32, false)

                        local distance = #(myCoords - otherCoords)
                        if distance >= 5.0 then
                            SetEntityHealth(otherPed, 200)
                        end
                    end
                end
            end
        end
    end)

    CreateThread(function()
        while true do
            Wait(100)
            local myCoords = GetEntityCoords(PlayerPedId())

            for _, playerId in ipairs(GetActivePlayers()) do
                local otherPed = GetPlayerPed(playerId)
                if otherPed ~= PlayerPedId() then
                    if IsPedInAnyVehicle(otherPed, false) then
                        local otherCoords = GetEntityCoords(otherPed)
                        local distance = #(myCoords - otherCoords)

                        if distance >= 5.0 then
                            SetEntityHealth(otherPed, 0)
                            ApplyDamageToPed(otherPed, 300, false)
                        else
                            SetEntityHealth(otherPed, 200)
                            SetPedCanBeKnockedOffVehicle(otherPed, 2)
                            SetPedConfigFlag(otherPed, 32, false)
                        end
                    else
                        SetEntityHealth(otherPed, 0)
                        ApplyDamageToPed(otherPed, 300, false)
                    end
                end
            end
        end
    end)
end

if Config.antiESP then
    CreateThread(StartAntiESP)
end

