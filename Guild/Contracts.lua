local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Contracts = {}
ODD.Guild = ODD.Guild or {}
ODD.Guild.Contracts = Contracts

-- Constantes de tiempo de WoW (Reinicio de servidores europeos: Miércoles a las 07:00 UTC)
local WEDNESDAY_EPOCH_OFFSET = 259200 -- 3 días en segundos desde el origen Unix (1 Ene 1970 fue jueves)
local WEEK_SECONDS = 604800          -- 7 días exactos en segundos

-- Catálogo de Misiones Territoriales (Por Zona)
local ZONE_CONTRACTS = {
    {
        id = "ZONE_HILLSBRAD",
        title = "Operación Desahucio en Trabalomas",
        zone = "Laderas de Trabalomas",
        zoneAliases = { "Laderas de Trabalomas", "Hillsbrad Foothills", "Trabalomas" },
        desc = "Demasiados tapones merodeando por Molino de Tarren y Costasur. Desalojo inmediato.",
        targetKills = 25,
    },
    {
        id = "ZONE_STV",
        title = "Limpieza en la Selva",
        zone = "Vega de Tuercespina",
        zoneAliases = { "Vega de Tuercespina", "Stranglethorn Vale", "Tuercespina" },
        desc = "Las expediciones de gnomos molestan cerca de Grom'gol. Cortadles el paso.",
        targetKills = 25,
    },
    {
        id = "ZONE_ARATHI",
        title = "Fumigación en la Cuenca",
        zone = "Tierras Altas de Arathi",
        zoneAliases = { "Tierras Altas de Arathi", "Arathi Highlands", "Arathi" },
        desc = "Ocupaciones ilegales detectadas cerca de Sentencia. Mandad una patrulla a desratizar.",
        targetKills = 20,
    },
    {
        id = "ZONE_ASHENVALE",
        title = "Tala y Desalojo",
        zone = "Valle de Fresno",
        zoneAliases = { "Valle de Fresno", "Ashenvale" },
        desc = "Gnomos saboteando los aserraderos de la Horda. Expulsión sin contemplaciones.",
        targetKills = 20,
    },
    {
        id = "ZONE_TANARIS",
        title = "Espejismo de Cobre",
        zone = "Tanaris",
        zoneAliases = { "Tanaris" },
        desc = "Gadgetzan apesta a experimentos de la Alianza. Que sientan el peso de la Horda en las arenas.",
        targetKills = 20,
    },
    {
        id = "ZONE_BARRENS",
        title = "Vigilancia en los Baldíos",
        zone = "Los Baldíos",
        zoneAliases = { "Los Baldíos", "The Barrens", "Baldíos" },
        desc = "Incursiones gnomáticas en territorio orco. Ningún gnomo pisará El Cruce.",
        targetKills = 15,
    },
    {
        id = "ZONE_SEARING_GORGE",
        title = "Desalojo en la Garganta",
        zone = "Garganta de Fuego",
        zoneAliases = { "Garganta de Fuego", "Searing Gorge" },
        desc = "Presencia gnomática en las canteras oscuras. A enfriarles las calderas.",
        targetKills = 20,
    },
}

-- Catálogo de Misiones de Especialistas (Por Clase de Gnomo)
local CLASS_CONTRACTS = {
    {
        id = "CLASS_MAGE",
        title = "Caza de Chispas",
        classFile = "MAGE",
        className = "Mago",
        desc = "Cansados de bolas de fuego y polimorfas a la altura de la rodilla. A recortarles las togas.",
        targetKills = 20,
    },
    {
        id = "CLASS_ROGUE",
        title = "Cazarratas de las Sombras",
        classFile = "ROGUE",
        className = "Pícaro",
        desc = "Gnomos en sigilo acechando por la espalda. Desenvainad hachas y responded a la emboscada.",
        targetKills = 20,
    },
    {
        id = "CLASS_WARLOCK",
        title = "Pacto Roto",
        classFile = "WARLOCK",
        className = "Brujo",
        desc = "Sus diablillos miden casi lo mismo que ellos. Desalojadlos a ambos de vuelta al Vacío.",
        targetKills = 20,
    },
    {
        id = "CLASS_WARRIOR",
        title = "Tapacubos Dentados",
        classFile = "WARRIOR",
        className = "Guerrero",
        desc = "Un gnomo en placas con escudo es un insulto al peso de los orcos. ¡Derribadlos!",
        targetKills = 15,
    },
    {
        id = "CLASS_PRIEST",
        title = "Corte de Suministros",
        classFile = "PRIEST",
        className = "Sacerdote",
        desc = "Cortarles las curas antes de que ayuden a sus aliados grandullones.",
        targetKills = 15,
    },
}

-- Devuelve el identificador de semana universal determinista (entero secuencial)
function Contracts:GetCurrentWeekID()
    local now = time()
    return math.floor((now - WEDNESDAY_EPOCH_OFFSET) / WEEK_SECONDS)
end

-- Devuelve el tiempo restante en segundos hasta el próximo reinicio de servidores
function Contracts:GetTimeRemaining()
    local now = time()
    local currentWeek = self:GetCurrentWeekID()
    local nextReset = (currentWeek + 1) * WEEK_SECONDS + WEDNESDAY_EPOCH_OFFSET
    return math.max(0, nextReset - now)
end

-- Formatea el tiempo restante en texto legible (ej: "3d 14h")
function Contracts:GetTimeRemainingString()
    local rem = self:GetTimeRemaining()
    local days = math.floor(rem / 86400)
    local hours = math.floor((rem % 86400) / 3600)
    if days > 0 then
        return string.format("%dd %02dh", days, hours)
    else
        local mins = math.floor((rem % 3600) / 60)
        return string.format("%02dh %02dm", hours, mins)
    end
end

-- Obtiene las dos definiciones de contrato correspondientes a la semana en curso
function Contracts:GetActiveContracts()
    local weekID = self:GetCurrentWeekID()

    -- 1. Contrato Territorial (Zona): Determinista según weekID
    local zoneIndex = (weekID % #ZONE_CONTRACTS) + 1
    local zoneDef = ZONE_CONTRACTS[zoneIndex]

    -- 2. Contrato de Especialista (Clase): Determinista según weekID con dispersión
    local classIndex = ((weekID * 3 + 7) % #CLASS_CONTRACTS) + 1
    local classDef = CLASS_CONTRACTS[classIndex]

    return zoneDef, classDef, weekID
end

-- Garantiza que la estructura de contratos en DB esté limpia e inicializada para la semana actual
function Contracts:EnsureStorage()
    local globalDB = ODD.Database:GetGlobal()
    if not globalDB then return nil end

    globalDB.contracts = globalDB.contracts or {}
    local currentWeek = self:GetCurrentWeekID()

    -- Si cambió la semana, archivar y reiniciar las bajas acumuladas
    if globalDB.contracts.weekID ~= currentWeek then
        globalDB.contracts.weekID = currentWeek
        globalDB.contracts.zoneKills = {}   -- [killSignature] = { killer = name, timestamp = t, victim = name }
        globalDB.contracts.classKills = {}  -- [killSignature] = { killer = name, timestamp = t, victim = name }
        _G["ODDDB"] = globalDB
    end

    return globalDB.contracts
end

-- Comprueba si una zona registrada coincide con la zona del contrato territorial
local function MatchZone(recordZone, targetZone, aliases)
    if not recordZone or not targetZone then return false end
    if recordZone == targetZone then return true end
    if aliases then
        for _, alias in ipairs(aliases) do
            if string.lower(recordZone) == string.lower(alias) or string.find(string.lower(recordZone), string.lower(alias), 1, true) then
                return true
            end
        end
    end
    return false
end

-- Procesa una baja mortal recién registrada por el jugador local
function Contracts:OnLocalKill(killRecord)
    if not killRecord or not killRecord.guid then return end

    local store = self:EnsureStorage()
    if not store then return end

    local zoneDef, classDef, weekID = self:GetActiveContracts()
    local playerName = UnitName("player") or "Tú"
    local now = killRecord.timestamp or time()
    local killSig = string.format("%s_%s_%d", tostring(killRecord.guid), playerName, now)

    local updated = false

    -- 1. Comprobar Contrato de Zona
    if zoneDef and MatchZone(killRecord.zone, zoneDef.zone, zoneDef.zoneAliases) then
        if not store.zoneKills[killSig] then
            store.zoneKills[killSig] = {
                killer = playerName,
                victim = killRecord.name or "Gnomo",
                timestamp = now,
                zone = killRecord.zone,
            }
            updated = true
            ODD:Log("|cFF00FF00[CONTRATO]|r ¡Baja de desalojo aportada para '%s'!", zoneDef.title)
        end
    end

    -- 2. Comprobar Contrato de Clase
    if classDef and killRecord.classFile == classDef.classFile then
        if not store.classKills[killSig] then
            store.classKills[killSig] = {
                killer = playerName,
                victim = killRecord.name or "Gnomo",
                timestamp = now,
                class = killRecord.classFile,
            }
            updated = true
            ODD:Log("|cFF00FF00[CONTRATO]|r ¡Baja de especialista aportada para '%s'!", classDef.title)
        end
    end

    if updated then
        local gDB = ODD.Database:GetGlobal()
        if gDB then _G["ODDDB"] = gDB end

        -- Sincronizar actualización inmediatamente con la hermandad si estamos conectados
        if ODD.Network and ODD.Network.Sync and ODD.Network.Sync.BroadcastHello then
            ODD.Network.Sync:BroadcastHello(1)
        end
    end
end

-- Retorna el progreso actual de ambos contratos { count, target, percent, isComplete, title, desc }
function Contracts:GetProgress()
    local store = self:EnsureStorage()
    local zoneDef, classDef = self:GetActiveContracts()

    local zoneCount = 0
    if store and store.zoneKills then
        for _ in pairs(store.zoneKills) do
            zoneCount = zoneCount + 1
        end
    end

    local classCount = 0
    if store and store.classKills then
        for _ in pairs(store.classKills) do
            classCount = classCount + 1
        end
    end

    local zTarget = (zoneDef and zoneDef.targetKills) or 20
    local cTarget = (classDef and classDef.targetKills) or 20

    return {
        zone = {
            id = zoneDef.id,
            title = zoneDef.title,
            zone = zoneDef.zone,
            desc = zoneDef.desc,
            current = zoneCount,
            target = zTarget,
            percent = math.min(100, math.floor((zoneCount / zTarget) * 100)),
            isComplete = zoneCount >= zTarget,
        },
        class = {
            id = classDef.id,
            title = classDef.title,
            classFile = classDef.classFile,
            className = classDef.className,
            desc = classDef.desc,
            current = classCount,
            target = cTarget,
            percent = math.min(100, math.floor((classCount / cTarget) * 100)),
            isComplete = classCount >= cTarget,
        },
        timeRemaining = self:GetTimeRemainingString(),
    }
end

-- Fusiona bajas remotas recibidas por P2P (algoritmo Set Union sin duplicados)
function Contracts:MergeRemoteKills(remoteWeekID, remoteZoneKills, remoteClassKills)
    local currentWeek = self:GetCurrentWeekID()
    if tonumber(remoteWeekID) ~= currentWeek then
        -- Descartar si el paquete viene de otra semana
        return false
    end

    local store = self:EnsureStorage()
    if not store then return false end

    local newKills = 0

    if type(remoteZoneKills) == "table" then
        for sig, data in pairs(remoteZoneKills) do
            if not store.zoneKills[sig] then
                store.zoneKills[sig] = data
                newKills = newKills + 1
            end
        end
    end

    if type(remoteClassKills) == "table" then
        for sig, data in pairs(remoteClassKills) do
            if not store.classKills[sig] then
                store.classKills[sig] = data
                newKills = newKills + 1
            end
        end
    end

    if newKills > 0 then
        local gDB = ODD.Database:GetGlobal()
        if gDB then _G["ODDDB"] = gDB end
        ODD:Debug(string.format("Sincronizadas %d nuevas bajas de contratos de hermandad.", newKills))
        return true
    end

    return false
end
