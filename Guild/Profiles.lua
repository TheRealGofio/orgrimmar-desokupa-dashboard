local addonName, addonTable = ...
local ODD = addonTable.ODD

local Profiles = {}
ODD.Guild.Profiles = Profiles

-- Inicializa o actualiza el perfil propio en el personaje local
function Profiles:UpdateLocalProfile()
    local pInfo = ODD.API.Forever:GetPlayerInfo()
    local charDB = (ODD.Database and type(ODD.Database.GetChar) == "function") and ODD.Database:GetChar() or nil
    if not charDB then return end

    charDB.identity.guid = pInfo.guid
    charDB.identity.name = pInfo.name
    charDB.identity.realm = pInfo.realm
    charDB.identity.class = pInfo.className
    charDB.identity.race = pInfo.raceFile
    charDB.identity.level = pInfo.level

    ODD:Debug("Perfil propio actualizado: %s (%s)", tostring(pInfo.name), tostring(pInfo.className))
end

function Profiles:GetLocalProfile()
    local charDB = (ODD.Database and type(ODD.Database.GetChar) == "function") and ODD.Database:GetChar() or nil
    local id = charDB and charDB.identity or {}

    -- Si el nombre almacenado es solo el nombre de pila y estamos en hermandad, actualizarlo con el nombre completo
    if id.guid and (not id.name or not id.name:find(" ")) then
        local pInfo = ODD.API.Forever:GetPlayerInfo()
        if pInfo.name and pInfo.name:find(" ") then
            id.name = pInfo.name
        end
    end

    return id
end

function Profiles:SetCustomRole(role)
    local charDB = ODD.Database:GetChar()
    if charDB then
        charDB.identity.customRole = role
    end
end

function Profiles:SetMainCharacter(mainName)
    local charDB = ODD.Database:GetChar()
    if charDB then
        charDB.identity.mainCharacter = mainName
    end
end
