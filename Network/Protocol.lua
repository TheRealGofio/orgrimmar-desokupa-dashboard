local addonName, addonTable = ...
local ODD = addonTable.ODD

local Protocol = {}
ODD.Network.Protocol = Protocol

Protocol.PREFIX = "ODD"
Protocol.VERSION = 1
Protocol.MAX_WIRE_BYTES = 250 -- Límite de seguridad estricto bajo los 255 bytes de Blizzard

-- Generador de identificadores opacos de mensaje
local msgCounter = 0
function Protocol:GenerateMsgId()
    msgCounter = (msgCounter + 1) % 100000
    local pInfo = ODD.API.Forever:GetPlayerInfo()
    local prefix = (pInfo.name or "ODD"):sub(1, 3)
    return string.format("%s%d%d", prefix, time() % 10000, msgCounter)
end

-- Empaqueta mensaje de línea según el cable format:
-- version|type|msgId|target|codec|payload
function Protocol:FormatLine(msgType, msgId, target, codec, payload)
    target = target or "*"
    codec = codec or "RAW"
    payload = payload or ""
    return string.format("%d|%s|%s|%s|%s|%s", Protocol.VERSION, msgType, msgId, target, codec, payload)
end

-- Parsea una línea de mensaje entrante
function Protocol:ParseLine(rawLine)
    if not rawLine or type(rawLine) ~= "string" then return nil end

    local ver, mType, mId, target, codec, payload = rawLine:match("^(%d+)|(%w+)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
    if not ver then return nil end

    ver = tonumber(ver)
    if ver ~= Protocol.VERSION then
        return nil, "INCOMPATIBLE_VERSION"
    end

    return {
        version = ver,
        type = mType,
        msgId = mId,
        target = target,
        codec = codec,
        payload = payload,
    }
end
