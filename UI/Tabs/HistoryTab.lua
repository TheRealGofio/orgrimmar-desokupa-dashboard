local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local HistoryTab = {}
ODD.UI.HistoryTab = HistoryTab

-- Elementos de la UI
local scrollChild = nil
local rowFrames = {}
local zoneBars = {}
local totalKillsLabel = nil
local filterButtons = {}
local currentFilter = "all" -- "all", "self", "guild"

-- Colores de clase estándar WoW
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

-- Búfer en memoria de desahucios remotos recibidos por P2P durante la sesión
local remoteKillsCache = {}

function HistoryTab:OnRemoteKillReceived(data, senderName)
    if not data then return end
    local kName = data.k or senderName or "Compañero"
    local entry = {
        killerName = kName,
        killerClass = data.kc or "WARRIOR",
        victimName = data.v or "Gnomo",
        victimClass = data.vc or "MAGE",
        victimLevel = data.vl or "??",
        zone = data.z or "Mundo Abierto",
        totalKills = data.tk or 1,
        timestamp = time(),
        isSelf = false,
    }
    table.insert(remoteKillsCache, 1, entry) -- Insertar al principio

    -- Mantener un máximo de 100 registros en sesión
    if #remoteKillsCache > 100 then
        table.remove(remoteKillsCache)
    end

    if HistoryTab.Refresh then
        HistoryTab:Refresh()
    end
end

-- Calcula las zonas más calientes de desalojo sumando registros propios y de hermandad
local function CalculateTopZones()
    local zoneTotals = {}
    local totalKillsRecorded = 0

    -- 1. Bajas propias con zona verificada
    local charDB = ODD.Database:GetChar()
    local gnomes = charDB and charDB.observations and charDB.observations.gnomes
    local records = (gnomes and gnomes.records) or {}
    for _, r in ipairs(records) do
        local z = r.zone or "Desconocida"
        zoneTotals[z] = (zoneTotals[z] or 0) + 1
        totalKillsRecorded = totalKillsRecorded + 1
    end

    -- 2. Bajas remotas en búfer de sesión
    for _, r in ipairs(remoteKillsCache) do
        local z = r.zone or "Desconocida"
        zoneTotals[z] = (zoneTotals[z] or 0) + 1
        totalKillsRecorded = totalKillsRecorded + 1
    end

    -- 3. Zonas declaradas sincronizadas de otros compañeros en perfiles globales
    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.profiles then
        for _, profile in pairs(globalDB.profiles) do
            if profile.topZones and type(profile.topZones) == "string" then
                -- Formato "Zona1:12;Zona2:5"
                for entry in profile.topZones:gmatch("[^;]+") do
                    local zName, zCount = entry:match("^([^:]+):(%d+)$")
                    if zName and zCount then
                        local c = tonumber(zCount) or 0
                        zoneTotals[zName] = (zoneTotals[zName] or 0) + c
                        totalKillsRecorded = totalKillsRecorded + c
                    end
                end
            end
        end
    end

    local list = {}
    for zName, count in pairs(zoneTotals) do
        table.insert(list, { name = zName, count = count })
    end
    table.sort(list, function(a, b) return a.count > b.count end)

    return list, totalKillsRecorded
end

-- Recopila y ordena la lista de bajas para el historial
local function GetEvictionsList()
    local evictions = {}

    -- 1. Bajas locales verificadas
    local charDB = ODD.Database:GetChar()
    local myName = (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "Tú"
    local _, myClass = UnitClass("player")
    local gnomes = charDB and charDB.observations and charDB.observations.gnomes
    local records = (gnomes and gnomes.records) or {}

    for _, r in ipairs(records) do
        table.insert(evictions, {
            killerName = myName,
            killerClass = myClass or "WARRIOR",
            victimName = r.victimName or "Gnomo",
            victimClass = r.victimClass or "WARRIOR",
            victimLevel = r.victimLevel or "??",
            zone = r.zone or "Desconocida",
            wasEating = r.wasEating,
            wasMounted = r.wasMounted,
            inGuildGroup = r.inGuildGroup,
            timestamp = r.timestamp or 0,
            isSelf = true,
        })
    end

    -- 2. Bajas remotas recibidas por P2P
    for _, r in ipairs(remoteKillsCache) do
        table.insert(evictions, r)
    end

    -- Ordenar cronológicamente descendente (lo más nuevo arriba)
    table.sort(evictions, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)

    return evictions
end

function HistoryTab:Refresh()
    if not scrollChild then return end

    -- 1. Actualizar Zonas Calientes (Heatmap de Desalojos)
    local topZones, totalTracked = CalculateTopZones()
    local barColors = {
        { 0.85, 0.15, 0.15 }, -- Puesto 1: Rojo fuego Horda
        { 0.95, 0.45, 0.10 }, -- Puesto 2: Naranja fuego
        { 0.90, 0.75, 0.10 }, -- Puesto 3: Oro
        { 0.50, 0.40, 0.25 }, -- Puesto 4+: Bronce oscuro
    }

    for idx = 1, 4 do
        local bar = zoneBars[idx]
        if bar then
            local item = topZones[idx]
            if item and totalTracked > 0 then
                local pct = math.floor((item.count / totalTracked) * 100 + 0.5)
                local col = barColors[idx] or barColors[4]
                bar.fill:SetColorTexture(col[1], col[2], col[3], 0.85)

                local barW = math.max(4, math.min(110, math.floor((pct / 100) * 110)))
                bar.fill:SetWidth(barW)

                bar.nameFs:SetText(string.format("|cFFFFD100%d.|r %s", idx, item.name))
                bar.countFs:SetText(string.format("|cFFFFFFFF%d|r (|cFF00FF00%d%%|r)", item.count, pct))
                bar:Show()
            else
                bar:Hide()
            end
        end
    end

    -- 2. Actualizar estilos de los botones de filtro
    for key, btn in pairs(filterButtons) do
        if key == currentFilter then
            btn:SetText(string.format("|cFFFFD100[%s]|r", btn.rawText))
        else
            btn:SetText(string.format("|cFF888888%s|r", btn.rawText))
        end
    end

    -- 3. Filtrar y renderizar lista de desahucios (limitado a los 50 más recientes para máxima claridad)
    local allEvictions = GetEvictionsList()
    local filtered = {}
    local MAX_DISPLAY_EVICTIONS = 50

    for _, ev in ipairs(allEvictions) do
        if #filtered >= MAX_DISPLAY_EVICTIONS then break end
        if currentFilter == "all" then
            table.insert(filtered, ev)
        elseif currentFilter == "self" and ev.isSelf then
            table.insert(filtered, ev)
        elseif currentFilter == "guild" and not ev.isSelf then
            table.insert(filtered, ev)
        end
    end

    if totalKillsLabel then
        totalKillsLabel:SetText(string.format("Total desahucios registrados: |cFFFFD100%d|r (Mostrando últimos: |cFF00FFCC%d|r)", #allEvictions, #filtered))
    end

    for _, r in ipairs(rowFrames) do r:Hide() end

    local rowHeight = 22
    local currentY = 0

    for i, ev in ipairs(filtered) do
        local row = rowFrames[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetSize(740, 20)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            row.bg = bg

            -- Fecha / Hora
            local rTime = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            rTime:SetPoint("LEFT", row, "LEFT", 6, 0)
            rTime:SetWidth(110)
            rTime:SetJustifyH("LEFT")
            row.timeFs = rTime

            -- Ejecutor (Desokupa)
            local rKiller = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rKiller:SetPoint("LEFT", rTime, "RIGHT", 8, 0)
            rKiller:SetWidth(160)
            rKiller:SetJustifyH("LEFT")
            row.killerFs = rKiller

            -- Víctima (Gnomo + Nivel + Clase)
            local rVictim = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rVictim:SetPoint("LEFT", rKiller, "RIGHT", 8, 0)
            rVictim:SetWidth(180)
            rVictim:SetJustifyH("LEFT")
            row.victimFs = rVictim

            -- Zona
            local rZone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rZone:SetPoint("LEFT", rVictim, "RIGHT", 8, 0)
            rZone:SetWidth(150)
            rZone:SetJustifyH("LEFT")
            row.zoneFs = rZone

            -- Etiquetas / Modificadores (Comiendo, Montura, Grupo)
            local rTags = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rTags:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            rTags:SetJustifyH("RIGHT")
            row.tagsFs = rTags

            rowFrames[i] = row
        end

        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY)
        currentY = currentY - rowHeight

        -- Alternar color de fondo de fila
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.12, 0.12, 0.14, 0.35)
        else
            row.bg:SetColorTexture(0.16, 0.16, 0.18, 0.35)
        end

        -- Fecha
        local dateStr = ev.timestamp and ev.timestamp > 0 and date("%d/%m %H:%M", ev.timestamp) or "Reciente"
        row.timeFs:SetText(dateStr)

        -- Ejecutor
        local kCol = CLASS_COLORS[ev.killerClass] or "FFFFFFFF"
        local kTag = ev.isSelf and " |cFF00FF00(Tú)|r" or ""
        row.killerFs:SetText(string.format("|c%s%s|r%s", kCol, ev.killerName or "Desconocido", kTag))

        -- Víctima
        local vCol = CLASS_COLORS[ev.victimClass] or "FFFFFFFF"
        row.victimFs:SetText(string.format("|c%s%s|r (Nv %s %s)", vCol, ev.victimName or "Gnomo", tostring(ev.victimLevel or "??"), ev.victimClass or ""))

        -- Zona
        row.zoneFs:SetText(string.format("|cFFFFD100%s|r", ev.zone or "Mundo Abierto"))

        -- Modificadores especiales
        local tagList = {}
        if ev.wasEating then table.insert(tagList, "|cFFFF8000[Comiendo]|r") end
        if ev.wasMounted then table.insert(tagList, "|cFF00FFCC[Montura]|r") end
        if ev.inGuildGroup then table.insert(tagList, "|cFF00FF00[Grupo Guild]|r") end
        if #tagList == 0 then
            row.tagsFs:SetText(ev.isSelf and "|cFF00FF00Verificado|r" or "|cFF888888Declarado|r")
        else
            row.tagsFs:SetText(table.concat(tagList, " "))
        end

        row:Show()
    end

    scrollChild:SetHeight(math.max(1, #filtered * rowHeight))
end

function HistoryTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_HISTORY"] .. " - Registro de Bajas y Zonas Calientes", -12)

    totalKillsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalKillsLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    totalKillsLabel:SetText("Total desahucios registrados: 0")

    -- ========================================================
    -- BLOQUE 1: MAPA DE ZONAS CALIENTES (HEATMAP DE OPERACIÓN)
    -- ========================================================
    local zoneHeader = ODD.UI.Components:CreateSectionHeader(frame, "Zonas Calientes de Desalojo (Top Áreas de Operación):", -54)

    local zoneContainer = ODD.UI.Components:CreateSectionBox(frame, 760, 52, true, 0.45)
    zoneContainer:SetPoint("TOPLEFT", zoneHeader, "BOTTOMLEFT", 0, -4)

    for i = 1, 4 do
        local zBox = CreateFrame("Frame", nil, zoneContainer)
        zBox:SetSize(360, 20)

        local col = (i % 2 == 1) and 8 or 388
        local row = (i <= 2) and -5 or -27
        zBox:SetPoint("TOPLEFT", zoneContainer, "TOPLEFT", col, row)

        local nameFs = zBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetPoint("LEFT", zBox, "LEFT", 4, 0)
        nameFs:SetWidth(150)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText(string.format("%d. Sin datos", i))
        zBox.nameFs = nameFs

        local barBg = zBox:CreateTexture(nil, "BACKGROUND")
        barBg:SetPoint("LEFT", nameFs, "RIGHT", 6, 0)
        barBg:SetSize(110, 10)
        barBg:SetColorTexture(0.18, 0.18, 0.18, 0.8)
        zBox.barBg = barBg

        local fill = zBox:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
        fill:SetSize(0, 10)
        fill:SetColorTexture(0.85, 0.2, 0.2, 0.9)
        zBox.fill = fill

        local countFs = zBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        countFs:SetPoint("LEFT", barBg, "RIGHT", 8, 0)
        countFs:SetText("0 (0%)")
        zBox.countFs = countFs

        zoneBars[i] = zBox
    end

    -- ========================================================
    -- BLOQUE 2: HISTORIAL CRONOLÓGICO DE DESAHUCIOS
    -- ========================================================
    local histHeader = ODD.UI.Components:CreateSectionHeader(frame, "Historial de Desahucios Ejecutados:", -122)

    -- Botones de filtrado
    local filterBox = CreateFrame("Frame", nil, frame)
    filterBox:SetSize(280, 20)
    filterBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -122)

    local fLbl = filterBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fLbl:SetPoint("LEFT", filterBox, "LEFT", 0, 0)
    fLbl:SetText("Filtrar:")

    local function MakeFilterBtn(key, labelText, xOffset, width)
        local btn = CreateFrame("Button", nil, filterBox)
        btn:SetSize(width, 18)
        btn:SetPoint("LEFT", fLbl, "RIGHT", xOffset, 0)
        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn.rawText = labelText
        btn:SetText(string.format("|cFF888888%s|r", labelText))
        btn:SetScript("OnClick", function()
            currentFilter = key
            HistoryTab:Refresh()
        end)
        filterButtons[key] = btn
        return btn
    end

    MakeFilterBtn("all", "Todos", 6, 55)
    MakeFilterBtn("self", "Mis Bajas", 65, 65)
    MakeFilterBtn("guild", "Hermandad", 134, 75)

    -- Marco contenedor con borde para toda la tabla de historial
    local histContainer = ODD.UI.Components:CreateSectionBox(frame, 760, 248, true, 0.40)
    histContainer:SetPoint("TOPLEFT", histHeader, "BOTTOMLEFT", 0, -4)

    -- Cabecera de la tabla
    local headerFrame = CreateFrame("Frame", nil, histContainer)
    headerFrame:SetSize(750, 18)
    headerFrame:SetPoint("TOPLEFT", histContainer, "TOPLEFT", 6, -6)

    local colTime = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colTime:SetPoint("LEFT", headerFrame, "LEFT", 6, 0)
    colTime:SetText("Fecha/Hora")

    local colKiller = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colKiller:SetPoint("LEFT", headerFrame, "LEFT", 124, 0)
    colKiller:SetText("Ejecutor")

    local colVictim = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colVictim:SetPoint("LEFT", headerFrame, "LEFT", 292, 0)
    colVictim:SetText("Gnomo Desahuciado")

    local colZone = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colZone:SetPoint("LEFT", headerFrame, "LEFT", 480, 0)
    colZone:SetText("Zona")

    local colTags = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colTags:SetPoint("RIGHT", headerFrame, "RIGHT", -30, 0)
    colTags:SetText("Estado / Modificador")

    -- ScrollFrame de la tabla dentro del contenedor estilizado
    local scrollFrame = CreateFrame("ScrollFrame", "ODD_HistoryScrollFrame", histContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(746, 216)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(scrollChild)

    frame:SetScript("OnShow", function()
        HistoryTab:Refresh()
    end)

    HistoryTab:Refresh()
    return frame
end
