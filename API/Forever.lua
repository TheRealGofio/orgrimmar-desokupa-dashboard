local addonName, addonTable = ...
local ODD = addonTable.ODD

local Forever = {}
ODD.API.Forever = Forever

-- Detección segura de valores secretos (restricciones de API de combate / UI protegida)
function Forever:IsSecret(val)
    if _G["issecretvalue"] and type(_G["issecretvalue"]) == "function" then
        local ok, isSec = pcall(_G["issecretvalue"], val)
        return (not ok) or (isSec == true)
    end
    return false
end

-- Sanitizador de cadenas (estilo GRS)
function Forever:SanitizeText(value)
    if self:IsSecret(value) or type(value) ~= "string" then
        return nil
    end
    value = value:gsub("[%c|]", ""):match("^%s*(.-)%s*$")
    if not value or value == "" then
        return nil
    end
    return value
end

-- Sanitizador de números
function Forever:SanitizeNumber(value)
    if self:IsSecret(value) then
        return nil
    end
    return tonumber(value)
end

-- Sanitizador de GUIDs seguros
function Forever:SanitizeGUID(value)
    local text = self:SanitizeText(value)
    if text and text:find("^%w") then
        return text
    end
    return nil
end

-- Obtener información básica y segura del jugador local
function Forever:GetPlayerInfo()
    local name, realm = UnitFullName("player")
    local _, classFilename, classId = UnitClass("player")
    local raceName, raceFile, raceId = UnitRace("player")
    local guid = UnitGUID("player")
    local level = UnitLevel("player")

    -- En WoW Forever, los nombres completos (con apellido) están disponibles en el Roster de hermandad
    local fullName = self:SanitizeText(name)
    local safeGuid = self:SanitizeGUID(guid)
    if safeGuid and type(GetNumGuildMembers) == "function" and type(GetGuildRosterInfo) == "function" then
        local numTotal = GetNumGuildMembers()
        for i = 1, numTotal do
            local gName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, gGuid = GetGuildRosterInfo(i)
            if gGuid and self:SanitizeGUID(gGuid) == safeGuid and gName then
                fullName = self:SanitizeText(gName)
                break
            end
        end
    end

    return {
        guid = safeGuid,
        name = fullName,
        realm = self:SanitizeText(realm) or GetRealmName(),
        className = self:SanitizeText(classFilename),
        classId = self:SanitizeNumber(classId),
        raceFile = self:SanitizeText(raceFile),
        raceId = self:SanitizeNumber(raceId),
        level = self:SanitizeNumber(level),
    }
end

-- Comprobar si el jugador está en una hermandad activa
function Forever:IsInGuild()
    return IsInGuild() == true
end
