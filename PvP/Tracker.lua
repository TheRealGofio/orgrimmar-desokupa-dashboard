local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local PvP = {}
ODD.PvP = ODD.PvP or {}
ODD.PvP.Tracker = PvP

-- Consulta las estadísticas oficiales de PvP del jugador local
function PvP:GetLocalStats()
    local todayHK, todayHonor = 0, 0
    local yestHK, yestHonor = 0, 0
    local lifeHK, lifeRank = 0, 0

    if type(GetPVPSessionStats) == "function" then
        todayHK, todayHonor = GetPVPSessionStats()
    end
    if type(GetPVPYesterdayStats) == "function" then
        yestHK, yestHonor = GetPVPYesterdayStats()
    end
    if type(GetPVPLifetimeStats) == "function" then
        lifeHK, lifeRank = GetPVPLifetimeStats()
    end

    local honorLevel = 0
    if type(UnitHonorLevel) == "function" then
        honorLevel = UnitHonorLevel("player") or 0
    end

    return {
        todayHK = todayHK or 0,
        todayHonor = todayHonor or 0,
        yesterdayHK = yestHK or 0,
        yesterdayHonor = yestHonor or 0,
        lifetimeHK = lifeHK or 0,
        rank = lifeRank or 0,
        honorLevel = honorLevel,
        origin = "local_observed",
    }
end

-- Escucha de finalización de Campos de Batalla verificados
function PvP:Initialize()
    -- Actualización de estadísticas tras muertes con honor
    ODD.Events:Register("PLAYER_PVP_KILLS_CHANGED", function()
        ODD:Debug("Estadísticas PvP actualizadas por PLAYER_PVP_KILLS_CHANGED.")
        if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then
            ODD.UI.PvPTab:Refresh()
        end
    end)

    -- Fin de campo de batalla verificado
    ODD.Events:Register("PVP_MATCH_COMPLETE", function(event, winner, duration)
        PvP:OnMatchComplete(winner, duration)
    end)

    ODD:Debug("Módulo PvP Tracker inicializado.")
end

function PvP:OnMatchComplete(winner, duration)
    local myFaction = UnitFactionGroup("player")
    local isWinner = false

    -- En WoW, winner suele ser 0 (Horda) / 1 (Alianza) o nombre de facción
    if winner == 0 and myFaction == "Horde" then
        isWinner = true
    elseif winner == "Horde" and myFaction == "Horde" then
        isWinner = true
    end

    local zone = GetZoneText() or "Campo de Batalla"
    local charDB = ODD.Database:GetChar()
    if charDB and charDB.observations and charDB.observations.pvp then
        local matchRecord = {
            id = string.format("BG%d", time()),
            timestamp = time(),
            zone = zone,
            victory = isWinner,
            duration = duration or 0,
            origin = "local_observed",
        }
        table.insert(charDB.observations.pvp.matches, matchRecord)
        _G["ODDCharacterDB"] = charDB

        ODD:Log("Campo de batalla finalizado en %s: %s", zone, isWinner and "|cFF00FF00Victoria|r" or "|cFFFF0000Derrota|r")
        if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then
            ODD.UI.PvPTab:Refresh()
        end
    end
end
