local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local GnomometerTab = {}
ODD.UI.GnomometerTab = GnomometerTab

local killsValueLabel = nil
local lastKillLabel = nil
local scrollChild = nil
local rowFrames = {}
local currentSort = "kills" -- "kills" o "points"
local btnSortKills = nil
local btnSortPoints = nil

-- Elementos de la sección Heatmap de Zonas
local zoneBars = {}
local zoneHeader = nil

-- Colores de clase estándar WoW para el ranking
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

-- Colores y medallas de texto para el Top 5 destacado
local TOP_MEDALS = {
    [1] = "|cFFFFD700[1]|r ",
    [2] = "|cFFC0C0C0[2]|r ",
    [3] = "|cFFCD7F32[3]|r ",
    [4] = "|cFF00FFCC[4]|r ",
    [5] = "|cFF00FFCC[5]|r ",
}

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

    -- 2. Zonas declaradas sincronizadas de otros compañeros
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

function GnomometerTab:Refresh()
    if not killsValueLabel or not scrollChild then return end

    local charDB = ODD.Database:GetChar()
    local gnomes = charDB and charDB.observations and charDB.observations.gnomes
    local totalKills = gnomes and gnomes.kills or 0
    local totalPoints = 0
    if ODD.Achievements and ODD.Achievements.Medals then
        totalPoints = ODD.Achievements.Medals:GetPlayerAchievementPoints()
    end

    killsValueLabel:SetText(string.format("Tus bajas verificadas: |cFFFFD100%d|r   •   Puntos de Logro: |cFF00FFCC%d pts|r", totalKills, totalPoints))

    if gnomes and gnomes.records and #gnomes.records > 0 then
        local last = gnomes.records[#gnomes.records]
        local dateStr = date("%Y-%m-%d %H:%M", last.timestamp)
        local details = ""
        if last.victimName then
            local classCol = CLASS_COLORS[last.victimClass] or "FFFFFFFF"
            details = string.format(" - Victima: |c%s%s|r (%s, Nivel %s)", classCol, last.victimName, last.victimClass or "?", tostring(last.victimLevel or "?"))
        end
        lastKillLabel:SetText(string.format("Ultima baja: %s en %s%s", dateStr, last.zone or "Desconocida", details))
    else
        lastKillLabel:SetText("Ultima baja: Ninguna registrada")
    end

    -- ========================================================
    -- ACTUALIZAR HEATMAP DE ZONAS CALIENTES
    -- ========================================================
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

                -- Ancho máximo de la barra de progreso: 110 px
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

    -- Refrescar Leaderboard con Scroll
    if ODD.Achievements and ODD.Achievements.Rankings then
        local board = ODD.Achievements.Rankings:GetGnomeLeaderboard(currentSort)
        local rowHeight = 20

        -- Actualizar estilos de los botones de ordenación
        if btnSortKills and btnSortPoints then
            if currentSort == "kills" then
                btnSortKills:SetText("|cFFFFD100[Más Bajas]|r")
                btnSortPoints:SetText("|cFF888888Más Puntos|r")
            else
                btnSortKills:SetText("|cFF888888Más Bajas|r")
                btnSortPoints:SetText("|cFF00FFCC[Más Puntos]|r")
            end
        end

        for _, r in ipairs(rowFrames) do r:Hide() end

        local currentY = 0
        for i, entry in ipairs(board) do
            local row = rowFrames[i]
            if not row then
                row = CreateFrame("Frame", nil, scrollChild)
                row:SetSize(740, 18)

                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints(row)
                row.bg = bg

                local rRank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rRank:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.rank = rRank

                local rName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rName:SetPoint("LEFT", row, "LEFT", 50, 0)
                row.name = rName

                local rScore = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rScore:SetPoint("RIGHT", row, "RIGHT", -16, 0)
                row.score = rScore

                rowFrames[i] = row
            end

            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY)
            currentY = currentY - rowHeight

            local isTop5 = (i <= 5)
            if isTop5 then
                if i == 1 then
                    row.bg:SetColorTexture(0.4, 0.3, 0.05, 0.6)
                elseif i == 2 then
                    row.bg:SetColorTexture(0.3, 0.3, 0.35, 0.5)
                elseif i == 3 then
                    row.bg:SetColorTexture(0.35, 0.2, 0.1, 0.5)
                else
                    row.bg:SetColorTexture(0.18, 0.18, 0.22, 0.45)
                end
                row.rank:SetText(TOP_MEDALS[i] or string.format("#%d", i))
            else
                if i % 2 == 0 then
                    row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.3)
                else
                    row.bg:SetColorTexture(0.16, 0.16, 0.16, 0.3)
                end
                row.rank:SetText(string.format(" #%d", i))
            end

            local color = CLASS_COLORS[entry.className] or "FFFFFFFF"
            local tag = entry.isSelf and " |cFF00FF00(Tu - Verificado)|r" or " |cFF808080(Declarado)|r"
            row.name:SetText(string.format("|c%s%s|r%s", color, entry.name, tag))
            row.score:SetText(string.format("|cFFFFD100%d bajas|r  •  |cFF00FFCC%d pts|r", entry.kills or 0, entry.points or 0))
            row:Show()
        end

        scrollChild:SetHeight(math.max(1, #board * rowHeight))
    end
end

function GnomometerTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_GNOMOMETER"] .. " - Desokupacion de Gnomos", -12)

    -- Contador propio
    killsValueLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    killsValueLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
    killsValueLabel:SetText("Tus bajas verificadas: 0")

    lastKillLabel = ODD.UI.Components:CreateStatusLabel(frame, "Ultima baja: Ninguna registrada", -58, "FFAAAAAA")

    -- ========================================================
    -- BLOQUE: MAPA DE ZONAS CALIENTES (HEATMAP DE DESALOJOS)
    -- ========================================================
    zoneHeader = ODD.UI.Components:CreateSectionHeader(frame, "Zonas Calientes de Desalojo (Top Áreas de Operación):", -82)

    local zoneContainer = CreateFrame("Frame", nil, frame)
    zoneContainer:SetSize(760, 48)
    zoneContainer:SetPoint("TOPLEFT", zoneHeader, "BOTTOMLEFT", 0, -4)

    -- Crear 4 tarjetas de zonas calientes en fila horizontal (2 filas x 2 cols para que quepa holgado)
    for i = 1, 4 do
        local zBox = CreateFrame("Frame", nil, zoneContainer)
        zBox:SetSize(360, 20)

        local col = (i % 2 == 1) and 0 or 380
        local row = (i <= 2) and 0 or -22
        zBox:SetPoint("TOPLEFT", zoneContainer, "TOPLEFT", col, row)

        local nameFs = zBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetPoint("LEFT", zBox, "LEFT", 4, 0)
        nameFs:SetWidth(150)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText(string.format("%d. Sin datos", i))
        zBox.nameFs = nameFs

        -- Fondo de la barra de progreso
        local barBg = zBox:CreateTexture(nil, "BACKGROUND")
        barBg:SetPoint("LEFT", nameFs, "RIGHT", 6, 0)
        barBg:SetSize(110, 10)
        barBg:SetColorTexture(0.18, 0.18, 0.18, 0.8)
        zBox.barBg = barBg

        -- Relleno de la barra
        local fill = zBox:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
        fill:SetSize(0, 10)
        fill:SetColorTexture(0.85, 0.2, 0.2, 0.9)
        zBox.fill = fill

        -- Texto de porcentaje y cantidad
        local countFs = zBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        countFs:SetPoint("LEFT", barBg, "RIGHT", 8, 0)
        countFs:SetText("0 (0%)")
        zBox.countFs = countFs

        zoneBars[i] = zBox
    end

    -- ========================================================
    -- TABLA DEL LEADERBOARD CON SCROLL
    -- ========================================================
    local lbHeader = ODD.UI.Components:CreateSectionHeader(frame, "Clasificacion de Hermandad (Top 5 Destacado + General):", -144)

    -- Botones de ordenación
    local sortBox = CreateFrame("Frame", nil, frame)
    sortBox:SetSize(220, 20)
    sortBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -144)

    local sortLbl = sortBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sortLbl:SetPoint("LEFT", sortBox, "LEFT", 0, 0)
    sortLbl:SetText("Ordenar:")

    btnSortKills = CreateFrame("Button", nil, sortBox)
    btnSortKills:SetSize(75, 18)
    btnSortKills:SetPoint("LEFT", sortLbl, "RIGHT", 6, 0)
    btnSortKills:SetNormalFontObject("GameFontHighlightSmall")
    btnSortKills:SetText("|cFFFFD100[Más Bajas]|r")
    btnSortKills:SetScript("OnClick", function()
        currentSort = "kills"
        GnomometerTab:Refresh()
    end)

    btnSortPoints = CreateFrame("Button", nil, sortBox)
    btnSortPoints:SetSize(80, 18)
    btnSortPoints:SetPoint("LEFT", btnSortKills, "RIGHT", 4, 0)
    btnSortPoints:SetNormalFontObject("GameFontHighlightSmall")
    btnSortPoints:SetText("|cFF888888Más Puntos|r")
    btnSortPoints:SetScript("OnClick", function()
        currentSort = "points"
        GnomometerTab:Refresh()
    end)

    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetSize(760, 18)
    headerFrame:SetPoint("TOPLEFT", lbHeader, "BOTTOMLEFT", 0, -6)

    local colPos = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colPos:SetPoint("LEFT", headerFrame, "LEFT", 6, 0)
    colPos:SetText("Pos")

    local colName = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colName:SetPoint("LEFT", headerFrame, "LEFT", 50, 0)
    colName:SetText("Jugador / Estado")

    local colScore = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colScore:SetPoint("RIGHT", headerFrame, "RIGHT", -30, 0)
    colScore:SetText("Bajas  •  Puntos")

    local scrollFrame = CreateFrame("ScrollFrame", "ODD_GnomeLeaderboardScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(760, 195)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(scrollChild)

    frame:SetScript("OnShow", function()
        GnomometerTab:Refresh()
    end)

    GnomometerTab:Refresh()
    return frame
end
