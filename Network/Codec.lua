local addonName, addonTable = ...
local ODD = addonTable.ODD

local Codec = {}
ODD.Network = ODD.Network or {}
ODD.Network.Codec = Codec

-- Detección de APIs nativas de codificación en WoW Forever
local hasEncodingUtil = (C_EncodingUtil ~= nil)
local hasCBOR = (hasEncodingUtil and type(C_EncodingUtil.SerializeCBOR) == "function")
local hasBase64 = (hasEncodingUtil and type(C_EncodingUtil.EncodeBase64) == "function")
local hasCompress = (type(CompressString) == "function" or (hasEncodingUtil and type(C_EncodingUtil.CompressString) == "function"))
local hasDecompress = (type(DecompressString) == "function" or (hasEncodingUtil and type(C_EncodingUtil.DecompressString) == "function"))

-- Serializador de respaldo nativo puro (clave:valor;) si CBOR nativo no está expuesto
local function SimpleSerialize(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        local tv = type(v)
        if tv == "string" then
            -- Escape de delimitadores ; y :
            local cleanStr = v:gsub(":", "~c"):gsub(";", "~s")
            table.insert(parts, string.format("%s:s:%s", tostring(k), cleanStr))
        elseif tv == "number" then
            table.insert(parts, string.format("%s:n:%s", tostring(k), tostring(v)))
        elseif tv == "boolean" then
            table.insert(parts, string.format("%s:b:%s", tostring(k), v and "1" or "0"))
        end
    end
    return table.concat(parts, ";")
end

local function SimpleDeserialize(str)
    local tbl = {}
    if not str or str == "" then return tbl end
    for item in string.gmatch(str, "([^;]+)") do
        local k, t, val = item:match("^(%w+):(%w+):(.*)$")
        if k and t and val then
            if t == "s" then
                tbl[k] = val:gsub("~s", ";"):gsub("~c", ":")
            elseif t == "n" then
                tbl[k] = tonumber(val)
            elseif t == "b" then
                tbl[k] = (val == "1")
            end
        end
    end
    return tbl
end

function Codec:Encode(tbl)
    -- Intento de CBOR nativo si está disponible
    if hasCBOR and hasBase64 then
        local ok, cbor = pcall(C_EncodingUtil.SerializeCBOR, tbl)
        if ok and cbor then
            local okB64, b64 = pcall(C_EncodingUtil.EncodeBase64, cbor)
            if okB64 and b64 then
                return "CB1", b64
            end
        end
    end

    -- Fallback nativo determinista y seguro
    return "S1", SimpleSerialize(tbl)
end

function Codec:EncodeSimple(tbl)
    return "S1", SimpleSerialize(tbl)
end

function Codec:Decode(codecType, payload)
    if not payload or payload == "" then return nil end

    if codecType == "CB1" and hasCBOR and hasBase64 then
        local okB64, raw = pcall(C_EncodingUtil.DecodeBase64, payload)
        if okB64 and raw then
            local okCB, tbl = pcall(C_EncodingUtil.DeserializeCBOR, raw)
            if okCB and type(tbl) == "table" then
                return tbl
            end
        end
        return nil
    elseif codecType == "S1" then
        return SimpleDeserialize(payload)
    end

    return nil
end
