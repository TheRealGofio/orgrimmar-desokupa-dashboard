local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Rankings = {}
ODD.Achievements = ODD.Achievements or {}
ODD.Achievements.Rankings = Rankings

-- Calcula el título honorífico interno de hermandad según méritos
function Rankings:GetHonoraryTitle(kills, points, isRank1Kills, isRank1Points)
    kills = kills or 0
    points = points or 0

    if isRank1Kills and kills >= 5 then
        return "El Fumigador Jefe", "FFFFD100"
    elseif isRank1Points and points >= 20 then
        return "Inspector de Desokupaciones", "FF00FFCC"
    elseif kills >= 50 then
        return "Azote de Manitas", "FFFF2020"
    elseif kills >= 25 then
        return "Desalojador Élite", "FFFF8000"
    elseif kills >= 10 then
        return "Cazarratas", "FF00FF00"
    elseif kills >= 1 then
        return "Desokupador Novato", "FF69CCF0"
    elseif points >= 15 then
        return "Coleccionista de Medallas", "FFA330C9"
    else
        return "Aspirante", "FF888888"
    end
end
-- sortBy: "kills" (por bajas) o "points" (por puntos de logro)
function Rankings:GetGnomeLeaderboard(sortBy)
    sortBy = sortBy or "kills"
    local list = {}

    -- 1. Incluir el registro verificado propio (Local Observed)
    local charDB = ODD.Database:GetChar()
    local myName = UnitName("player") or "Tú"
    local myFullName, myRealm = UnitFullName("player")
    local myCombinedName = (myFullName and myRealm and myRealm ~= "") and (myFullName .. "-" .. myRealm) or (myFullName or myName)
    local myClass = select(2, UnitClass("player")) or "WARRIOR"
    local myKills = (charDB and charDB.observations and charDB.observations.gnomes and charDB.observations.gnomes.kills) or 0
    local myPoints = 0
    if ODD.Achievements and ODD.Achievements.Medals then
        myPoints = ODD.Achievements.Medals:GetPlayerAchievementPoints()
    end

    local function IsMe(name)
        if not name then return false end
        local cName = Ambiguate(name, "none"):lower()
        local cMyName = Ambiguate(myName, "none"):lower()
        local cComb = myCombinedName:lower()
        return (cName == cMyName) or (name:lower() == cComb) or (name:lower():find("^" .. cMyName))
    end

    table.insert(list, {
        name = myName,
        className = myClass,
        kills = myKills,
        points = myPoints,
        isSelf = true,
        origin = "local_observed",
    })

    -- 2. Incluir registros declarados por otros miembros recibidos por la red P2P
    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.profiles then
        for name, profile in pairs(globalDB.profiles) do
            if not IsMe(name) and ((profile.gnomeKills and profile.gnomeKills > 0) or (profile.achievementPoints and profile.achievementPoints > 0)) then
                table.insert(list, {
                    name = name,
                    className = profile.className or "UNKNOWN",
                    kills = profile.gnomeKills or 0,
                    points = profile.achievementPoints or 0,
                    isSelf = false,
                    origin = string.format("Declarado por %s (no verificado)", name),
                })
            end
        end
    end

    -- 3. Ordenar descendentemente según el criterio seleccionado
    table.sort(list, function(a, b)
        if sortBy == "points" then
            if a.points == b.points then
                if a.kills == b.kills then
                    return a.name < b.name
                end
                return a.kills > b.kills
            end
            return a.points > b.points
        else
            if a.kills == b.kills then
                if a.points == b.points then
                    return a.name < b.name
                end
                return a.points > b.points
            end
            return a.kills > b.kills
        end
    end)

    return list
end
