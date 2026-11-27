local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local PvPTab = {}
ODD.UI.PvPTab = PvPTab

local statLabels = {}
local bgSummaryLabel = nil
local nemesisScrollChild = nil
local nemesisRows = {}
local currentNemesisFilter = "wanted" -- "wanted", "avenged", "all"
local filterButtons = {}
local countLabel = nil

-- Colores de clase estándar
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

function PvPTab:Refresh()
    if not bgSummaryLabel then return end

    -- 1. Estadísticas oficiales de honor
    local stats = ODD.PvP.Tracker:GetLocalStats()
    if statLabels.today then
        if stats.todayHonor > 0 then
            statLabels.today:SetText(string.format("Hoy: |cFFFFD100%d HK|r (%d Honor)", stats.todayHK, stats.todayHonor))
        else
            statLabels.today:SetText(string.format("Hoy: |cFFFFD100%d HK|r", stats.todayHK))
        end
    end
    if statLabels.yesterday then
        if stats.yesterdayHonor > 0 then
            statLabels.yesterday:SetText(string.format("Ayer: |cFFFFD100%d HK|r (%d Honor)", stats.yesterdayHK, stats.yesterdayHonor))
        else
            statLabels.yesterday:SetText(string.format("Ayer: |cFFFFD100%d HK|r", stats.yesterdayHK))
        end
    end
    if statLabels.lifetime then
        local rankStr = (stats.rank and stats.rank > 0) and string.format("Rango %d (%s)", stats.rank, stats.rankName or "") or (stats.rankName or "Civil")
        statLabels.lifetime:SetText(string.format("Histórico: |cFFFFD100%d HK|r |cFF888888[%s]|r", stats.lifetimeHK, rankStr))
    end

    -- 2. Resumen de Campos de Batalla
    local charDB = ODD.Database:GetChar()
    local matches = (charDB and charDB.observations and charDB.observations.pvp and charDB.observations.pvp.matches) or {}
    local wins, losses = 0, 0
    for _, m in ipairs(matches) do
        if m.victory then wins = wins + 1 else losses = losses + 1 end
    end
    local total = wins + losses
    local winRate = total > 0 and math.floor((wins / total) * 100) or 0
    bgSummaryLabel:SetText(string.format("Campos de Batalla: |cFF00FF00%d Victorias|r - |cFFFF0000%d Derrotas|r (Ratio: %d%%)", wins, losses, winRate))

    -- 3. Estilos de botones de filtro
    for key, btn in pairs(filterButtons) do
        if key == currentNemesisFilter then
            btn:SetText(string.format("|cFFFFD100[%s]|r", btn.rawText))
        else
            btn:SetText(string.format("|cFF888888%s|r", btn.rawText))
        end
    end

    -- 4. Tabla de Némesis / Objetivos Prioritarios de Desahucio
    if nemesisScrollChild then
        for _, r in ipairs(nemesisRows) do r:Hide() end

        local nemList = ODD.PvP.Tracker:GetNemesisList(currentNemesisFilter)
        local allNemList = ODD.PvP.Tracker:GetNemesisList("all")
        local rowHeight = 26
        local currentY = 0

        if countLabel then
            countLabel:SetText(string.format("Rivales: |cFFFFD100%d|r (Mostrando: |cFF00FFCC%d|r)", #allNemList, #nemList))
        end

        for i, nem in ipairs(nemList) do
            local row = nemesisRows[i]
            if not row then
                row = CreateFrame("Frame", nil, nemesisScrollChild)
                row:SetSize(760, 24)

                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints(row)
                row.bg = bg

                -- Estado: [BUSCADO] o [VENGADO]
                local rStatus = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rStatus:SetPoint("LEFT", row, "LEFT", 8, 0)
                row.status = rStatus

                -- Nombre y Raza
                local rName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rName:SetPoint("LEFT", row, "LEFT", 110, 0)
                row.name = rName

                -- Marcador (Te ha matado X veces - Lo has matado Y veces)
                local rScore = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rScore:SetPoint("LEFT", row, "LEFT", 330, 0)
                row.score = rScore

                -- Último avistamiento (Zona y Fecha)
                local rZone = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                rZone:SetPoint("RIGHT", row, "RIGHT", -46, 0)
                row.zone = rZone

                -- Botón pequeño de descartar / eliminar entrada con [X] en texto limpio ASCII
                local delBtn = CreateFrame("Button", nil, row)
                delBtn:SetSize(22, 18)
                delBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                delBtn:SetNormalFontObject("GameFontDisableSmall")
                delBtn:SetText("|cFFFF4444[X]|r")
                delBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Descartar de la lista de Némesis")
                    GameTooltip:Show()
                end)
                delBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row.delBtn = delBtn

                nemesisRows[i] = row
            end

            row:SetPoint("TOPLEFT", nemesisScrollChild, "TOPLEFT", 0, currentY)
            currentY = currentY - rowHeight

            if i % 2 == 0 then
                row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.4)
            else
                row.bg:SetColorTexture(0.16, 0.16, 0.16, 0.4)
            end

            local isWanted = (nem.status == "WANTED")
            if isWanted then
                row.status:SetText("|cFFFF0000[BUSCADO]|r")
            else
                row.status:SetText("|cFF00FF00[VENGADO]|r")
            end

            local cColor = CLASS_COLORS[nem.class] or "FFFFFFFF"
            local raceStr = nem.race and string.format(" (%s)", nem.race) or ""
            row.name:SetText(string.format("|c%s%s|r%s", cColor, nem.name or "Desconocido", raceStr))

            local deaths = nem.deathsTo or 0
            local kills = nem.killsOn or 0
            row.score:SetText(string.format("Te ha matado: |cFFFF2020%d|r  •  Lo has matado: |cFF00FF00%d|r", deaths, kills))

            local dateStr = nem.lastEncounter and date("%Y-%m-%d", nem.lastEncounter) or ""
            row.zone:SetText(string.format("%s (%s)", nem.zone or "Mundo Abierto", dateStr))

            -- Configurar acción del botón descartar
            local targetGuid = nem.guid
            row.delBtn:SetScript("OnClick", function()
                if targetGuid and ODD.PvP and ODD.PvP.Tracker then
                    ODD.PvP.Tracker:RemoveNemesis(targetGuid)
                end
            end)

            row:Show()
        end

        nemesisScrollChild:SetHeight(math.max(1, #nemList * rowHeight))
    end
end

function PvPTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_PVP"] .. " - Honor y Objetivos Prioritarios", -12)

    -- Panel de Estadísticas de Honor con borde de tema y florituras
    local honorBox = ODD.UI.Components:CreateSectionBox(frame, 760, 42, true, 0.45)
    honorBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)

    statLabels.today = honorBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statLabels.today:SetPoint("LEFT", honorBox, "LEFT", 16, 0)
    statLabels.today:SetText("Hoy: Cargando...")

    statLabels.yesterday = honorBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statLabels.yesterday:SetPoint("LEFT", honorBox, "LEFT", 260, 0)
    statLabels.yesterday:SetText("Ayer: Cargando...")

    statLabels.lifetime = honorBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statLabels.lifetime:SetPoint("LEFT", honorBox, "LEFT", 500, 0)
    statLabels.lifetime:SetText("Histórico: Cargando...")

    -- Resumen de Victorias / Derrotas de Campos de Batalla
    bgSummaryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgSummaryLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -88)
    bgSummaryLabel:SetText("Campos de Batalla: 0 Victorias - 0 Derrotas")

    countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -88)
    countLabel:SetText("")

    -- ========================================================
    -- LISTA DE NÉMESIS / OBJETIVOS PRIORITARIOS DE DESAHUCIO
    -- ========================================================
    local nemHeader = ODD.UI.Components:CreateSectionHeader(frame, "Lista de Némesis:", -118)

    -- Botones de Filtrado y Limpieza de Némesis
    local filterBox = CreateFrame("Frame", nil, frame)
    filterBox:SetSize(460, 20)
    filterBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -118)

    local fLbl = filterBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fLbl:SetPoint("LEFT", filterBox, "LEFT", 0, 0)
    fLbl:SetText("Ver:")

    local function MakeFilterBtn(key, labelText, xOffset, width)
        local btn = CreateFrame("Button", nil, filterBox)
        btn:SetSize(width, 18)
        btn:SetPoint("LEFT", fLbl, "RIGHT", xOffset, 0)
        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn.rawText = labelText
        btn:SetText(string.format("|cFF888888%s|r", labelText))
        btn:SetScript("OnClick", function()
            currentNemesisFilter = key
            PvPTab:Refresh()
        end)
        filterButtons[key] = btn
        return btn
    end

    MakeFilterBtn("wanted", "Buscados", 6, 68)
    MakeFilterBtn("avenged", "Vengados", 78, 68)
    MakeFilterBtn("all", "Todos", 150, 50)

    -- Botón para limpiar vengados
    local clearAvengedBtn = CreateFrame("Button", nil, filterBox)
    clearAvengedBtn:SetSize(100, 18)
    clearAvengedBtn:SetPoint("LEFT", fLbl, "RIGHT", 204, 0)
    clearAvengedBtn:SetNormalFontObject("GameFontDisableSmall")
    clearAvengedBtn:SetText("|cFF888888[Limpiar Vengados]|r")
    clearAvengedBtn:SetScript("OnClick", function()
        if ODD.PvP and ODD.PvP.Tracker then
            ODD.PvP.Tracker:ClearAvengedNemesis()
        end
    end)

    -- Botón para limpiar TODO Némesis
    local clearAllBtn = CreateFrame("Button", nil, filterBox)
    clearAllBtn:SetSize(90, 18)
    clearAllBtn:SetPoint("LEFT", clearAvengedBtn, "RIGHT", 6, 0)
    clearAllBtn:SetNormalFontObject("GameFontDisableSmall")
    clearAllBtn:SetText("|cFFFF4444[Limpiar Todo]|r")
    clearAllBtn:SetScript("OnClick", function()
        if ODD.PvP and ODD.PvP.Tracker then
            ODD.PvP.Tracker:ClearAllNemesis()
        end
    end)

    -- Marco contenedor con borde para toda la lista de Némesis
    local nemContainer = ODD.UI.Components:CreateSectionBox(frame, 760, 274, true, 0.40)
    nemContainer:SetPoint("TOPLEFT", nemHeader, "BOTTOMLEFT", 0, -4)

    local headerFrame = CreateFrame("Frame", nil, nemContainer)
    headerFrame:SetSize(750, 18)
    headerFrame:SetPoint("TOPLEFT", nemContainer, "TOPLEFT", 6, -6)

    local colStat = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colStat:SetPoint("LEFT", headerFrame, "LEFT", 8, 0)
    colStat:SetText("Estado")

    local colEnemy = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colEnemy:SetPoint("LEFT", headerFrame, "LEFT", 110, 0)
    colEnemy:SetText("Némesis / Raza")

    local colScore = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colScore:SetPoint("LEFT", headerFrame, "LEFT", 330, 0)
    colScore:SetText("Marcador Personal")

    local colLoc = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colLoc:SetPoint("RIGHT", headerFrame, "RIGHT", -46, 0)
    colLoc:SetText("Último Encuentro")

    -- Tabla de Némesis con Scroll dentro del contenedor estilizado
    local scrollFrame = CreateFrame("ScrollFrame", "ODD_NemesisScrollFrame", nemContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(746, 242)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)

    nemesisScrollChild = CreateFrame("Frame", nil, scrollFrame)
    nemesisScrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(nemesisScrollChild)

    frame:SetScript("OnShow", function()
        PvPTab:Refresh()
    end)

    PvPTab:Refresh()
    return frame
end
