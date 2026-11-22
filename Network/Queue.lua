local addonName, addonTable = ...
local ODD = addonTable.ODD

local Queue = {}
ODD.Network.Queue = Queue

-- Token bucket conservador: capacidad 6 mensajes, recarga 1 cada segundo
local maxTokens = 6
local currentTokens = 6
local refillRate = 1 -- tokens por segundo
local lastRefill = GetTime()

local pendingQueue = {}
local tickerFrame = CreateFrame("Frame")

local function RefillTokens()
    local now = GetTime()
    local delta = now - lastRefill
    if delta >= refillRate then
        local added = math.floor(delta / refillRate)
        currentTokens = math.min(maxTokens, currentTokens + added)
        lastRefill = now
    end
end

local function ProcessQueue()
    RefillTokens()

    while #pendingQueue > 0 and currentTokens >= 1 do
        local item = table.remove(pendingQueue, 1)
        currentTokens = currentTokens - 1

        local sendFunc = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G["SendAddonMessage"]
        if sendFunc then
            local result = sendFunc(ODD.Network.Protocol.PREFIX, item.text, item.channel, item.target)
            ODD:Debug("Mensaje addon enviado (%s) -> Resultado: %s", item.text:sub(1, 30), tostring(result))
        end
    end
end

tickerFrame:SetScript("OnUpdate", function(self, elapsed)
    if #pendingQueue > 0 then
        ProcessQueue()
    end
end)

function Queue:Enqueue(text, channel, target)
    channel = channel or "GUILD"

    -- Validación estricta de tamaño en bytes
    if #text > ODD.Network.Protocol.MAX_WIRE_BYTES then
        ODD:Log("Error: Intento de enviar mensaje que excede el límite de cable (%d bytes)", #text)
        return false
    end

    table.insert(pendingQueue, {
        text = text,
        channel = channel,
        target = target,
        enqueuedAt = GetTime(),
    })

    -- Intentar procesar de inmediato si hay fichas
    ProcessQueue()
    return true
end
