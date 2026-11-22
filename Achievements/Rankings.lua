local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Rankings = {}
ODD.Achievements = ODD.Achievements or {}
ODD.Achievements.Rankings = Rankings

-- Calcula el Leaderboard del Gnomómetro combinando la observación local con los datos remotos declarados
function Rankings:GetGnomeLeaderboard()
    local list = {}

    -- 1. Incluir el registro verificado propio (Local Observed)
    local charDB = ODD.Database:GetChar()
    local myName = UnitName("player") or "Tú"
    local myClass = select(2, UnitClass("player")) or "WARRIOR"
    local myKills = (charDB and charDB.observations and charDB.observations.gnomes and charDB.observations.gnomes.kills) or 0

    table.insert(list, {
        name = myName,
        className = myClass,
        kills = myKills,
        isSelf = true,
        origin = "local_observed",
    })

    -- 2. Incluir registros declarados por otros miembros recibidos por la red P2P
    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.profiles then
        for name, profile in pairs(globalDB.profiles) do
            if name ~= myName and profile.gnomeKills and profile.gnomeKills > 0 then
                table.insert(list, {
                    name = name,
                    className = profile.className or "UNKNOWN",
                    kills = profile.gnomeKills,
                    isSelf = false,
                    origin = string.format("Declarado por %s (no verificado)", name),
                })
            end
        end
    end

    -- 3. Ordenar descendentemente por número de bajas
    table.sort(list, function(a, b)
        if a.kills == b.kills then
            return a.name < b.name
        end
        return a.kills > b.kills
    end)

    return list
end
