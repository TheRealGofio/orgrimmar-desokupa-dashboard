local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Fragments = {}
ODD.Network = ODD.Network or {}
ODD.Network.Fragments = Fragments

-- Búfer de ensamblado: [sender:msgId] = { parts = {}, totalParts = N, codec = C, receivedAt = T }
local assemblyBuffer = {}
local MAX_PAYLOAD_PER_FRAGMENT = 180 -- Deja 70 bytes holgados para cabeceras sin exceder 250 bytes de cable

-- Divide un payload extenso en fragmentos compatibles con el canal de chat
function Fragments:Fragment(msgId, target, codec, rawPayload)
    local fragments = {}
    local totalLen = #rawPayload

    if totalLen <= MAX_PAYLOAD_PER_FRAGMENT then
        -- No requiere fragmentación
        local line = ODD.Network.Protocol:FormatLine("SNAPSHOT", msgId, target, codec, string.format("1/1:%s", rawPayload))
        table.insert(fragments, line)
        return fragments
    end

    local totalParts = math.ceil(totalLen / MAX_PAYLOAD_PER_FRAGMENT)
    for part = 1, totalParts do
        local startIdx = ((part - 1) * MAX_PAYLOAD_PER_FRAGMENT) + 1
        local endIdx = math.min(totalLen, part * MAX_PAYLOAD_PER_FRAGMENT)
        local chunk = rawPayload:sub(startIdx, endIdx)

        -- Formato payload: part/totalParts:chunk
        local chunkPayload = string.format("%d/%d:%s", part, totalParts, chunk)
        local line = ODD.Network.Protocol:FormatLine("SNAPSHOT", msgId, target, codec, chunkPayload)
        table.insert(fragments, line)
    end

    return fragments
end

-- Reensambla fragmentos entrantes
function Fragments:Ingest(sender, msgId, codec, payload)
    local part, totalParts, chunk = payload:match("^(%d+)/(%d+):(.*)$")
    if not part or not totalParts or not chunk then
        return nil -- Formato incorrecto
    end

    part = tonumber(part)
    totalParts = tonumber(totalParts)
    if not part or not totalParts or part > totalParts or totalParts > 64 then
        return nil -- Fuera de rango de seguridad
    end

    if totalParts == 1 then
        return chunk, codec -- Mensaje no dividido
    end

    local key = sender .. ":" .. msgId
    if not assemblyBuffer[key] then
        assemblyBuffer[key] = {
            parts = {},
            totalParts = totalParts,
            codec = codec,
            receivedAt = GetTime(),
        }
    end

    local buf = assemblyBuffer[key]
    buf.parts[part] = chunk

    -- Comprobar si ya están todas las partes
    local count = 0
    for i = 1, totalParts do
        if buf.parts[i] then count = count + 1 end
    end

    if count == totalParts then
        -- Completado exitosamente
        local completePayload = table.concat(buf.parts, "")
        local finalCodec = buf.codec
        assemblyBuffer[key] = nil -- Limpiar buffer
        return completePayload, finalCodec
    end

    return nil -- Aún esperando más fragmentos
end

-- Limpieza periódica de fragmentos caducados (TTL 120s)
local janitorFrame = CreateFrame("Frame")
janitorFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 30 then
        self.elapsed = 0
        local now = GetTime()
        for k, buf in pairs(assemblyBuffer) do
            if (now - buf.receivedAt) > 120 then
                assemblyBuffer[k] = nil
            end
        end
    end
end)
