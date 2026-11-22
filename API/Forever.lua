local addonName, addonTable = ...
local ODD = addonTable.ODD

local Forever = {}
ODD.API.Forever = Forever

-- Detección segura de valores secretos (restricciones de API de combate / UI protegida)
function Forever:IsSecret(val)
    if _G["issecretvalue"] and type(_G["issecretvalue"]) == "function" then
        local ok, isSec = pcall(_G["issecretvalue"], val)
        return ok and (isSec == true)
    end
    return false
end

-- Obtener información básica y segura del jugador local
function Forever:GetPlayerInfo()
    local name, realm = UnitFullName("player")
    local _, classFilename, classId = UnitClass("player")
    local raceName, raceFile, raceId = UnitRace("player")
    local guid = UnitGUID("player")
    local level = UnitLevel("player")

    return {
        guid = guid,
        name = name,
        realm = realm or GetRealmName(),
        className = classFilename,
        classId = classId,
        raceFile = raceFile,
        raceId = raceId,
        level = level,
    }
end

-- Comprobar si el jugador está en una hermandad activa
function Forever:IsInGuild()
    return IsInGuild() == true
end
