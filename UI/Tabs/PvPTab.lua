local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local PvPTab = {}
ODD.UI.PvPTab = PvPTab

local statLabels = {}
local bgSummaryLabel = nil
local recentMatchesScrollChild = nil
local matchRows = {}

function PvPTab:Refresh()
    if not bgSummaryLabel then return end

    -- 1. Estadísticas oficiales de honor
    local stats = ODD.PvP.Tracker:GetLocalStats()
    if statLabels.today then
        statLabels.today:SetText(string.format("Hoy: |cFFFFD100%d HK|r (%d Honor)", stats.todayHK, stats.todayHonor))
    end
    if statLabels.yesterday then
        statLabels.yesterday:SetText(string.format("Ayer: |cFFFFD100%d HK|r (%d Honor)", stats.yesterdayHK, stats.yesterdayHonor))
    end
    if statLabels.lifetime then
        statLabels.lifetime:SetText(string.format("Historico: |cFFFFD100%d HK|r (Rango %d)", stats.lifetimeHK, stats.rank))
    end

    -- 2. Historial de Campos de Batalla
    local charDB = ODD.Database:GetChar()
    local matches = (charDB and charDB.observations and charDB.observations.pvp and charDB.observations.pvp.matches) or {}
    local wins, losses = 0, 0
    for _, m in ipairs(matches) do
        if m.victory then
            wins = wins + 1
        else
            losses = losses + 1
        end
    end

    local total = wins + losses
    local winRate = total > 0 and math.floor((wins / total) * 100) or 0
    bgSummaryLabel:SetText(string.format("Campos de Batalla: |cFF00FF00%d Victorias|r - |cFFFF0000%d Derrotas|r (Ratio: %d%%)", wins, losses, winRate))

    -- Filas de partidas recientes
    if recentMatchesScrollChild then
        for _, r in ipairs(matchRows) do r:Hide() end

        local rowHeight = 20
        local currentY = 0
        local startIdx = math.max(1, #matches - 30)

        local count = 0
        for i = #matches, startIdx, -1 do
            count = count + 1
            local m = matches[i]
            local row = matchRows[count]
            if not row then
                row = CreateFrame("Frame", nil, recentMatchesScrollChild)
                row:SetSize(740, 18)

                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints(row)
                row.bg = bg

                local rResult = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rResult:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.result = rResult

                local rZone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rZone:SetPoint("LEFT", row, "LEFT", 100, 0)
                row.zone = rZone

                local rDate = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rDate:SetPoint("RIGHT", row, "RIGHT", -16, 0)
                row.date = rDate

                matchRows[count] = row
            end

            row:SetPoint("TOPLEFT", recentMatchesScrollChild, "TOPLEFT", 0, currentY)
            currentY = currentY - rowHeight

            if m.victory then
                row.bg:SetColorTexture(0.05, 0.25, 0.05, 0.35)
                row.result:SetText("|cFF00FF00Victoria|r")
            else
                row.bg:SetColorTexture(0.25, 0.05, 0.05, 0.35)
                row.result:SetText("|cFFFF0000Derrota|r")
            end

            row.zone:SetText(m.zone or "Campo de Batalla")
            row.date:SetText(date("%Y-%m-%d %H:%M", m.timestamp))
            row:Show()
        end

        recentMatchesScrollChild:SetHeight(math.max(1, count * rowHeight))
    end
end

function PvPTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_PVP"] .. " - Honor y Campos de Batalla", -12)

    -- Panel de Estadísticas de Honor
    local honorBox = CreateFrame("Frame", nil, frame)
    honorBox:SetSize(760, 48)
    honorBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)
    local hBg = honorBox:CreateTexture(nil, "BACKGROUND")
    hBg:SetAllPoints(honorBox)
    hBg:SetColorTexture(0.12, 0.12, 0.12, 0.5)

    statLabels.today = honorBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statLabels.today:SetPoint("LEFT", honorBox, "LEFT", 16, 0)
    statLabels.today:SetText("Hoy: Cargando...")

    statLabels.yesterday = honorBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statLabels.yesterday:SetPoint("LEFT", honorBox, "LEFT", 260, 0)
    statLabels.yesterday:SetText("Ayer: Cargando...")

    statLabels.lifetime = honorBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statLabels.lifetime:SetPoint("LEFT", honorBox, "LEFT", 500, 0)
    statLabels.lifetime:SetText("Historico: Cargando...")

    -- Resumen de Victorias / Derrotas de Campos de Batalla
    bgSummaryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bgSummaryLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -95)
    bgSummaryLabel:SetText("Campos de Batalla: 0 Victorias - 0 Derrotas")

    -- Tabla de Partidas Recientes con Scroll
    local histHeader = ODD.UI.Components:CreateSectionHeader(frame, "Historial de Encuentros Recientes:", -128)

    local scrollFrame = CreateFrame("ScrollFrame", "ODD_PvPMatchesScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(760, 275)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -155)

    recentMatchesScrollChild = CreateFrame("Frame", nil, scrollFrame)
    recentMatchesScrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(recentMatchesScrollChild)

    frame:SetScript("OnShow", function()
        PvPTab:Refresh()
    end)

    PvPTab:Refresh()
    return frame
end
