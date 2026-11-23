local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local PvPTab = {}
ODD.UI.PvPTab = PvPTab

local statLabels = {}
local bgSummaryLabel = nil
local nemesisScrollChild = nil
local nemesisRows = {}

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

    -- 3. Tabla de Némesis / Objetivos Prioritarios de Desahucio
    if nemesisScrollChild then
        for _, r in ipairs(nemesisRows) do r:Hide() end

        local nemList = ODD.PvP.Tracker:GetNemesisList()
        local rowHeight = 26
        local currentY = 0

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
                rZone:SetPoint("RIGHT", row, "RIGHT", -16, 0)
                row.zone = rZone

                -- Soporte para Shift + Clic (Compartir ficha de Némesis en chat)
                row:EnableMouse(true)
                row:SetScript("OnEnter", function(self)
                    self.bg:SetColorTexture(0.35, 0.25, 0.05, 0.5)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if self.nemData then
                        local n = self.nemData
                        local statusTxt = (n.status == "WANTED") and "|cFFFF0000[OBJETIVO BUSCADO]|r" or "|cFF00FF00[VENGADO]|r"
                        GameTooltip:AddLine(string.format("Némesis: %s", n.name or "Desconocido"), 1, 0.82, 0)
                        GameTooltip:AddLine(statusTxt)
                        GameTooltip:AddLine(string.format("Veces que te abatió: %d", n.deathsTo or 0), 1, 0.2, 0.2)
                        GameTooltip:AddLine(string.format("Veces que lo abatiste: %d", n.killsOn or 0), 0.2, 1, 0.2)
                        GameTooltip:AddLine(string.format("Última zona: %s", n.zone or "Mundo Abierto"), 0.8, 0.8, 0.8)
                        GameTooltip:AddLine("Shift + Clic: Compartir en chat", 0.6, 0.6, 0.6)
                    end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function(self)
                    if self.nemData then
                        if self.nemData.status == "WANTED" then
                            self.bg:SetColorTexture(0.35, 0.05, 0.05, 0.45)
                        else
                            self.bg:SetColorTexture(0.05, 0.22, 0.05, 0.35)
                        end
                    end
                    GameTooltip:Hide()
                end)
                row:SetScript("OnMouseUp", function(self, button)
                    if IsShiftKeyDown() and self.nemData then
                        local n = self.nemData
                        local status = (n.status == "WANTED") and "BUSCADO" or "VENGADO"
                        local shareText = string.format("[ODD] Némesis [%s]: %s (%s) - Balance: %d abatido / %d muertes en %s",
                            status, n.name or "Enemigo", n.class or "?", n.killsOn or 0, n.deathsTo or 0, n.zone or "Mundo Abierto")
                        if type(ChatEdit_InsertLink) == "function" then
                            if not ChatEdit_InsertLink(shareText) then
                                local editBox = ChatEdit_ChooseBoxForSend()
                                if editBox then
                                    ChatEdit_ActivateChat(editBox)
                                    editBox:Insert(shareText)
                                end
                            end
                        end
                    end
                end)

                nemesisRows[i] = row
            end

            row.nemData = nem
            row:SetPoint("TOPLEFT", nemesisScrollChild, "TOPLEFT", 0, currentY)
            currentY = currentY - rowHeight

            local isWanted = (nem.status == "WANTED")
            if isWanted then
                row.bg:SetColorTexture(0.35, 0.05, 0.05, 0.45)
                row.status:SetText("|cFFFF0000[BUSCADO]|r")
            else
                row.bg:SetColorTexture(0.05, 0.22, 0.05, 0.35)
                row.status:SetText("|cFF00FF00[VENGADO]|r")
            end

            local classCol = CLASS_COLORS[nem.class] or "FFFFFFFF"
            local raceStr = (nem.race and nem.race ~= "UNKNOWN") and string.format(" (%s)", nem.race) or ""
            row.name:SetText(string.format("|c%s%s|r%s", classCol, nem.name or "Enemigo", raceStr))

            row.score:SetText(string.format("Te abatió: |cFFFF0000%d|r  •  Lo abatiste: |cFF00FF00%d|r", 
                nem.deathsTo or 0, nem.killsOn or 0))

            local dateStr = date("%m/%d %H:%M", nem.lastEncounter or time())
            row.zone:SetText(string.format("%s (%s)", nem.zone or "Mundo Abierto", dateStr))

            row:Show()
        end

        nemesisScrollChild:SetHeight(math.max(1, #nemList * rowHeight))
    end
end

function PvPTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_PVP"] .. " - Honor y Objetivos Prioritarios", -12)

    -- Panel de Estadísticas de Honor
    local honorBox = CreateFrame("Frame", nil, frame)
    honorBox:SetSize(760, 42)
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
    statLabels.lifetime:SetText("Histórico: Cargando...")

    -- Resumen de Victorias / Derrotas de Campos de Batalla
    bgSummaryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgSummaryLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -88)
    bgSummaryLabel:SetText("Campos de Batalla: 0 Victorias - 0 Derrotas")

    -- ========================================================
    -- LISTA DE NÉMESIS / OBJETIVOS PRIORITARIOS DE DESAHUCIO
    -- ========================================================
    local nemHeader = ODD.UI.Components:CreateSectionHeader(frame, "Lista de Némesis (Enemigos que te han abatido):", -118)

    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetSize(760, 18)
    headerFrame:SetPoint("TOPLEFT", nemHeader, "BOTTOMLEFT", 0, -6)

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
    colLoc:SetPoint("RIGHT", headerFrame, "RIGHT", -30, 0)
    colLoc:SetText("Último Encuentro")

    -- Tabla de Némesis con Scroll (cortando limpiamente antes de las pestañas inferiores)
    local scrollFrame = CreateFrame("ScrollFrame", "ODD_NemesisScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(760, 245)
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
