local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Audio = {}
ODD.Audio = Audio

-- Rutas de audio relativas al directorio de Interface de WoW (soporta mp3 y ogg)
local SOUND_KILL_MP3 = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Sounds\\kill.mp3"
local SOUND_KILL_OGG = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Sounds\\kill.ogg"
local SOUND_ACHIEVEMENT_MP3 = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Sounds\\achievement.mp3"
local SOUND_ACHIEVEMENT_OGG = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Sounds\\achievement.ogg"
local SOUND_RADAR_MP3 = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Sounds\\radar.mp3"
local SOUND_RADAR_OGG = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Sounds\\radar.ogg"

-- Rutas directas a los gritos de batalla nativos de Gnomo del cliente de WoW
local GNOME_MALE_VOICES = {
    "Sound\\character\\Gnome\\GnomeVocalMale\\GnomeMaleCharge01.ogg",
    "Sound\\character\\Gnome\\GnomeVocalMale\\GnomeMaleCharge02.ogg",
    "Sound\\character\\Gnome\\GnomeVocalMale\\GnomeMaleCharge03.ogg",
    "Sound\\character\\Gnome\\GnomeVocalMale\\GnomeMaleCheer01.ogg",
}

local GNOME_FEMALE_VOICES = {
    "Sound\\character\\Gnome\\GnomeVocalFemale\\GnomeFemaleCharge01.ogg",
    "Sound\\character\\Gnome\\GnomeVocalFemale\\GnomeFemaleCharge02.ogg",
    "Sound\\character\\Gnome\\GnomeVocalFemale\\GnomeFemaleCheer01.ogg",
}

-- Identificadores de sonido nativos de WoW (SoundKit IDs)
-- 2828: Gnome Male Charge ("¡Por Gnomeregan!" auténtico)
-- 2840: Gnome Female Charge (Grito de guerra gnoma auténtica)
-- 8458: PVP_THROUGH_QUEUE (trompeta de batalla PvP)
-- 888:  UI_EPICLOOT_TOAST (fanfarria de botín/logro)
local SOUNDKIT_IDS = {
    GNOME_MALE_CHARGE   = 2828,
    GNOME_FEMALE_CHARGE = 2840,
    PVP_KILL            = (SOUNDKIT and SOUNDKIT.PVP_THROUGH_QUEUE) or (SOUNDKIT and SOUNDKIT.IG_PVP_UPDATE) or 8458,
    ACHIEVEMENT         = (SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST) or (SOUNDKIT and SOUNDKIT.ACHIEVEMENT_UNLOCKED) or 888,
}

-- Reproduce un sonido de archivo o sonido nativo
-- Intenta canales "Master" y "Dialog" para asegurar audibilidad independientemente de cvars de SFX
function Audio:Play(filePaths, fallbackSoundKitId)
    if ODD.Database and ODD.Database:GetSetting("muteSounds") then
        return false
    end

    local played = false
    local paths = (type(filePaths) == "table") and filePaths or (filePaths and { filePaths } or {})

    -- 1. Intentar archivo custom con PlaySoundFile en Master
    if type(PlaySoundFile) == "function" then
        for _, path in ipairs(paths) do
            if path and not played then
                local ok, handle = pcall(PlaySoundFile, path, "Master")
                if ok and handle ~= false and handle ~= nil then
                    played = true
                    break
                end
            end
        end
    end

    -- 2. Fallback o sonido nativo SOUNDKIT
    if not played and fallbackSoundKitId and type(PlaySound) == "function" then
        -- En WoW moderno/Forever, PlaySound(id, channel)
        local ok, handle = pcall(PlaySound, fallbackSoundKitId, "Master")
        if not ok or handle == false then
            -- Intentar sin canal o en Dialog
            pcall(PlaySound, fallbackSoundKitId, "Dialog")
        end
        played = true
    end

    return played
end

-- Sonido al abatir un gnomo (trompeta PvP / fanfarria)
function Audio:PlayKillSound()
    return self:Play({ SOUND_KILL_OGG, SOUND_KILL_MP3 }, SOUNDKIT_IDS.PVP_KILL)
end

-- Sonido al desbloquear un logro
function Audio:PlayAchievementSound()
    return self:Play({ SOUND_ACHIEVEMENT_OGG, SOUND_ACHIEVEMENT_MP3 }, SOUNDKIT_IDS.ACHIEVEMENT)
end

-- Sonido al detectar un gnomo enemigo cercano (Radar): Voz de gnomo según género a máximo volumen
function Audio:PlayRadarAlertSound(sex)
    if ODD.Database and ODD.Database:GetSetting("muteSounds") then
        return false
    end

    -- En WoW UnitSex: 1 = Neutro/Desconocido, 2 = Male, 3 = Female
    local isFemale = false
    if sex == 3 or sex == "FEMALE" or sex == "female" then
        isFemale = true
    elseif sex == 2 or sex == "MALE" or sex == "male" then
        isFemale = false
    else
        -- Si no se pudo determinar el sexo, aleatorio 50/50
        isFemale = (math.random(1, 2) == 2)
    end

    local voiceList = isFemale and GNOME_FEMALE_VOICES or GNOME_MALE_VOICES
    local soundKitId = isFemale and SOUNDKIT_IDS.GNOME_FEMALE_CHARGE or SOUNDKIT_IDS.GNOME_MALE_CHARGE
    local played = false

    -- 1. Intentar reproducir archivos OGG internos directos de la voz correspondiente (canal Master)
    if type(PlaySoundFile) == "function" then
        local pickPath = voiceList[math.random(1, #voiceList)]
        local ok, handle = pcall(PlaySoundFile, pickPath, "Master")
        if ok and handle ~= false and handle ~= nil then
            played = true
        end
    end

    -- 2. Fallback a SoundKit IDs oficiales de gnomo según género (2828: Male, 2840: Female)
    if not played and type(PlaySound) == "function" then
        local ok, handle = pcall(PlaySound, soundKitId, "Master")
        if ok and handle ~= false and handle ~= nil then
            played = true
        end
    end

    -- 3. Fallback a Media/Sounds local si lo hubiera
    if not played then
        self:Play({ SOUND_RADAR_OGG, SOUND_RADAR_MP3 }, soundKitId)
    end
end
