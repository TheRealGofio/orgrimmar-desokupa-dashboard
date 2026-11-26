local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local PvP = {}
ODD.PvP = ODD.PvP or {}
ODD.PvP.Tracker = PvP

local deathTicket = 0

-- Constantes de límite de almacenamiento
local MAX_NEMESIS_RECORDS = 50 -- Máximo 50 rivales en base de datos
local AVENGED_TTL_SECONDS = 14 * 86400 -- 14 días para limpiar vengados inactivos

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

    -- Obtener el título y nombre oficial de rango de la API de WoW Forever
    local rankName = "Civil"
    if lifeRank and lifeRank > 0 and type(GetPVPRankInfo) == "function" then
        local rTitle = GetPVPRankInfo(lifeRank, "player")
        if rTitle and rTitle ~= "" then
            rankName = rTitle
        end
    end

    return {
        todayHK = todayHK or 0,
        todayHonor = todayHonor or 0,
        yesterdayHK = yestHK or 0,
        yesterdayHonor = yestHonor or 0,
        lifetimeHK = lifeHK or 0,
        rank = lifeRank or 0,
        rankName = rankName,
        honorLevel = honorLevel,
        origin = "local_observed",
    }
end

-- ========================================================
-- SISTEMA DE NÉMESIS / VENGANZA (OBJETIVOS PRIORITARIOS EN MUNDO ABIERTO)
-- ========================================================

-- Comprueba si el jugador está en mundo abierto (excluye BGs, Arenas, Mazmorras y Bandas)
function PvP:IsWorldPvP()
    local inInstance = false
    if type(IsInInstance) == "function" then
        local ok, inst = pcall(IsInInstance)
        if ok and inst == true then
            return false
        end
    end

    if C_PvP and type(C_PvP.IsActiveBattlefield) == "function" then
        local okPvp, active = pcall(C_PvP.IsActiveBattlefield)
        if okPvp and active == true then
            return false
        end
    end

    return true
end

-- Poda y limpieza automática de la tabla de Némesis
local function PruneNemesisTable(nemTable)
    if not nemTable then return end
    local now = time()

    -- 1. Eliminar vengados que tengan más de 14 días sin actividad
    for guid, record in pairs(nemTable) do
        if record.status == "AVENGED" and (now - (record.lastEncounter or 0)) > AVENGED_TTL_SECONDS then
            nemTable[guid] = nil
        end
    end

    -- 2. Si aún supera el límite máximo, eliminar las entradas menos relevantes
    local count = 0
    local list = {}
    for guid, record in pairs(nemTable) do
        count = count + 1
        table.insert(list, { guid = guid, record = record })
    end

    if count > MAX_NEMESIS_RECORDS then
        -- Ordenar: los candidatos a ser eliminados primero son vengados antiguos o con pocas muertes
        table.sort(list, function(a, b)
            if a.record.status ~= b.record.status then
                return a.record.status == "AVENGED" -- Eliminar primero VENGADOS
            end
            if (a.record.deathsTo or 0) ~= (b.record.deathsTo or 0) then
                return (a.record.deathsTo or 0) < (b.record.deathsTo or 0) -- Menos muertes primero
            end
            return (a.record.lastEncounter or 0) < (b.record.lastEncounter or 0) -- Más viejo primero
        end)

        local toRemove = count - MAX_NEMESIS_RECORDS
        for i = 1, toRemove do
            nemTable[list[i].guid] = nil
        end
    end
end

-- Extrae los datos del enemigo que asestó el killing blow según C_DeathRecap
local function FindDeathRecapKiller(diedAt, playerGUID)
    local events = nil
    if C_DeathRecap and type(C_DeathRecap.GetRecapEvents) == "function" then
        local ok, evs = pcall(C_DeathRecap.GetRecapEvents)
        if ok and type(evs) == "table" and #evs > 0 then
            events = evs
        end
    end
    if not events and type(GetDeathRecapEvents) == "function" then
        local ok, evs = pcall(GetDeathRecapEvents)
        if ok and type(evs) == "table" and #evs > 0 then
            events = evs
        end
    end

    if not events then return nil end

    local chosen = nil
    for _, eventInfo in ipairs(events) do
        if type(eventInfo) == "table" then
            local ok, srcGUID, srcName, dstGUID, stamp, overkill = pcall(function()
                return eventInfo.sourceGUID, eventInfo.sourceName, eventInfo.destGUID, tonumber(eventInfo.timestamp), tonumber(eventInfo.overkill)
            end)

            if ok and type(srcGUID) == "string" and type(stamp) == "number" and type(overkill) == "number" and overkill >= 0 then
                local recent = (stamp >= diedAt - 4 and stamp <= diedAt + 4)
                local isPlayerVictim = (not playerGUID) or (dstGUID == playerGUID)
                if recent and isPlayerVictim and (not chosen or stamp >= chosen.stamp) then
                    chosen = { guid = srcGUID, name = srcName, stamp = stamp }
                end
            end
        end
    end

    return chosen
end

-- Procesa la muerte del jugador y busca al asesino
local function ProcessDeathRecap(ticket, diedAt, attempt)
    if ticket ~= deathTicket then return end

    -- Regla estricta: Némesis NO aplica en Battlegrounds, Arenas ni Mazmorras/Bandas
    if not PvP:IsWorldPvP() then return end

    local playerGUID = ODD.API.Forever:SanitizeGUID(UnitGUID("player"))
    local killer = FindDeathRecapKiller(diedAt, playerGUID)

    -- Si aún no ha llegado el evento y quedan intentos, reintentar (idéntico al timing de GRS)
    if not killer and attempt < 4 and C_Timer and C_Timer.After then
        local wait = ({ 0.35, 0.7, 1.2 })[attempt]
        C_Timer.After(wait, function()
            ProcessDeathRecap(ticket, diedAt, attempt + 1)
        end)
        return
    end

    if not killer or not killer.guid:find("^Player%-") then
        return
    end

    PvP:RecordNemesisKillOnPlayer(killer.guid, killer.name)
end

-- Registra cuando un enemigo te mata
function PvP:RecordNemesisKillOnPlayer(killerGUID, killerName)
    local charDB = ODD.Database:GetChar()
    if not charDB or not charDB.observations or not charDB.observations.pvp then return end

    charDB.observations.pvp.nemesis = charDB.observations.pvp.nemesis or {}
    local nemTable = charDB.observations.pvp.nemesis

    local enemyName = killerName
    local enemyClass = nil
    local enemyRace = nil

    -- Intentar resolver raza, clase y nombre por GetPlayerInfoByGUID
    if type(GetPlayerInfoByGUID) == "function" then
        local ok, _, classFile, locRace, engRace, _, pName = pcall(GetPlayerInfoByGUID, killerGUID)
        if ok then
            enemyClass = ODD.API.Forever:SanitizeText(classFile)
            enemyRace = ODD.API.Forever:SanitizeText(engRace) or ODD.API.Forever:SanitizeText(locRace)
            if not enemyName or enemyName == "" then
                enemyName = ODD.API.Forever:SanitizeText(pName)
            end
        end
    end

    enemyName = enemyName or "Enemigo de la Alianza"

    local record = nemTable[killerGUID] or {
        guid = killerGUID,
        name = enemyName,
        class = enemyClass or "UNKNOWN",
        race = enemyRace or "UNKNOWN",
        deathsTo = 0,
        killsOn = 0,
        firstEncounter = time(),
        lastEncounter = time(),
        zone = GetZoneText() or "Mundo Abierto",
        status = "WANTED",
    }

    record.name = enemyName
    record.class = enemyClass or record.class
    record.race = enemyRace or record.race
    record.deathsTo = (record.deathsTo or 0) + 1
    record.lastEncounter = time()
    record.zone = GetZoneText() or record.zone
    record.status = "WANTED"

    nemTable[killerGUID] = record
    PruneNemesisTable(nemTable)
    _G["ODDCharacterDB"] = charDB

    ODD:Log("|cFFFF0000[NÉMESIS]|r ¡Caíste ante |cFFFFD100%s|r (%s)! Marcado como Objetivo Prioritario.", 
        record.name, record.race or "Alianza")

    if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then
        ODD.UI.PvPTab:Refresh()
    end
end

-- Registra cuando te vengas y abates a un enemigo de la lista de Némesis
function PvP:CheckNemesisAvenged(victimGUID, victimName, victimClass, victimRace)
    -- Regla estricta: Las venganzas de Némesis solo computan en Mundo Abierto (no en BGs ni estancias)
    if not self:IsWorldPvP() then return end

    local charDB = ODD.Database:GetChar()
    if not charDB or not charDB.observations or not charDB.observations.pvp then return end

    local nemTable = charDB.observations.pvp.nemesis
    if not nemTable or not nemTable[victimGUID] then return end

    local record = nemTable[victimGUID]
    record.killsOn = (record.killsOn or 0) + 1
    record.lastEncounter = time()
    record.zone = GetZoneText() or record.zone

    -- Si lo has matado al menos tantas veces como te ha matado, queda vengado
    if record.killsOn >= record.deathsTo then
        record.status = "AVENGED"
        ODD:Log("|cFF00FF00[¡VENGANZA CUMPLIDA!]|r Has eliminado a tu némesis |cFFFFD100%s|r (Marcador: %d - %d).", 
            record.name or victimName or "Enemigo", record.killsOn, record.deathsTo)
    else
        ODD:Log("|cFFFFD100[REPRESALIA]|r Has abatido a tu némesis %s. Te faltan %d bajas para saldar la deuda.", 
            record.name or victimName or "Enemigo", record.deathsTo - record.killsOn)
    end

    _G["ODDCharacterDB"] = charDB

    if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then
        ODD.UI.PvPTab:Refresh()
    end
end

-- Permite limpiar manualmente o borrar un némesis específico
function PvP:RemoveNemesis(guid)
    local charDB = ODD.Database:GetChar()
    if charDB and charDB.observations and charDB.observations.pvp and charDB.observations.pvp.nemesis then
        charDB.observations.pvp.nemesis[guid] = nil
        _G["ODDCharacterDB"] = charDB
        if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then
            ODD.UI.PvPTab:Refresh()
        end
    end
end

-- Limpia todos los némesis (limpieza total)
function PvP:ClearAllNemesis()
    local charDB = ODD.Database:GetChar()
    if charDB and charDB.observations and charDB.observations.pvp then
        local count = 0
        if charDB.observations.pvp.nemesis then
            for _ in pairs(charDB.observations.pvp.nemesis) do count = count + 1 end
        end
        charDB.observations.pvp.nemesis = {}
        _G["ODDCharacterDB"] = charDB
        ODD:Log("Se han eliminado todos los rivales (%d) de tu lista de Némesis.", count)
        if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then
            ODD.UI.PvPTab:Refresh()
        end
    end
end

-- Limpia todos los némesis que ya han sido vengados
function PvP:ClearAvengedNemesis()
    local charDB = ODD.Database:GetChar()
    if charDB and charDB.observations and charDB.observations.pvp and charDB.observations.pvp.nemesis then
        local removed = 0
        for guid, r in pairs(charDB.observations.pvp.nemesis) do
            if r.status == "AVENGED" then
                charDB.observations.pvp.nemesis[guid] = nil
                removed = removed + 1
            end
        end
        _G["ODDCharacterDB"] = charDB
        ODD:Log("Se han limpiado %d objetivos vengados de tu lista de Némesis.", removed)
        if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then
            ODD.UI.PvPTab:Refresh()
        end
    end
end

-- Obtiene la lista filtrada y ordenada de Némesis
function PvP:GetNemesisList(filter)
    filter = filter or "all" -- "all", "wanted", "avenged"
    local charDB = ODD.Database:GetChar()
    local nemTable = (charDB and charDB.observations and charDB.observations.pvp and charDB.observations.pvp.nemesis) or {}
    local list = {}

    for guid, nem in pairs(nemTable) do
        if filter == "all" then
            table.insert(list, nem)
        elseif filter == "wanted" and nem.status == "WANTED" then
            table.insert(list, nem)
        elseif filter == "avenged" and nem.status == "AVENGED" then
            table.insert(list, nem)
        end
    end

    table.sort(list, function(a, b)
        -- Primero los que siguen en búsqueda ("WANTED")
        if a.status ~= b.status then
            return a.status == "WANTED"
        end
        -- Luego los que más veces te han matado
        if (a.deathsTo or 0) ~= (b.deathsTo or 0) then
            return (a.deathsTo or 0) > (b.deathsTo or 0)
        end
        return (a.lastEncounter or 0) > (b.lastEncounter or 0)
    end)

    return list
end

-- ========================================================
-- INICIALIZACIÓN Y EVENTOS
-- ========================================================
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

    -- Detección de muerte del jugador para capturar Némesis
    ODD.Events:Register("PLAYER_DEAD", function()
        deathTicket = deathTicket + 1
        local now = time()
        ProcessDeathRecap(deathTicket, now, 1)
    end)

    -- También enganchar PARTY_KILL para comprobar si la víctima era Némesis
    ODD.Events:Register("PARTY_KILL", function(event, attackerGUID, targetGUID)
        local safeT = ODD.API.Forever:SanitizeGUID(targetGUID)
        if safeT then
            PvP:CheckNemesisAvenged(safeT)
        end
    end)

    ODD:Debug("Módulo PvP Tracker inicializado con límite de 50 rivales y purga de vengados.")
end
