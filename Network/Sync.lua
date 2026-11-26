local addonName, addonTable = ...
local ODD = addonTable.ODD

local Sync = {}
ODD.Network.Sync = Sync

-- Historial de mensajes recientes recibidos para evitar duplicados (sender:msgId)
local seenMessages = {}
local presenceList = {} -- miembros con ODD detectados online
local versionWarned = false -- flag para alertar de versión desactualizada solo una vez por sesión
local lastGossipTime = 0 -- control de frecuencia de réplica de caché global

-- Helper semántico para comparar versiones (ej: "0.3.10-alpha" vs "0.3.9-alpha")
-- Devuelve 1 si verA > verB, -1 si verA < verB, 0 si son iguales
local function CompareVersions(verA, verB)
    if not verA or not verB then return 0 end
    if verA == verB then return 0 end

    local function parse(vStr)
        local major, minor, patch, pre = tostring(vStr):match("^(%d+)%.(%d+)%.(%d+)-?(%w*)")
        return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0, pre or ""
    end

    local majA, minA, patA = parse(verA)
    local majB, minB, patB = parse(verB)

    if majA ~= majB then return (majA > majB) and 1 or -1 end
    if minA ~= minB then return (minA > minB) and 1 or -1 end
    if patA ~= patB then return (patA > patB) and 1 or -1 end
    return 0
end

function Sync:Initialize()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(ODD.Network.Protocol.PREFIX)
    elseif _G["RegisterAddonMessagePrefix"] then
        _G["RegisterAddonMessagePrefix"](ODD.Network.Protocol.PREFIX)
    end

    ODD.Events:Register("CHAT_MSG_ADDON", function(event, prefix, text, channel, sender)
        if prefix ~= ODD.Network.Protocol.PREFIX then return end
        Sync:OnMessageReceived(text, channel, sender)
    end)

    ODD:Debug("Módulo de Red y Sincronización inicializado.")
end

-- Envía HELLO con presencia y versión de ODD con jitter aleatorio
function Sync:BroadcastHello(delaySeconds)
    delaySeconds = delaySeconds or (math.random(1, 5)) -- Jitter de 1 a 5s

    C_Timer.After(delaySeconds, function()
        if not ODD.API.Forever:IsInGuild() then return end
        if not ODD.Database:GetSetting("sharePresence") then return end

        local pInfo = ODD.API.Forever:GetPlayerInfo()
        local data = {
            ver = ODD.version,
            cls = pInfo.className,
            lvl = pInfo.level,
        }
        
        -- Añadir main o rol si está configurado compartir perfil
        if ODD.Database:GetSetting("shareProfile") then
            local profile = ODD.Guild.Profiles:GetLocalProfile()
            if profile.mainCharacter then data.main = profile.mainCharacter end
            if profile.customRole then data.role = profile.customRole end
        end

        -- Añadir estadísticas de bajas del Gnomómetro, puntos de logro y top zonas si está configurado compartir estadísticas
        if ODD.Database:GetSetting("shareStats") then
            local charDB = ODD.Database:GetChar()
            if charDB and charDB.observations and charDB.observations.gnomes then
                data.gk = charDB.observations.gnomes.kills or 0

                -- Calcular las 2 zonas más frecuentes del jugador para el mapa de zonas calientes colectivo
                local zoneCounts = {}
                local records = charDB.observations.gnomes.records or {}
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
                    data.tz = table.concat(topList, ";")
                end
            end
            if ODD.Achievements and ODD.Achievements.Medals then
                data.ap = ODD.Achievements.Medals:GetPlayerAchievementPoints()
            end
        end

        -- Añadir bajas de contratos semanales para sincronización P2P
        -- Limitamos a un máximo de 1-2 firmas recientes por contrato para no saturar el cable (250 bytes)
        if ODD.Guild and ODD.Guild.Contracts then
            local store = ODD.Guild.Contracts:EnsureStorage()
            local weekID = ODD.Guild.Contracts:GetCurrentWeekID()
            if store and (next(store.zoneKills or {}) or next(store.classKills or {})) then
                data.cw = weekID
                -- Serializar como mucho 1 firma por contrato en el HELLO para mantener el paquete ultraligero
                local zSigs = {}
                for sig, _ in pairs(store.zoneKills or {}) do
                    table.insert(zSigs, sig)
                    if #zSigs >= 1 then break end
                end
                if #zSigs > 0 then data.czk = table.concat(zSigs, "|") end

                local cSigs = {}
                for sig, _ in pairs(store.classKills or {}) do
                    table.insert(cSigs, sig)
                    if #cSigs >= 1 then break end
                end
                if #cSigs > 0 then data.cck = table.concat(cSigs, "|") end
            end
        end

        local codec, encoded = ODD.Network.Codec:Encode(data)
        local msgId = ODD.Network.Protocol:GenerateMsgId()
        local line = ODD.Network.Protocol:FormatLine("HELLO", msgId, "*", codec, encoded)

        -- Si la línea empaquetada excede el límite de cable (por ejemplo si el codec CB1/Base64 infla el tamaño),
        -- forzamos fallback al serializador plano 'S1' para garantizar que viaje en un único paquete seguro
        if #line > ODD.Network.Protocol.MAX_WIRE_BYTES and codec ~= "S1" then
            local _, s1Encoded = ODD.Network.Codec:EncodeSimple(data)
            local fallbackLine = ODD.Network.Protocol:FormatLine("HELLO", msgId, "*", "S1", s1Encoded)
            if #fallbackLine <= ODD.Network.Protocol.MAX_WIRE_BYTES then
                line = fallbackLine
            end
        end

        -- Saneamiento preventivo de seguridad: asegurar que line jamás exceda MAX_WIRE_BYTES (250 bytes)
        if #line > ODD.Network.Protocol.MAX_WIRE_BYTES then
            -- 1. Intentar primero con S1 sin contratos
            data.czk = nil
            data.cck = nil
            data.cw = nil
            local _, s1NoContracts = ODD.Network.Codec:EncodeSimple(data)
            local trimmedLine = ODD.Network.Protocol:FormatLine("HELLO", msgId, "*", "S1", s1NoContracts)
            if #trimmedLine <= ODD.Network.Protocol.MAX_WIRE_BYTES then
                line = trimmedLine
            else
                -- 2. Si todavía excediera (por nombres o zonas excesivamente largas), podar campos secundarios no críticos
                data.tz = nil
                data.main = nil
                data.role = nil
                local _, minimalEncoded = ODD.Network.Codec:EncodeSimple(data)
                line = ODD.Network.Protocol:FormatLine("HELLO", msgId, "*", "S1", minimalEncoded)
            end
        end

        ODD.Network.Queue:Enqueue(line, "GUILD")
        ODD:Debug("Enviado anuncio de presencia HELLO.")
    end)
end

-- Réplica de Caché Gossip P2P: Envía a la hermandad las filas de miembros que
-- tenemos en nuestra base de datos local y que podrían faltarle a otros
function Sync:BroadcastGossipCache(targetRequester)
    if not ODD.API.Forever:IsInGuild() then return end
    local globalDB = ODD.Database:GetGlobal()
    if not globalDB or not globalDB.profiles then return end

    local myName = (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player")
    local myShort = Ambiguate(myName or "", "none"):lower()

    local batch = {}
    local currentLen = 0

    local function FlushBatch()
        if #batch == 0 then return end
        local payload = table.concat(batch, "#")
        local msgId = ODD.Network.Protocol:GenerateMsgId()
        -- Siempre enviar con target "*" a nivel de hermandad para evitar rechazos de nombres cortos/apellidos
        local line = ODD.Network.Protocol:FormatLine("GOSSIP", msgId, "*", "RAW", payload)
        ODD.Network.Queue:Enqueue(line, "GUILD")
        batch = {}
        currentLen = 0
    end

    for name, p in pairs(globalDB.profiles) do
        local clean = Ambiguate(name, "none"):lower()
        if clean ~= myShort and ((p.gnomeKills and p.gnomeKills > 0) or (p.achievementPoints and p.achievementPoints > 0)) then
            -- Formato compacto: Nombre=Clase,Bajas,Puntos,UpdatedAt
            local entry = string.format("%s=%s,%d,%d,%d", name, p.className or "WARRIOR", p.gnomeKills or 0, p.achievementPoints or 0, p.updatedAt or 0)
            -- Límite conservador de 120 bytes para que nunca exceda el cable format
            if (currentLen + #entry + 2) > 120 then
                FlushBatch()
            end
            table.insert(batch, entry)
            currentLen = currentLen + #entry + 1
        end
    end
    FlushBatch()
end

-- Emite anuncio de baja mortal a través del canal de addon silencioso
function Sync:BroadcastKill(killRecord, totalKills)
    if not ODD.API.Forever:IsInGuild() then return end
    if ODD.Database:GetSetting("muteGuildAnnouncements") then return end

    local pInfo = ODD.API.Forever:GetPlayerInfo()
    local myClass = pInfo.classFile or select(2, UnitClass("player")) or "WARRIOR"
    local myFullName = pInfo.name or (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "Desconocido"

    local data = {
        k = myFullName,
        kc = myClass,
        v = killRecord.victimName or "Gnomo",
        vc = killRecord.victimClass or "MAGE",
        vl = tostring(killRecord.victimLevel or "??"),
        z = killRecord.zone or "Mundo Abierto",
        tk = totalKills or 1,
    }

    local codec, encoded = ODD.Network.Codec:EncodeSimple(data)
    local msgId = ODD.Network.Protocol:GenerateMsgId()
    local line = ODD.Network.Protocol:FormatLine("KILL", msgId, "*", codec, encoded)
    ODD.Network.Queue:Enqueue(line, "GUILD")

    -- Imprimir también en el chat local propio para confirmación visual inmediata
    self:DisplayKillInChat(data.k, data.kc, data.v, data.vc, data.vl, data.z, data.tk, true)
end

-- Emite anuncio de logro desbloqueado a través del canal de addon silencioso
function Sync:BroadcastAchievement(achievementId, achievementName, points)
    if not ODD.API.Forever:IsInGuild() then return end
    if ODD.Database:GetSetting("muteGuildAnnouncements") then return end

    local pInfo = ODD.API.Forever:GetPlayerInfo()
    local myClass = pInfo.classFile or select(2, UnitClass("player")) or "WARRIOR"
    local myFullName = pInfo.name or (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "Desconocido"

    local data = {
        p = myFullName,
        pc = myClass,
        aid = achievementId or "gnome_1",
        an = achievementName or "Logro",
        pts = points or 10,
        t = time(),
    }

    local codec, encoded = ODD.Network.Codec:EncodeSimple(data)
    local msgId = ODD.Network.Protocol:GenerateMsgId()
    local line = ODD.Network.Protocol:FormatLine("ACHIEVE", msgId, "*", codec, encoded)
    ODD.Network.Queue:Enqueue(line, "GUILD")

    -- Imprimir en el chat local propio con enlace interactivo
    self:DisplayAchievementInChat(data.p, data.pc, data.aid, data.an, data.pts, data.t, true)
end

local CLASS_COLORS = {
    ["WARRIOR"]     = "FFC79C6E",
    ["PALADIN"]     = "FFF58CBA",
    ["HUNTER"]      = "FFABD473",
    ["ROGUE"]       = "FFFFF569",
    ["PRIEST"]      = "FFFFFFFF",
    ["DEATHKNIGHT"] = "FFC41F3B",
    ["SHAMAN"]      = "FF0070DE",
    ["MAGE"]        = "FF69CCF0",
    ["WARLOCK"]     = "FF9482C9",
    ["MONK"]        = "FF00FF96",
    ["DRUID"]       = "FFFF7D0A",
    ["DEMONHUNTER"] = "FFA330C9",
    ["EVOKER"]      = "FF33937F",
}

function Sync:DisplayKillInChat(killer, killerClass, victim, victimClass, victimLvl, zone, totalKills, isSelf)
    local kColor = CLASS_COLORS[killerClass] or "FFFFFFFF"
    local vColor = CLASS_COLORS[victimClass] or "FFFFFFFF"
    local killerStr = string.format("|c%s%s|r", kColor, killer)
    local victimStr = string.format("|c%s%s (%s Nivel %s)|r", vColor, victim, victimClass or "?", tostring(victimLvl or "?"))

    local outMsg = string.format("|cFFFF8000[ODD]|r %s ha desalojado a %s en |cFFFFFFFF%s|r. |cFF00FF00(Total: %d)|r",
        killerStr, victimStr, zone or "Mundo Abierto", tonumber(totalKills) or 1)

    DEFAULT_CHAT_FRAME:AddMessage(outMsg)
end

function Sync:DisplayAchievementInChat(playerName, playerClass, achId, achName, points, timestamp, isSelf)
    local pColor = CLASS_COLORS[playerClass] or "FFFFFFFF"
    local playerStr = string.format("|c%s%s|r", pColor, playerName)
    local t = timestamp or time()
    
    -- Enlace interactivo con protocolo nativo de WoW: |Hitem:ODDACH:id:points:player:timestamp|h[Nombre del logro]|h
    local achLink = string.format("|cFF00FFCC|Hitem:ODDACH:%s:%d:%s:%d|h[%s]|h|r", tostring(achId), tonumber(points) or 10, playerName or "Compañero", t, achName or "Logro")

    local outMsg = string.format("|cFFFF8000[ODD]|r %s ha conseguido el logro %s |cFFFFD100(+%d pts)|r",
        playerStr, achLink, tonumber(points) or 10)

    DEFAULT_CHAT_FRAME:AddMessage(outMsg)
end

-- Solicitud de sincronización de hermandad
local lastWindowSyncTime = 0

function Sync:RequestGuildSync()
    if not ODD.API.Forever:IsInGuild() then return end

    local now = GetTime()
    -- Throttle de seguridad: como máximo 1 ráfaga cada 3 segundos si el usuario abre y cierra la ventana rápidamente
    if (now - lastWindowSyncTime) < 3 then
        return
    end
    lastWindowSyncTime = now

    ODD:Debug("Sincronización en vivo activada.")
    -- 1. Emitir nuestro estado actual de inmediato
    self:BroadcastHello(0)

    -- 2. Emitir solicitud de ping (REQ) para que todos los compañeros online respondan con sus datos actuales
    local msgId = ODD.Network.Protocol:GenerateMsgId()
    local line = ODD.Network.Protocol:FormatLine("REQ", msgId, "*", "RAW", "SYNC")
    ODD.Network.Queue:Enqueue(line, "GUILD")
end

function Sync:TriggerManualSync()
    if not ODD.API.Forever:IsInGuild() then
        ODD:Log("No estás en una hermandad para sincronizar.")
        return
    end

    local globalDB = ODD.Database:GetGlobal()
    local count = 0
    if globalDB and globalDB.profiles then
        for _ in pairs(globalDB.profiles) do count = count + 1 end
    end
    ODD:Log("Sincronizando con la hermandad... (%d perfiles en tu base de datos local).", count)
    lastWindowSyncTime = 0 -- Forzar sin throttle
    self:RequestGuildSync()
    -- Emitir también un barrido de nuestra caché a la hermandad
    C_Timer.After(0.5, function()
        Sync:BroadcastGossipCache("*")
    end)
end

-- Helper para refrescar vistas abiertas en la interfaz
local function RefreshAllOpenTabs()
    if ODD.UI.HQTab and ODD.UI.HQTab.RefreshStats then
        ODD.UI.HQTab:RefreshStats()
    end
    if ODD.UI.HQTab and ODD.UI.HQTab.RefreshPresence then
        ODD.UI.HQTab:RefreshPresence()
    end
    if ODD.UI.HQTab and ODD.UI.HQTab.RefreshContracts then
        ODD.UI.HQTab:RefreshContracts()
    end
    if ODD.UI.GnomometerTab and ODD.UI.GnomometerTab.Refresh then
        ODD.UI.GnomometerTab:Refresh()
    end
    if ODD.UI.HistoryTab and ODD.UI.HistoryTab.Refresh then
        ODD.UI.HistoryTab:Refresh()
    end
end

function Sync:OnMessageReceived(text, channel, sender)
    -- Limpieza de reino en el sender
    local senderName = Ambiguate(sender, "none")
    local myName = (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player")
    local myFullName, myRealm = UnitFullName("player")
    local myCombinedName = (myFullName and myRealm and myRealm ~= "") and (myFullName .. "-" .. myRealm) or (myFullName or myName)

    local function IsMe(name)
        if not name then return false end
        local cName = Ambiguate(name, "none"):lower()
        local cMyName = Ambiguate(myName, "none"):lower()
        local cComb = myCombinedName:lower()
        return (cName == cMyName) or (name:lower() == cComb) or (name:lower():find("^" .. cMyName))
    end

    if IsMe(senderName) or IsMe(sender) then return end -- Ignorar mensajes propios reflejados por el canal de hermandad

    local parsed, err = ODD.Network.Protocol:ParseLine(text)
    if not parsed then
        ODD:Debug("Mensaje de addon descartado: %s", tostring(err))
        return
    end

    -- Deduplicación
    local dedupeKey = senderName .. ":" .. parsed.msgId
    if seenMessages[dedupeKey] then return end
    seenMessages[dedupeKey] = GetTime()

    -- Comprobación de destinatario: aceptar broadcasts "*" y mensajes dirigidos por nombre completo o de pila
    if parsed.target ~= "*" and parsed.target ~= myName and parsed.target ~= senderName then
        local shortTarget = Ambiguate(parsed.target, "none"):lower()
        local shortMy = Ambiguate(myName, "none"):lower()
        local firstTarget = shortTarget:match("^(%S+)") or shortTarget
        local firstMy = shortMy:match("^(%S+)") or shortMy
        if shortTarget ~= shortMy and firstTarget ~= firstMy then
            return
        end
    end

    if parsed.type == "HELLO" then
        local data = ODD.Network.Codec:Decode(parsed.codec, parsed.payload)
        if data then
            presenceList[senderName] = {
                version = data.ver,
                class = data.cls,
                level = data.lvl,
                main = data.main,
                role = data.role,
                lastSeen = time(),
                origin = string.format("Declarado por %s (no verificado)", senderName),
            }

            -- Comprobación de versión desactualizada P2P
            if data.ver and not versionWarned then
                local cmp = CompareVersions(data.ver, ODD.version)
                if cmp > 0 then
                    versionWarned = true
                    ODD.newerVersionAvailable = data.ver
                    local warnMsg = string.format("|cFFFF8000[ODD]|r |cFFFF2020¡Nueva versión disponible!|r Tienes una versión desactualizada (|cFFFFD100v%s|r). Ya puedes descargar la nueva versión (|cFF00FF00v%s|r) desde GitHub o WowUp.",
                        tostring(ODD.version), tostring(data.ver))
                    DEFAULT_CHAT_FRAME:AddMessage(warnMsg)
                end
            end
            if data.gk or data.ap then
                presenceList[senderName].gnomeKills = tonumber(data.gk) or 0
                presenceList[senderName].achievementPoints = tonumber(data.ap) or 0
                presenceList[senderName].topZones = data.tz

                -- Guardar en los perfiles globales para persistencia en el Leaderboard
                local globalDB = ODD.Database:GetGlobal()
                if globalDB then
                    globalDB.profiles = globalDB.profiles or {}
                    globalDB.profiles[senderName] = globalDB.profiles[senderName] or {}
                    local prof = globalDB.profiles[senderName]
                    prof.name = senderName
                    prof.className = data.cls
                    prof.gnomeKills = tonumber(data.gk) or 0
                    prof.achievementPoints = tonumber(data.ap) or 0
                    if data.tz then
                        prof.topZones = data.tz
                    end
                    prof.updatedAt = time()
                    _G["ODDDB"] = globalDB
                end
            end

            -- Procesar sincronización de contratos semanales
            if data.cw and (data.czk or data.cck) and ODD.Guild and ODD.Guild.Contracts then
                local remoteZ = {}
                if data.czk then
                    for sig in string.gmatch(data.czk, "([^|]+)") do
                        remoteZ[sig] = { killer = senderName, timestamp = time() }
                    end
                end
                local remoteC = {}
                if data.cck then
                    for sig in string.gmatch(data.cck, "([^|]+)") do
                        remoteC[sig] = { killer = senderName, timestamp = time() }
                    end
                end
                ODD.Guild.Contracts:MergeRemoteKills(data.cw, remoteZ, remoteC)
            end

            ODD:Debug("Compañero con ODD detectado: %s (v%s)", senderName, tostring(data.ver))
            RefreshAllOpenTabs()
        end

    elseif parsed.type == "REQ" then
        -- Un compañero solicitó sincronización:
        -- 1. Respondemos anunciando nuestros datos propios con micro-jitter
        Sync:BroadcastHello(math.random(1, 10) / 10)

        -- 2. Réplica de Caché Gossip: Si tenemos datos de otros miembros en nuestra base de datos,
        -- se los enviamos al compañero que acaba de pedir la sincronización
        local now = GetTime()
        if (now - lastGossipTime) > 4 then
            lastGossipTime = now
            C_Timer.After(math.random(12, 25) / 10, function()
                Sync:BroadcastGossipCache(senderName)
            end)
        end

    elseif parsed.type == "GOSSIP" then
        -- Recibido paquete con datos de compañeros de hermandad replicados por un par
        local globalDB = ODD.Database:GetGlobal()
        if globalDB and parsed.payload and parsed.payload ~= "" then
            globalDB.profiles = globalDB.profiles or {}
            local hasChanges = false

            for entry in string.gmatch(parsed.payload, "([^#]+)") do
                -- Formato: Nombre=Clase,Bajas,Puntos,UpdatedAt
                local mName, mRest = entry:match("^([^=]+)=(.*)$")
                if mName and mRest and not IsMe(mName) then
                    local mCls, mKills, mPts, mUpd = mRest:match("^([^,]+),(%d+),(%d+),(%d+)$")
                    mKills = tonumber(mKills) or 0
                    mPts = tonumber(mPts) or 0
                    mUpd = tonumber(mUpd) or 0

                    local existing = globalDB.profiles[mName]
                    -- Solo actualizar si no existe o si el registro entrante es más reciente / tiene más bajas
                    if not existing or (mKills > (existing.gnomeKills or 0)) or (mPts > (existing.achievementPoints or 0)) then
                        globalDB.profiles[mName] = existing or {}
                        local prof = globalDB.profiles[mName]
                        prof.name = mName
                        prof.className = mCls or prof.className or "WARRIOR"
                        prof.gnomeKills = math.max(prof.gnomeKills or 0, mKills)
                        prof.achievementPoints = math.max(prof.achievementPoints or 0, mPts)
                        prof.updatedAt = math.max(prof.updatedAt or 0, mUpd, time())
                        hasChanges = true
                    end
                end
            end

            if hasChanges then
                _G["ODDDB"] = globalDB
                RefreshAllOpenTabs()
                ODD:Debug("Caché de hermandad actualizada vía Gossip desde %s.", senderName)
            end
        end

    elseif parsed.type == "KILL" then
        local data = ODD.Network.Codec:Decode(parsed.codec, parsed.payload)
        if data and not ODD.Database:GetSetting("muteGuildAnnouncements") then
            Sync:DisplayKillInChat(data.k or senderName, data.kc or "WARRIOR", data.v or "Gnomo", data.vc or "MAGE", data.vl or "??", data.z or "Mundo Abierto", data.tk or 1, false)
        end
        if data and ODD.UI and ODD.UI.HistoryTab and ODD.UI.HistoryTab.OnRemoteKillReceived then
            ODD.UI.HistoryTab:OnRemoteKillReceived(data, senderName)
        end
    elseif parsed.type == "ACHIEVE" then
        local data = ODD.Network.Codec:Decode(parsed.codec, parsed.payload)
        if data and not ODD.Database:GetSetting("muteGuildAnnouncements") then
            Sync:DisplayAchievementInChat(data.p or senderName, data.pc or "WARRIOR", data.aid or "gnome_1", data.an or "Logro", data.pts or 10, data.t or time(), false)
        end
    elseif parsed.type == "SB" then
        -- Mensaje de Soundboard recibido por hermandad o grupo
        local soundId = parsed.payload
        if soundId and soundId ~= "" and ODD.Soundboard and ODD.Soundboard.PlaySound then
            ODD.Soundboard:PlaySound(soundId, senderName)
        end
    end
end

function Sync:GetOnlinePeers()
    return presenceList
end
