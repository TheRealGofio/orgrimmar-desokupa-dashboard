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

    -- Refrescar Leaderboard con Scroll
    if ODD.Achievements and ODD.Achievements.Rankings then
        local board = ODD.Achievements.Rankings:GetGnomeLeaderboard(currentSort)
        local rowHeight = 22

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
                row:SetSize(740, 20)

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
    killsValueLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)
    killsValueLabel:SetText("Tus bajas verificadas: 0")

    lastKillLabel = ODD.UI.Components:CreateStatusLabel(frame, "Ultima baja: Ninguna registrada", -62, "FFAAAAAA")

    -- ========================================================
    -- TABLA DEL LEADERBOARD CON SCROLL
    -- ========================================================
    local lbHeader = ODD.UI.Components:CreateSectionHeader(frame, "Clasificacion de Hermandad (Top 5 Destacado + General):", -95)

    -- Botones de ordenación
    local sortBox = CreateFrame("Frame", nil, frame)
    sortBox:SetSize(220, 20)
    sortBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -95)

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
    scrollFrame:SetSize(760, 240)
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
