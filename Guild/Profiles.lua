local addonName, addonTable = ...
local ODD = addonTable.ODD

local Profiles = {}
ODD.Guild.Profiles = Profiles

-- Inicializa o actualiza el perfil propio en el personaje local y en la cuenta global
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

    -- Sincronizar en caliente el perfil global de la cuenta (ODDDB.profiles)
    -- para que todos los alters de esta misma cuenta tengan las estadísticas actualizadas al instante
    self:SaveToGlobalProfiles()

    ODD:Debug("Perfil propio actualizado: %s (%s)", tostring(pInfo.name), tostring(pInfo.className))
end

-- Guarda el estado del personaje actual en ODDDB.profiles de la cuenta
function Profiles:SaveToGlobalProfiles()
    local globalDB = ODD.Database and ODD.Database:GetGlobal()
    local charDB = ODD.Database and ODD.Database:GetChar()
    if not globalDB or not charDB then return end

    local pName = (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player")
    if not pName or pName == "" or pName == "Desconocido" then return end

    globalDB.profiles = globalDB.profiles or {}
    globalDB.profiles[pName] = globalDB.profiles[pName] or {}

    local prof = globalDB.profiles[pName]
    prof.name = pName
    prof.className = select(2, UnitClass("player")) or charDB.identity.class or "WARRIOR"

    local gnomes = charDB.observations and charDB.observations.gnomes
    prof.gnomeKills = gnomes and gnomes.kills or 0

    if ODD.Achievements and ODD.Achievements.Medals then
        prof.achievementPoints = ODD.Achievements.Medals:GetPlayerAchievementPoints()
    end

    -- Calcular top zonas
    local records = gnomes and gnomes.records or {}
    local zoneCounts = {}
    for _, r in ipairs(records) do
        local z = r.zone or "Desconocida"
        zoneCounts[z] = (zoneCounts[z] or 0) + 1
    end
    local sortedZones = {}
    for zName, count in pairs(zoneCounts) do
        table.insert(sortedZones, { name = zName, count = count })
    end
    table.sort(sortedZones, function(a, b) return a.count > b.count end)

    local topList = {}
    for idx = 1, math.min(2, #sortedZones) do
        table.insert(topList, string.format("%s:%d", sortedZones[idx].name, sortedZones[idx].count))
    end
    if #topList > 0 then
        prof.topZones = table.concat(topList, ";")
    end

    prof.updatedAt = time()
    _G["ODDDB"] = globalDB
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
        self:SaveToGlobalProfiles()
    end
end

function Profiles:SetMainCharacter(mainName)
    local charDB = ODD.Database:GetChar()
    if charDB then
        charDB.identity.mainCharacter = mainName
        self:SaveToGlobalProfiles()
    end
end
