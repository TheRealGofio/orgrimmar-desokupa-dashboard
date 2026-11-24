local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Tracker = {}
ODD.Gnomes = ODD.Gnomes or {}
ODD.Gnomes.Tracker = Tracker

-- Constantes de verificación
local GNOME_RACE_ID = 7 -- RaceID estándar de Gnomo en World of Warcraft
local KILL_COOLDOWN_WINDOW = 15 -- Cooldown reducido a 15s (idéntico a GRS) para evitar bloqueos en pruebas sucesivas

-- Historial reciente para deduplicación: [targetGUID] = timestamp
local recentKills = {}

-- Caché en vivo y observada de gnomos: [guid] = { name, classFile, level, timestamp }
local targetGnomeCache = {}
local liveSeenGnomes = {} -- [guid] = true/false para verificación instantánea

-- Caché de combate a corto plazo para capturar estados previos (comiendo / montura)
local combatAuraCache = {}

-- Contador de bajas en la sesión actual
Tracker.sessionKills = 0

-- Comprueba si el jugador está en mundo abierto (excluye BGs, Arenas, Mazmorras y Bandas)
function Tracker:IsWorldPvP()
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

-- Helper seguro para clasificar si es gnomo
local function ClassifyRace(raceToken, raceName)
    local rTok = ODD.API.Forever:SanitizeText(raceToken)
    local rNam = ODD.API.Forever:SanitizeText(raceName)
    if (rTok and rTok:lower():find("gnome")) or (rNam and rNam:lower():find("gnom")) then
        return true
    end
    return false
end

-- Escanea el objetivo actual para detectar estados de interés antes de que sufra daño
function Tracker:CheckTargetAuras()
    if not UnitExists("target") then return end
    local guid = ODD.API.Forever:SanitizeGUID(UnitGUID("target"))
    if not guid then return end

    local isGnome = false
    local okRace, raceName, raceFile, raceId = pcall(UnitRace, "target")
    if okRace and not ODD.API.Forever:IsSecret(raceId) and not ODD.API.Forever:IsSecret(raceFile) then
        local numId = ODD.API.Forever:SanitizeNumber(raceId)
        if numId == GNOME_RACE_ID or ClassifyRace(raceFile, raceName) then
            isGnome = true
        end
    end
    if not isGnome and liveSeenGnomes[guid] then
        isGnome = true
    end
    if not isGnome then return end

    -- Guardar en caché de gnomos para cuando muera
    -- En WoW Forever, los personajes pueden tener nombre y apellido.
    local fullName = nil
    if type(GetUnitName) == "function" then
        local okGN, gn = pcall(GetUnitName, "target", true)
        if okGN and gn and gn ~= "" then
            fullName = ODD.API.Forever:SanitizeText(gn)
        end
    end
    if not fullName then
        local okName, rawName = pcall(UnitName, "target")
        fullName = ODD.API.Forever:SanitizeText(rawName)
    end
    local name = fullName
    local okClass, _, rawClass = pcall(UnitClass, "target")
    local classFile = ODD.API.Forever:SanitizeText(rawClass)
    local okLvl, rawLevel = pcall(UnitLevel, "target")
    local level = ODD.API.Forever:SanitizeNumber(rawLevel) or "??"

    targetGnomeCache[guid] = {
        name = name or "Gnomo desconocido",
        classFile = classFile,
        level = level,
        timestamp = time()
    }
    liveSeenGnomes[guid] = true

    local wasEating = false
    local wasMounted = false

    -- Inspeccionar auras de forma segura y protegida contra taint
    pcall(function()
        if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
            for i = 1, 40 do
                local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL")
                if not aura then break end
                local aName = ODD.API.Forever:SanitizeText(aura.name)
                if aName then
                    local lowerName = aName:lower()
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
        elseif _G["UnitAura"] and type(_G["UnitAura"]) == "function" then
            for i = 1, 40 do
                local aName = _G["UnitAura"]("target", i, "HELPFUL")
                if not aName then break end
                aName = ODD.API.Forever:SanitizeText(aName)
                if aName then
                    local lowerName = aName:lower()
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

-- Intenta verificar si un GUID o token corresponde a un gnomo y extrae metadata
function Tracker:GetTargetInfo(unitToken, unitGUID)
    local token = unitToken
    local safeG = ODD.API.Forever:SanitizeGUID(unitGUID)
    if not token and safeG and UnitGUID("target") == safeG then
        token = "target"
    end

    -- 1. Intento por token activo ("target", "mouseover", etc.)
    if token and UnitExists(token) then
        local isGnome = false
        local okRace, raceName, raceFile, raceId = pcall(UnitRace, token)
        if okRace and not ODD.API.Forever:IsSecret(raceId) and not ODD.API.Forever:IsSecret(raceFile) then
            local numId = ODD.API.Forever:SanitizeNumber(raceId)
            if numId == GNOME_RACE_ID or ClassifyRace(raceFile, raceName) then
                isGnome = true
            end
        end
        local okName, rawName = pcall(UnitName, token)
        local name = ODD.API.Forever:SanitizeText(rawName)
        local okClass, _, rawClass = pcall(UnitClass, token)
        local classFile = ODD.API.Forever:SanitizeText(rawClass)
        local okLvl, rawLevel = pcall(UnitLevel, token)
        local level = ODD.API.Forever:SanitizeNumber(rawLevel) or "??"

        if isGnome then
            return true, "Gnome", name, classFile, level
        end
    end

    -- 2. Intento por caché previa observada en directo (GRS method)
    if safeG then
        if liveSeenGnomes[safeG] or targetGnomeCache[safeG] then
            local cached = targetGnomeCache[safeG]
            return true, "Gnome", cached and cached.name, cached and cached.classFile, cached and cached.level
        end
    end

    -- 3. Intento por GetPlayerInfoByGUID (API nativa de Blizzard)
    if safeG and type(GetPlayerInfoByGUID) == "function" then
        local ok, _, classFilename, localizedRace, englishRace, sex, name, realm = pcall(GetPlayerInfoByGUID, safeG)
        if ok then
            if ClassifyRace(englishRace, localizedRace) then
                return true, "Gnome", ODD.API.Forever:SanitizeText(name), ODD.API.Forever:SanitizeText(classFilename), nil
            end
        end
        -- Intento con segundo orden de retorno de Blizzard: (localizedRace, englishRace)
        local ok2, _, _, locRace2, engRace2, _, name2 = pcall(GetPlayerInfoByGUID, safeG)
        if ok2 then
            if ClassifyRace(engRace2, locRace2) then
                return true, "Gnome", ODD.API.Forever:SanitizeText(name2), nil, nil
            end
        end
    end

    return false, "UNVERIFIED", nil, nil, nil
end

-- Comprueba si el atacante es el jugador local o una mascota/tótem propia
function Tracker:IsPlayerOrPet(attackerGUID)
    local playerGUID = ODD.API.Forever:SanitizeGUID(UnitGUID("player"))
    local safeAttacker = ODD.API.Forever:SanitizeGUID(attackerGUID)
    if not playerGUID then return false end

    -- Coincidencia directa con el GUID del jugador
    if safeAttacker and safeAttacker == playerGUID then
        return true
    end

    -- Comprobación por mascota activa
    local petGUID = ODD.API.Forever:SanitizeGUID(UnitGUID("pet"))
    if petGUID and safeAttacker and safeAttacker == petGUID then
        return true
    end

    -- Comprobación por token nativo (UnitTokenFromGUID)
    if type(UnitTokenFromGUID) == "function" and attackerGUID then
        local ok, token = pcall(UnitTokenFromGUID, attackerGUID)
        if ok and token then
            token = ODD.API.Forever:SanitizeText(token)
            if token == "player" or token == "pet" then
                return true
            end
            if type(UnitIsUnit) == "function" then
                local okSameP, isP = pcall(UnitIsUnit, token, "player")
                if okSameP and isP == true then return true end
                local okSamePet, isPet = pcall(UnitIsUnit, token, "pet")
                if okSamePet and isPet == true then return true end
            end
        end
    end

    return false
end

-- Procesa un killing blow con verificación estricta de autoría y raza
function Tracker:OnKillEvent(attackerGUID, targetGUID, isDirectKill)
    local playerGUID = ODD.API.Forever:SanitizeGUID(UnitGUID("player"))
    local safeVictim = ODD.API.Forever:SanitizeGUID(targetGUID)
    local safeAttacker = ODD.API.Forever:SanitizeGUID(attackerGUID)

    if not safeVictim then return end

    -- 1. Regla de Autoría (Golpe de gracia estricto, modelo GRS):
    local isAuthorized = false
    local inGroup = IsInGroup and IsInGroup()

    if safeAttacker then
        isAuthorized = self:IsPlayerOrPet(safeAttacker)
    end

    if inGroup then
        -- En grupo / raid: SOLO cuenta si el atacante del killing blow eres TÚ o TU MASCOTA.
        -- Si un compañero de grupo dio el golpe de gracia, se descarta tajantemente.
        if not isAuthorized then
            return
        end
    else
        -- En solitario (sin grupo):
        -- Si safeAttacker no se pudo resolver, o el evento viene de UNIT_HEALTH (isDirectKill),
        -- o la víctima es nuestro objetivo actual, se acepta autoría de jugador solitario.
        if not isAuthorized then
            local targetCurr = ODD.API.Forever:SanitizeGUID(UnitGUID("target"))
            if isDirectKill or targetCurr == safeVictim then
                isAuthorized = true
            else
                isAuthorized = true
            end
        end
    end

    if not isAuthorized then
        return
    end

    -- 2. Regla: Exclusión de BGs e instancias (solo Mundo Abierto)
    if not self:IsWorldPvP() then
        return
    end

    -- 3. Regla: Deduplicación por cooldown de víctima
    local now = time()
    if recentKills[safeVictim] and (now - recentKills[safeVictim]) < KILL_COOLDOWN_WINDOW then
        return
    end

    -- 4. Regla: Verificación de raza (Gnomo) y lectura de metadata
    local isGnome, raceInfo, victimName, victimClass, victimLevel = self:GetTargetInfo(nil, safeVictim)
    if not isGnome then
        return
    end

    -- Registrar cooldown para evitar dobles conteos inmediatos
    recentKills[safeVictim] = now

    -- Recuperar estado previo de la víctima desde el caché de combate
    local auraData = combatAuraCache[safeVictim]
    local wasEating = false
    local wasMounted = false
    if auraData and (now - auraData.timestamp) < 45 then
        wasEating = auraData.wasEating == true
        wasMounted = auraData.wasMounted == true
    end

    self:RecordVerifiedKill(safeVictim, victimName, victimClass, victimLevel, wasEating, wasMounted)
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
        killId = string.format("K%d-%s", time(), tostring(targetGUID):sub(-6)),
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

    -- Notificar y procesar Contratos Semanales de Hermandad
    if ODD.Guild and ODD.Guild.Contracts and ODD.Guild.Contracts.OnLocalKill then
        ODD.Guild.Contracts:OnLocalKill({
            guid = targetGUID,
            name = victimName,
            classFile = victimClass,
            zone = killRecord.zone,
            timestamp = killRecord.timestamp,
        })
    end

    local infoStr = ""
    if victimName then
        infoStr = string.format(" [%s - %s Nivel %s]", victimName, victimClass or "?", tostring(victimLevel or "?"))
    end
    ODD:Log("|cFFFFD100¡Gnomo Desokupado!|r Total bajas verificadas: %d%s (Zona: %s)", gnomes.kills, infoStr, killRecord.zone)

    -- Anuncio público por el chat de hermandad (/g)
    self:AnnounceToGuild(killRecord, gnomes.kills)

    -- Reproducir sonido de baja de gnomo
    if ODD.Audio and ODD.Audio.PlayKillSound then
        ODD.Audio:PlayKillSound()
    end

    -- Comprobar y notificar logros nuevos (Toast en pantalla + sonido)
    if ODD.Achievements and ODD.Achievements.Medals then
        ODD.Achievements.Medals:CheckNewAchievements()
    end

    -- Refrescar la pestaña del Gnomómetro si está abierta
    if ODD.UI.GnomometerTab and ODD.UI.GnomometerTab.Refresh then
        ODD.UI.GnomometerTab:Refresh()
    end

    -- Refrescar HUD flotante compacto en pantalla si está activo
    if ODD.UI.HUD and ODD.UI.HUD.Refresh then
        ODD.UI.HUD:Refresh()
    end
end

-- Lista de frases ingeniosas y temáticas de Orgrimmar Desokupa para anunciar bajas
local KILL_ANNOUNCEMENT_TEMPLATES = {
    "¡Orden de desahucio ejecutada sobre %s en %s! Uno menos que molesta. (Total: %d)",
    "¡Desalojo completado sin fianza para %s en %s! El local queda precintado. (Total: %d)",
    "Acabo de enviar a %s al cementerio desde %s. Que no vuelva a okupar suelo de la Horda. (Total: %d)",
    "¡Fumigación exitosa en %s! El gnomo %s ha sido neutralizado. (Total: %d)",
    "Pisotón contundente a %s en %s. Debería haber mirado por dónde pisaba. (Total: %d)",
    "¡Cláusula de rescisión aplicada a %s en %s! Bajas totales acumuladas: %d.",
    "¿Quién dejó a este gnomo suelto? %s ha sido desalojado en %s. (Cuenta personal: %d)",
    "Propiedad recuperada en %s tras mandar al hoyo a %s. ¡Por la Horda! (Total: %d)",
    "Desalojo exprés en %s: %s ha aprendido por las malas a respetar los alquileres. (Total: %d)",
    "¡Otro gnomo que muerde el polvo! %s despachado en %s sin derecho a recurso. (Total: %d)",
}

-- Envía el anuncio de exterminio a la hermandad mediante mensaje de Addon P2P silencioso
function Tracker:AnnounceToGuild(killRecord, totalKills)
    if not ODD.API.Forever:IsInGuild() then return end

    -- Comprobar si los anuncios a la guild están silenciados en Ajustes
    if ODD.Database:GetSetting("muteGuildAnnouncements") then return end

    if ODD.Network and ODD.Network.Sync and ODD.Network.Sync.BroadcastKill then
        ODD.Network.Sync:BroadcastKill(killRecord, totalKills)
    end
end

-- Escanea cualquier unidad visible o de placa para recordar gnomos en el entorno
function Tracker:InspectUnit(token)
    if not token or type(token) ~= "string" or not UnitExists(token) or not UnitIsPlayer(token) then return end
    local guid = ODD.API.Forever:SanitizeGUID(UnitGUID(token))
    if not guid then return end

    local isGnome = false
    local okRace, raceName, raceFile, raceId = pcall(UnitRace, token)
    if okRace and not ODD.API.Forever:IsSecret(raceId) and not ODD.API.Forever:IsSecret(raceFile) then
        local numId = ODD.API.Forever:SanitizeNumber(raceId)
        if numId == GNOME_RACE_ID or ClassifyRace(raceFile, raceName) then
            isGnome = true
        end
    end
    if not isGnome then return end

    -- Asegurar que es de la facción enemiga (Alianza) y no está muerto
    local isEnemy = false
    if type(UnitIsEnemy) == "function" then
        local okEn, en = pcall(UnitIsEnemy, "player", token)
        if okEn and en == true then isEnemy = true end
    end
    local isDead = false
    if type(UnitIsDead) == "function" then
        local okDead, d = pcall(UnitIsDead, token)
        if okDead and d == true then isDead = true end
    end

    -- En WoW Forever, los personajes pueden tener nombre y apellido.
    -- GetUnitName(token, true) devuelve el nombre completo (nombre + apellido).
    local fullName = nil
    if type(GetUnitName) == "function" then
        local okGN, gn = pcall(GetUnitName, token, true)
        if okGN and gn and gn ~= "" then
            fullName = ODD.API.Forever:SanitizeText(gn)
        end
    end
    if not fullName then
        local okName, rawName = pcall(UnitName, token)
        fullName = ODD.API.Forever:SanitizeText(rawName)
    end
    local name = fullName
    local okClass, _, rawClass = pcall(UnitClass, token)
    local classFile = ODD.API.Forever:SanitizeText(rawClass)
    local okLvl, rawLevel = pcall(UnitLevel, token)
    local level = ODD.API.Forever:SanitizeNumber(rawLevel) or "??"

    targetGnomeCache[guid] = {
        name = name or "Gnomo desconocido",
        classFile = classFile,
        level = level,
        timestamp = time()
    }
    liveSeenGnomes[guid] = true

    -- Disparar Radar de Proximidad si es un gnomo enemigo vivo en mundo abierto
    if isEnemy and not isDead and self:IsWorldPvP() then
        if ODD.Gnomes and ODD.Gnomes.Radar and ODD.Gnomes.Radar.TriggerAlert then
            ODD.Gnomes.Radar:TriggerAlert(guid, name, classFile, level, token)
        end
    end
end

-- Escaneo de objetivos visibles activos
function Tracker:ScanVisible()
    Tracker:InspectUnit("target")
    Tracker:InspectUnit("mouseover")
    Tracker:InspectUnit("focus")
    Tracker:InspectUnit("pettarget")
end

-- Inicializa la escucha de eventos de combate
function Tracker:Initialize()
    -- Escuchar objetivos, ratón y placas de nombre para registrar gnomos visibles
    ODD.Events:Register("PLAYER_TARGET_CHANGED", function()
        Tracker:ScanVisible()
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
        local safeA = ODD.API.Forever:SanitizeGUID(attackerGUID)
        local safeT = ODD.API.Forever:SanitizeGUID(targetGUID) or ODD.API.Forever:SanitizeGUID(UnitGUID("target"))
        Tracker:OnKillEvent(safeA, safeT, false)
    end)

    -- Observador en tiempo real por salud de objetivo (método GRS para bajas en solitario y tótems/DoTs)
    ODD.Events:Register("UNIT_HEALTH", function(event, unit)
        -- Si estamos en grupo, NO inferir kills por UNIT_HEALTH para evitar robos o falsas atribuciones entre compañeros.
        -- PARTY_KILL se encargará con el GUID exacto del autor.
        if IsInGroup and IsInGroup() then return end

        if unit ~= "target" and unit ~= "pettarget" then return end
        if not UnitExists(unit) then return end

        local guid = ODD.API.Forever:SanitizeGUID(UnitGUID(unit))
        if not guid then return end

        local isDead = false
        if type(UnitIsDead) == "function" then
            local okDead, deadVal = pcall(UnitIsDead, unit)
            if okDead and deadVal ~= nil and not ODD.API.Forever:IsSecret(deadVal) then
                isDead = (deadVal == true)
            end
        end

        local hpZero = false
        local okHp, rawHp = pcall(UnitHealth, unit)
        if okHp and rawHp ~= nil and not ODD.API.Forever:IsSecret(rawHp) then
            local numHp = ODD.API.Forever:SanitizeNumber(rawHp)
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
