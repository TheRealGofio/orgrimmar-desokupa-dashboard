local addonName, addonTable = ...
local ODD = addonTable.ODD

local Forever = {}
ODD.API.Forever = Forever

-- Detección segura de valores secretos (restricciones de API de combate / UI protegida)
function Forever:IsSecret(val)
    if _G["issecretvalue"] and type(_G["issecretvalue"]) == "function" then
        local ok, isSec = pcall(_G["issecretvalue"], val)
        return (not ok) or (isSec == true)
    end
    return false
end

-- Sanitizador de cadenas (estilo GRS)
function Forever:SanitizeText(value)
    if self:IsSecret(value) or type(value) ~= "string" then
        return nil
    end
    value = value:gsub("[%c|]", ""):match("^%s*(.-)%s*$")
    if not value or value == "" then
        return nil
    end
    return value
end

-- Sanitizador de números
function Forever:SanitizeNumber(value)
    if self:IsSecret(value) then
        return nil
    end
    return tonumber(value)
end

-- Sanitizador de GUIDs seguros
function Forever:SanitizeGUID(value)
    local text = self:SanitizeText(value)
    if text and text:find("^%w") then
        return text
    end
    return nil
end

-- Devuelve el nombre completo oficial (Nombre + Apellido) de cualquier unidad en WoW Forever
function Forever:GetFullName(unitToken)
    if not unitToken then return nil end

    -- 1. Intentar GetUnitName(token) en WoW Forever devuelve el nombre completo ("Nombre Apellido")
    if type(GetUnitName) == "function" then
        local okGN, gn = pcall(GetUnitName, unitToken)
        if okGN and gn and gn ~= "" and not self:IsSecret(gn) then
            local clean = self:SanitizeText(gn)
            if clean and clean:find("%s+") then
                return clean
            end
        end
        -- También con showServerName por compatibilidad
        local okGN2, gn2 = pcall(GetUnitName, unitToken, true)
        if okGN2 and gn2 and gn2 ~= "" and not self:IsSecret(gn2) then
            local clean2 = self:SanitizeText(gn2)
            -- Limpiar posible guion de servidor: "Nombre Apellido-Realm" -> "Nombre Apellido"
            if clean2 then
                local beforeRealm = clean2:match("^([^-]+)")
                if beforeRealm and beforeRealm:find("%s+") then
                    return beforeRealm:gsub("%s+$", "")
                end
            end
        end
    end

    -- 2. Si es "player" o coincide con el jugador, consultar el Roster de Hermandad si está disponible
    if unitToken == "player" then
        local myGuid = self:SanitizeGUID(UnitGUID("player"))
        if myGuid and type(GetNumGuildMembers) == "function" and type(GetGuildRosterInfo) == "function" then
            local numTotal = GetNumGuildMembers() or 0
            for i = 1, numTotal do
                local gName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, gGuid = GetGuildRosterInfo(i)
                if gGuid and self:SanitizeGUID(gGuid) == myGuid and gName then
                    local cleanG = self:SanitizeText(gName)
                    if cleanG and cleanG:find("%s+") then
                        return cleanG
                    end
                end
            end
        end
    end

    -- 3. Intentar UnitFullName
    if type(UnitFullName) == "function" then
        local okFN, fn = pcall(UnitFullName, unitToken)
        if okFN and fn and fn ~= "" and not self:IsSecret(fn) then
            local cleanFN = self:SanitizeText(fn)
            if cleanFN and cleanFN:find("%s+") then
                return cleanFN
            end
        end
    end

    -- 4. Fallback estándar a UnitName
    local okN, n = pcall(UnitName, unitToken)
    if okN and n and n ~= "" and not self:IsSecret(n) then
        return self:SanitizeText(n)
    end

    return "Desconocido"
end

-- Obtener información básica y segura del jugador local
function Forever:GetPlayerInfo()
    local fullName = self:GetFullName("player")
    local _, realm = UnitFullName("player")
    local _, classFilename, classId = UnitClass("player")
    local raceName, raceFile, raceId = UnitRace("player")
    local guid = UnitGUID("player")
    local level = UnitLevel("player")

    local safeGuid = self:SanitizeGUID(guid)

    return {
        guid = safeGuid,
        name = fullName,
        realm = self:SanitizeText(realm) or GetRealmName(),
        className = self:SanitizeText(classFilename),
        classId = self:SanitizeNumber(classId),
        raceFile = self:SanitizeText(raceFile),
        raceId = self:SanitizeNumber(raceId),
        level = self:SanitizeNumber(level),
    }
end

-- Comprobar si el jugador está en una hermandad activa
function Forever:IsInGuild()
    return IsInGuild() == true
end

-- Normaliza nombres de personajes eliminando reino, espacios sobrantes y convirtiendo a minúsculas
function Forever:NormalizeName(name)
    if not name or name == "" then return "" end
    local clean = self:SanitizeText(name) or name
    -- Eliminar reino: "Nombre-Reino" -> "Nombre"
    clean = Ambiguate(clean, "none")
    -- Quitar espacios en los extremos y convertir a minúsculas
    clean = clean:match("^%s*(.-)%s*$"):lower()
    return clean
end

-- Comprueba de forma infalible si dos nombres se refieren al mismo personaje
function Forever:IsSamePlayer(nameA, nameB)
    if not nameA or not nameB then return false end
    local normA = self:NormalizeName(nameA)
    local normB = self:NormalizeName(nameB)
    if normA == "" or normB == "" then return false end
    if normA == normB then return true end

    -- Comparar primer nombre de pila (en caso de "Nombre Apellido" vs "Nombre")
    local firstA = normA:match("^(%S+)")
    local firstB = normB:match("^(%S+)")
    if firstA and firstB and firstA == firstB then
        return true
    end

    return false
end
