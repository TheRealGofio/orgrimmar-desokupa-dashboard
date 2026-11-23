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

-- Identificadores de sonido nativos de WoW (SoundKit IDs)
-- 8959: RAID_WARNING (campana/alarma de aviso)
-- 5964: GNOME_MALE_AGGRO ("¡Por Gnomeregan!" / voz de gnomo)
-- 5979: GNOME_FEMALE_AGGRO (Voz de gnoma)
-- 8458: PVP_THROUGH_QUEUE (trompeta de batalla PvP)
-- 888:  UI_EPICLOOT_TOAST (fanfarria de botín/logro)
local SOUNDKIT_IDS = {
    GNOME_ALERT  = (SOUNDKIT and SOUNDKIT.GNOME_MALE_AGGRO) or 5964,
    RAID_WARNING = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959,
    PVP_KILL     = (SOUNDKIT and SOUNDKIT.PVP_THROUGH_QUEUE) or (SOUNDKIT and SOUNDKIT.IG_PVP_UPDATE) or 8458,
    ACHIEVEMENT  = (SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST) or (SOUNDKIT and SOUNDKIT.ACHIEVEMENT_UNLOCKED) or 888,
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

-- Sonido al detectar un gnomo enemigo cercano (Radar): Voz de gnomo nativa y alarma
function Audio:PlayRadarAlertSound()
    -- Reproducir voz de gnomo nativa de WoW
    local gnomeId = SOUNDKIT_IDS.GNOME_ALERT
    if type(PlaySound) == "function" then
        pcall(PlaySound, gnomeId, "Master")
        -- También alarma de aviso si el volumen de voces estuviera bajo
        pcall(PlaySound, SOUNDKIT_IDS.RAID_WARNING, "Master")
    end
    -- Y si hay archivo custom
    self:Play({ SOUND_RADAR_OGG, SOUND_RADAR_MP3 }, gnomeId)
end
