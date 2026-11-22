local addonName, addonTable = ...
local ODD = addonTable.ODD

local Sync = {}
ODD.Network.Sync = Sync

-- Historial de mensajes recientes recibidos para evitar duplicados (sender:msgId)
local seenMessages = {}
local presenceList = {} -- miembros con ODD detectados online

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

        -- Añadir estadísticas de bajas del Gnomómetro si está configurado compartir estadísticas
        if ODD.Database:GetSetting("shareStats") then
            local charDB = ODD.Database:GetChar()
            if charDB and charDB.observations and charDB.observations.gnomes then
                data.gk = charDB.observations.gnomes.kills or 0
            end
        end

        -- Añadir profesiones si está configurado compartir talleres
        if ODD.Database:GetSetting("shareTrades") then
            if ODD.Professions and ODD.Professions.Scanner then
                local mySkills = ODD.Professions.Scanner:GetLocalProfessions()
                if mySkills and #mySkills > 0 then
                    local pList = {}
                    for _, p in ipairs(mySkills) do
                        table.insert(pList, string.format("%s:%d:%d", p.name, p.level, p.maxLevel))
                    end
                    data.profs = table.concat(pList, "|")
                end
            end
        end

        local codec, encoded = ODD.Network.Codec:Encode(data)
        local msgId = ODD.Network.Protocol:GenerateMsgId()
        local line = ODD.Network.Protocol:FormatLine("HELLO", msgId, "*", codec, encoded)

        ODD.Network.Queue:Enqueue(line, "GUILD")
        ODD:Debug("Enviado anuncio de presencia HELLO.")
    end)
end

-- Solicitud de sincronización de hermandad
local lastWindowSyncTime = 0

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

    ODD:Debug("Sincronización en vivo activada al abrir la ventana.")
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

    ODD:Log("Iniciando sincronización con la hermandad...")
    lastWindowSyncTime = 0 -- Forzar sin throttle
    self:RequestGuildSync()
end

function Sync:OnMessageReceived(text, channel, sender)
    -- Limpieza de reino en el sender
    local senderName = Ambiguate(sender, "none")
    local myName = UnitName("player")
    if senderName == myName then return end -- Ignorar mensajes propios reflejados

    local parsed, err = ODD.Network.Protocol:ParseLine(text)
    if not parsed then
        ODD:Debug("Mensaje de addon descartado: %s", tostring(err))
        return
    end

    -- Deduplicación
    local dedupeKey = senderName .. ":" .. parsed.msgId
    if seenMessages[dedupeKey] then return end
    seenMessages[dedupeKey] = GetTime()

    -- Comprobación de destinatario
    if parsed.target ~= "*" and parsed.target ~= myName then
        return -- Mensaje dirigido a otro compañero
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
            if data.gk then
                presenceList[senderName].gnomeKills = tonumber(data.gk) or 0
                -- Guardar en los perfiles globales para persistencia en el Leaderboard
                local globalDB = ODD.Database:GetGlobal()
                if globalDB then
                    globalDB.profiles = globalDB.profiles or {}
                    globalDB.profiles[senderName] = globalDB.profiles[senderName] or {}
                    globalDB.profiles[senderName].name = senderName
                    globalDB.profiles[senderName].className = data.cls
                    globalDB.profiles[senderName].gnomeKills = tonumber(data.gk) or 0
                    globalDB.profiles[senderName].updatedAt = time()
                    _G["ODDDB"] = globalDB
                end
            end

            if data.profs and data.profs ~= "" then
                local globalDB = ODD.Database:GetGlobal()
                if globalDB then
                    globalDB.profiles = globalDB.profiles or {}
                    globalDB.profiles[senderName] = globalDB.profiles[senderName] or {}
                    globalDB.profiles[senderName].professions = {}
                    for item in string.gmatch(data.profs, "([^|]+)") do
                        local pName, pLvl, pMax = item:match("^([^:]+):(%d+):(%d+)$")
                        if pName then
                            table.insert(globalDB.profiles[senderName].professions, {
                                name = pName,
                                level = tonumber(pLvl) or 0,
                                maxLevel = tonumber(pMax) or 0,
                            })
                        end
                    end
                    _G["ODDDB"] = globalDB
                end
            end

            ODD:Debug("Compañero con ODD detectado: %s (v%s)", senderName, tostring(data.ver))
            
            -- Actualizar en la UI si está abierta
            if ODD.UI.HQTab and ODD.UI.HQTab.RefreshPresence then
                ODD.UI.HQTab:RefreshPresence()
            end
            if ODD.UI.GnomometerTab and ODD.UI.GnomometerTab.Refresh then
                ODD.UI.GnomometerTab:Refresh()
            end
            if ODD.UI.WorkshopsTab and ODD.UI.WorkshopsTab.Refresh then
                ODD.UI.WorkshopsTab:Refresh()
            end
        end
    elseif parsed.type == "REQ" then
        -- Un compañero abrió su ventana y solicitó actualización en vivo
        -- Respondemos anunciando nuestros datos con un micro-jitter para no colapsar el canal
        Sync:BroadcastHello(math.random(1, 10) / 10) -- 0.1 a 1.0 segundos
    end
end

function Sync:GetOnlinePeers()
    return presenceList
end
