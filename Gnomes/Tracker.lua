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

-- Caché reciente de gnomos observados en combate: [guid] = { name, class, level, timestamp }
local targetGnomeCache = {}

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

    local isGnome = false
    local okRace, raceName, raceFile, raceId = pcall(UnitRace, "target")
    if okRace and not ODD.API.Forever:IsSecret(raceId) then
        isGnome = (raceId == GNOME_RACE_ID or (raceFile and raceFile:lower() == "gnome"))
    end
    if not isGnome then return end

    -- Guardar en caché de gnomos para cuando muera y ya no sea target
    local name = UnitName("target")
    local _, classFile = UnitClass("target")
    local okLvl, rawLevel = pcall(UnitLevel, "target")
    local level = "??"
    if okLvl and rawLevel and not ODD.API.Forever:IsSecret(rawLevel) then
        local numLvl = tonumber(rawLevel)
        if numLvl and numLvl > 0 then
            level = numLvl
        end
    end

    targetGnomeCache[guid] = {
        name = name,
        classFile = classFile,
        level = level,
        timestamp = time()
    }

    local wasEating = false
    local wasMounted = false

    -- Inspeccionar auras del gnomo de forma compatible con la API moderna/Forever
    -- En WoW moderno (10.x/11.x/12.x/Forever), UnitAura clásica está retirada a favor de C_UnitAuras
    pcall(function()
        if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
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
        elseif type(_G["UnitAura"]) == "function" then
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
    end)

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

    -- 1. Intento por token activo ("target", "mouseover", etc.)
    if token and UnitExists(token) then
        local isGnome = false
        local okRace, raceName, raceFile, raceId = pcall(UnitRace, token)
        if okRace and not ODD.API.Forever:IsSecret(raceId) then
            isGnome = (raceId == GNOME_RACE_ID or (raceFile and raceFile:lower() == "gnome"))
        end
        local name = UnitName(token)
        local _, classFile = UnitClass(token)
        local okLvl, rawLevel = pcall(UnitLevel, token)
        local level = "??"
        if okLvl and rawLevel and not ODD.API.Forever:IsSecret(rawLevel) then
            local numLvl = tonumber(rawLevel)
            if numLvl and numLvl > 0 then
                level = numLvl
            end
        end

        return isGnome, raceFile or "Gnome", name, classFile, level
    end

    -- 2. Intento por GetPlayerInfoByGUID (API nativa de Blizzard para resolver raza por GUID de jugador)
    if unitGUID and type(GetPlayerInfoByGUID) == "function" and not ODD.API.Forever:IsSecret(unitGUID) then
        local ok, _, classFilename, localizedRace, englishRace, sex, name, realm = pcall(GetPlayerInfoByGUID, unitGUID)
        if ok and (englishRace or localizedRace) then
            local isGnome = false
            if englishRace and type(englishRace) == "string" and englishRace:lower():find("gnome") then
                isGnome = true
            elseif localizedRace and type(localizedRace) == "string" and localizedRace:lower():find("gnom") then
                isGnome = true
            end
            if isGnome then
                return true, englishRace or "Gnome", name, classFilename, nil
            end
        end
        -- Variante con doble descarte si el retorno es (localizedRace, englishRace)
        local ok2, _, _, locRace2, engRace2, _, name2, realm2 = pcall(GetPlayerInfoByGUID, unitGUID)
        if ok2 and (engRace2 or locRace2) then
            local isGnome2 = false
            if engRace2 and type(engRace2) == "string" and engRace2:lower():find("gnome") then
                isGnome2 = true
            elseif locRace2 and type(locRace2) == "string" and locRace2:lower():find("gnom") then
                isGnome2 = true
            end
            if isGnome2 then
                return true, engRace2 or "Gnome", name2, nil, nil
            end
        end
    end

    -- 3. Intento por historial de combate reciente observado
    if unitGUID and targetGnomeCache[unitGUID] then
        local cached = targetGnomeCache[unitGUID]
        if (time() - cached.timestamp) < 60 then
            return true, "Gnome", cached.name, cached.classFile, cached.level
        end
    end

    return false, "UNVERIFIED", nil, nil, nil
end

-- Comprueba si el atacante es el jugador local o una mascota/tótem propia
function Tracker:IsPlayerOrPet(attackerGUID)
    local playerGUID = UnitGUID("player")
    if not playerGUID then return false end

    -- Coincidencia directa con el GUID del jugador
    if attackerGUID == playerGUID then
        return true
    end

    -- Comprobación por mascota activa
    local petGUID = UnitGUID("pet")
    if petGUID and attackerGUID == petGUID then
        return true
    end

    -- Comprobación por token nativo (WoW resuelve tótems/mascotas/guardianes asociados al player)
    if type(UnitTokenFromGUID) == "function" and attackerGUID then
        local ok, token = pcall(UnitTokenFromGUID, attackerGUID)
        if ok and token then
            if token == "player" or token == "pet" then
                return true
            end
            if type(UnitIsUnit) == "function" then
                if UnitIsUnit(token, "player") or UnitIsUnit(token, "pet") then
                    return true
                end
            end
        end
    end

    return false
end

-- Procesa un killing blow con verificación estricta de autoría y raza
function Tracker:OnKillEvent(attackerGUID, targetGUID, isDirectKill)
    -- Protección contra 'secret values' en el motor moderno de WoW Forever
    if ODD.API.Forever:IsSecret(attackerGUID) or ODD.API.Forever:IsSecret(targetGUID) then
        return
    end

    local playerGUID = UnitGUID("player")
    if not playerGUID or not targetGUID then return end
    if ODD.API.Forever:IsSecret(playerGUID) then return end

    -- 1. Regla de Autoría:
    -- Si tenemos attackerGUID, comprobamos si es el jugador, su mascota o sus tótems
    local isAuthorized = false
    if attackerGUID then
        isAuthorized = self:IsPlayerOrPet(attackerGUID)
    end

    -- Si no vino attackerGUID (o vino masked), pero es una muerte directa observada sobre el target al que el jugador estaba pegando solo:
    if not isAuthorized and isDirectKill then
        if UnitGUID("target") == targetGUID then
            isAuthorized = true
        end
    end

    if not isAuthorized then
        -- Descartado: kill de otro jugador o de terceros
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

-- Escanea cualquier unidad visible o de placa para recordar gnomos en el entorno
function Tracker:InspectUnit(token)
    if not token or type(token) ~= "string" or not UnitExists(token) or not UnitIsPlayer(token) then return end
    local guid = UnitGUID(token)
    if not guid or ODD.API.Forever:IsSecret(guid) then return end

    local isGnome = false
    local okRace, raceName, raceFile, raceId = pcall(UnitRace, token)
    if okRace and not ODD.API.Forever:IsSecret(raceId) then
        isGnome = (raceId == GNOME_RACE_ID or (raceFile and raceFile:lower() == "gnome"))
    end
    if not isGnome then return end

    local name = UnitName(token)
    local _, classFile = UnitClass(token)
    local okLvl, rawLevel = pcall(UnitLevel, token)
    local level = "??"
    if okLvl and rawLevel and not ODD.API.Forever:IsSecret(rawLevel) then
        local numLvl = tonumber(rawLevel)
        if numLvl and numLvl > 0 then
            level = numLvl
        end
    end

    targetGnomeCache[guid] = {
        name = name,
        classFile = classFile,
        level = level,
        timestamp = time()
    }
end

-- Inicializa la escucha de eventos de combate
function Tracker:Initialize()
    -- Escuchar objetivos, ratón y placas de nombre para registrar gnomos visibles
    ODD.Events:Register("PLAYER_TARGET_CHANGED", function()
        Tracker:InspectUnit("target")
        Tracker:CheckTargetAuras()
    end)
    ODD.Events:Register("UPDATE_MOUSEOVER_UNIT", function()
        Tracker:InspectUnit("mouseover")
    end)
    ODD.Events:Register("NAME_PLATE_UNIT_ADDED", function(event, unitToken)
        Tracker:InspectUnit(unitToken)
    end)
    ODD.Events:Register("UNIT_AURA", function(event, unitTarget)
        if unitTarget == "target" then
            Tracker:CheckTargetAuras()
        end
    end)

    -- En WoW Camelot/Forever, PARTY_KILL entrega (event, attackerGUID, targetGUID)
    ODD.Events:Register("PARTY_KILL", function(event, attackerGUID, targetGUID)
        if not attackerGUID and UnitGUID("player") then
            attackerGUID = UnitGUID("player")
        end
        if not targetGUID and UnitGUID("target") then
            targetGUID = UnitGUID("target")
        end
        Tracker:OnKillEvent(attackerGUID, targetGUID, false)
    end)

    -- Observador en tiempo real por salud de objetivo (método GRS para bajas en solitario y tótems/DoTs)
    ODD.Events:Register("UNIT_HEALTH", function(event, unit)
        if unit ~= "target" then return end
        if not UnitExists("target") then return end

        local guid = UnitGUID("target")
        if not guid or ODD.API.Forever:IsSecret(guid) then return end

        local isDead = false
        if type(UnitIsDead) == "function" then
            local okDead, deadVal = pcall(UnitIsDead, "target")
            if okDead and deadVal ~= nil and not ODD.API.Forever:IsSecret(deadVal) then
                isDead = (deadVal == true)
            end
        end

        local hpZero = false
        local okHp, rawHp = pcall(UnitHealth, "target")
        if okHp and rawHp ~= nil and not ODD.API.Forever:IsSecret(rawHp) then
            local numHp = tonumber(rawHp)
            if numHp and numHp <= 0 then
                hpZero = true
            end
        end

        if isDead or hpZero then
            Tracker:OnKillEvent(UnitGUID("player"), guid, true)
        end
    end)

    ODD:Debug("Módulo Gnomómetro inicializado escuchando PARTY_KILL, UNIT_HEALTH, placas y GetPlayerInfoByGUID.")
end
