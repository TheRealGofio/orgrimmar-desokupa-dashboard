local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Tracker = {}
ODD.Gnomes = ODD.Gnomes or {}
ODD.Gnomes.Tracker = Tracker

-- Constantes de verificación
local GNOME_RACE_ID = 7 -- RaceID estándar de Gnomo en World of Warcraft
local GNOME_RACE_STRING = "Gnome"
local KILL_COOLDOWN_WINDOW = 60 -- Cooldown de 60 segundos por víctima para evitar duplicados

-- Historial reciente para deduplicación: [targetGUID] = timestamp
local recentKills = {}

-- Caché de combate a corto plazo para capturar estados previos a recibir daño
-- [guid] = { wasEating = bool, wasMounted = bool, timestamp = number }
local combatAuraCache = {}

-- Contador de bajas en la sesión actual
Tracker.sessionKills = 0

-- Comprueba si el jugador está en mundo abierto (excluye BGs, Arenas, Mazmorras y Bandas)
function Tracker:IsWorldPvP()
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        return false -- Mazmorra, Banda, BG o Arena
    end

    if C_PvP and type(C_PvP.IsActiveBattlefield) == "function" and C_PvP.IsActiveBattlefield() then
        return false
    end

    return true
end

-- Escanea el objetivo actual para detectar estados de interés antes de que sufra daño
function Tracker:CheckTargetAuras()
    if not UnitExists("target") or not UnitCanAttack("player", "target") then return end
    local guid = UnitGUID("target")
    if not guid or ODD.API.Forever:IsSecret(guid) then return end

    local raceName, raceFile, raceId = UnitRace("target")
    local isGnome = (raceId == GNOME_RACE_ID or (raceFile and raceFile:lower() == "gnome"))
    if not isGnome then return end

    local wasEating = false
    local wasMounted = false

    -- Inspeccionar auras del gnomo de forma compatible con la API moderna/Forever
    -- En WoW moderno (10.x/11.x/12.x/Forever), UnitAura clásica está retirada a favor de C_UnitAuras
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL")
            if not aura then break end
            local lowerName = (aura.name or ""):lower()

            if lowerName:find("beber") or lowerName:find("drink") 
               or lowerName:find("comer") or lowerName:find("food") 
               or lowerName:find("restauraci") or lowerName:find("refreshment") then
                wasEating = true
            end

            if lowerName:find("mecazancudo") or lowerName:find("mechanostrider") 
               or lowerName:find("zancudo") or lowerName:find("strider") then
                wasMounted = true
            end
        end
    elseif _G["UnitAura"] then
        for i = 1, 40 do
            local name = _G["UnitAura"]("target", i, "HELPFUL")
            if not name then break end
            local lowerName = name:lower()

            if lowerName:find("beber") or lowerName:find("drink") 
               or lowerName:find("comer") or lowerName:find("food") 
               or lowerName:find("restauraci") or lowerName:find("refreshment") then
                wasEating = true
            end

            if lowerName:find("mecazancudo") or lowerName:find("mechanostrider") 
               or lowerName:find("zancudo") or lowerName:find("strider") then
                wasMounted = true
            end
        end
    end

    if wasEating or wasMounted then
        combatAuraCache[guid] = {
            wasEating = wasEating or (combatAuraCache[guid] and combatAuraCache[guid].wasEating),
            wasMounted = wasMounted or (combatAuraCache[guid] and combatAuraCache[guid].wasMounted),
            timestamp = time()
        }
    end
end

-- Intenta verificar si un GUID o token corresponde a un gnomo y extrae metadata si esta disponible
function Tracker:GetTargetInfo(unitToken, unitGUID)
    local token = unitToken
    if not token and unitGUID and UnitGUID("target") == unitGUID then
        token = "target"
    end

    if token and UnitExists(token) then
        local raceName, raceFile, raceId = UnitRace(token)
        local isGnome = (raceId == GNOME_RACE_ID or (raceFile and raceFile:lower() == "gnome"))
        local name = UnitName(token)
        local _, classFile = UnitClass(token)
        local level = UnitLevel(token)
        if level and level <= 0 then level = "??" end

        return isGnome, raceFile or "Gnome", name, classFile, level
    end

    return false, "UNVERIFIED", nil, nil, nil
end

-- Procesa un killing blow con verificación estricta de autoría y raza
function Tracker:OnKillEvent(attackerGUID, targetGUID)
    -- Protección contra 'secret values' en el motor moderno de WoW Forever
    if ODD.API.Forever:IsSecret(attackerGUID) or ODD.API.Forever:IsSecret(targetGUID) then
        ODD:Debug("PARTY_KILL descartado: valores clasificados como secretos por el cliente.")
        return
    end

    local playerGUID = UnitGUID("player")
    if not playerGUID or not targetGUID or not attackerGUID then return end
    if ODD.API.Forever:IsSecret(playerGUID) then return end

    -- Comprobación segura de igualdad entre cadenas sin taint de secret
    local isPlayerAttacker = false
    local okComp, match = pcall(function() return attackerGUID == playerGUID end)
    if okComp and match then
        isPlayerAttacker = true
    end

    -- 1. Regla: Solo cuenta si el atacante directo es el propio jugador
    if not isPlayerAttacker then
        -- Descartado: kill de otro miembro del grupo o de terceros
        return
    end

    -- 2. Regla: Exclusión de BGs e instancias (solo Mundo Abierto)
    if not self:IsWorldPvP() then
        return
    end

    -- 3. Regla: Deduplicación por cooldown de víctima
    local now = time()
    local okDedupe = pcall(function()
        if recentKills[targetGUID] and (now - recentKills[targetGUID]) < KILL_COOLDOWN_WINDOW then
            return true
        end
        return false
    end)
    if okDedupe == true then
        return
    end

    -- 4. Regla: Verificación estricta de raza (Gnomo) y lectura de metadata
    local isGnome, raceInfo, victimName, victimClass, victimLevel = self:GetTargetInfo(nil, targetGUID)
    if not isGnome then
        return
    end

    -- Recuperar estado previo de la víctima desde el caché de combate
    local auraData = combatAuraCache[targetGUID]
    local wasEating = false
    local wasMounted = false
    if auraData and (now - auraData.timestamp) < 45 then
        wasEating = auraData.wasEating == true
        wasMounted = auraData.wasMounted == true
    end

    -- Kill verificada y aceptada
    pcall(function() recentKills[targetGUID] = now end)

    self:RecordVerifiedKill(targetGUID, victimName, victimClass, victimLevel, wasEating, wasMounted)
end

-- Persiste la baja en la base de datos del personaje
function Tracker:RecordVerifiedKill(targetGUID, victimName, victimClass, victimLevel, wasEating, wasMounted)
    local charDB = ODD.Database:GetChar()
    if not charDB then return end

    local gnomes = charDB.observations.gnomes
    gnomes.kills = (gnomes.kills or 0) + 1
    self.sessionKills = (self.sessionKills or 0) + 1

    -- Comprobar si estás en grupo con otro compañero de hermandad
    local inGuildGroup = false
    if IsInGroup() then
        local numGroup = GetNumGroupMembers()
        local guildMembers = ODD.Guild and ODD.Guild.Roster and ODD.Guild.Roster:GetCachedMembers()
        local guildMap = {}
        if guildMembers then
            for _, gm in ipairs(guildMembers) do
                local cName = Ambiguate(gm.name or "", "none"):lower()
                guildMap[cName] = true
            end
        end

        local unitPrefix = IsInRaid() and "raid" or "party"
        for i = 1, numGroup do
            local uToken = unitPrefix .. i
            if UnitExists(uToken) and not UnitIsUnit(uToken, "player") then
                local uName = UnitName(uToken)
                if uName and guildMap[uName:lower()] then
                    inGuildGroup = true
                    break
                end
            end
        end
    end

    local killRecord = {
        killId = string.format("K%d-%s", time(), targetGUID:sub(-6)),
        targetGUID = targetGUID,
        victimName = victimName,
        victimClass = victimClass,
        victimLevel = victimLevel,
        wasEating = wasEating,
        wasMounted = wasMounted,
        inGuildGroup = inGuildGroup,
        timestamp = time(),
        zone = GetZoneText() or "Desconocida",
        origin = "local_observed",
    }

    table.insert(gnomes.records, killRecord)

    -- Guardado persistente
    _G["ODDCharacterDB"] = charDB

    local infoStr = ""
    if victimName then
        infoStr = string.format(" [%s - %s Nivel %s]", victimName, victimClass or "?", tostring(victimLevel or "?"))
    end
    ODD:Log("|cFFFFD100¡Gnomo Desokupado!|r Total bajas verificadas: %d%s (Zona: %s)", gnomes.kills, infoStr, killRecord.zone)

    -- Anuncio público por el chat de hermandad (/g)
    self:AnnounceToGuild(killRecord, gnomes.kills)

    -- Comprobar y notificar logros nuevos (Toast en pantalla + sonido)
    if ODD.Achievements and ODD.Achievements.Medals then
        ODD.Achievements.Medals:CheckNewAchievements()
    end

    -- Refrescar la pestaña del Gnomómetro si está abierta
    if ODD.UI.GnomometerTab and ODD.UI.GnomometerTab.Refresh then
        ODD.UI.GnomometerTab:Refresh()
    end
end

-- Envía el mensaje de exterminio al chat de hermandad
function Tracker:AnnounceToGuild(killRecord, totalKills)
    if not ODD.API.Forever:IsInGuild() then return end

    -- Comprobar si los anuncios a la guild están silenciados en Ajustes
    if ODD.Database:GetSetting("muteGuildAnnouncements") then return end

    local victimStr = killRecord.victimName or "un gnomo"
    if killRecord.victimLevel and killRecord.victimClass then
        victimStr = string.format("%s (%s nivel %s)", killRecord.victimName, killRecord.victimClass, tostring(killRecord.victimLevel))
    end

    local msg = string.format("[ODD] Gnomo exterminado: %s en %s! Mi cuenta asciende a %d bajas.", 
        victimStr, killRecord.zone or "Mundo Abierto", totalKills)

    -- SendChatMessage nativo al canal de hermandad
    local sendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or _G["SendChatMessage"]
    if sendChat then
        pcall(sendChat, msg, "GUILD")
    end
end

-- Inicializa la escucha de eventos de combate
function Tracker:Initialize()
    -- Escuchar cambio de objetivo y actualización de auras del objetivo
    ODD.Events:Register("PLAYER_TARGET_CHANGED", function()
        Tracker:CheckTargetAuras()
    end)
    ODD.Events:Register("UNIT_AURA", function(event, unitTarget)
        if unitTarget == "target" then
            Tracker:CheckTargetAuras()
        end
    end)

    -- En WoW Camelot/Forever, PARTY_KILL entrega (event, attackerGUID, targetGUID)
    ODD.Events:Register("PARTY_KILL", function(event, attackerGUID, targetGUID)
        Tracker:OnKillEvent(attackerGUID, targetGUID)
    end)

    ODD:Debug("Módulo Gnomómetro inicializado escuchando PARTY_KILL y auras.")
end
