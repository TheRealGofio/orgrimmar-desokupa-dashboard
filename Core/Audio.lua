local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Audio = {}
ODD.Audio = Audio

-- Rutas de audio relativas al directorio de Interface de WoW
local SOUND_KILL = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Sounds\\kill.ogg"
local SOUND_ACHIEVEMENT = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Sounds\\achievement.ogg"

-- Reproduce un sonido de archivo con PlaySoundFile (soportando OGG y MP3) y fallback a SOUNDKIT nativo
function Audio:Play(filePath, fallbackSoundKitId)
    if ODD.Database and ODD.Database:GetSetting("muteSounds") then
        return
    end

    local played = false

    -- 1. Intento con archivo custom en Media\Sounds
    if filePath and type(PlaySoundFile) == "function" then
        local ok, willPlay = pcall(PlaySoundFile, filePath, "Master")
        if ok and willPlay ~= false then
            played = true
        end
    end

    -- 2. Fallback a sonido nativo de WoW si el archivo no existe o no se reproduce
    if not played and fallbackSoundKitId and type(PlaySound) == "function" then
        pcall(PlaySound, fallbackSoundKitId, "Master")
    end
end

-- Sonido al abatir un gnomo
function Audio:PlayKillSound()
    -- Archivo: Media/Sounds/kill.ogg (o .mp3)
    -- Fallback nativo: Rugido / Victoria Horda (SOUNDKIT.PVP_THROUGH_VICTORY o sonido de orco)
    local fallback = SOUNDKIT and (SOUNDKIT.IG_PVP_UPDATE or SOUNDKIT.ALARM_CLOCK_WARNING_3) or 888
    self:Play(SOUND_KILL, fallback)
end

-- Sonido al desbloquear un logro
function Audio:PlayAchievementSound()
    -- Archivo: Media/Sounds/achievement.ogg (o .mp3)
    -- Fallback nativo: Fanfarria de logro / Botín épico
    local fallback = SOUNDKIT and (SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.ACHIEVEMENT_UNLOCKED) or 888
    self:Play(SOUND_ACHIEVEMENT, fallback)
end
