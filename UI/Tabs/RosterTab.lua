local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local RosterTab = {}
ODD.UI.RosterTab = RosterTab

local summaryLabel = nil
local rosterScrollChild = nil
local memberRows = {}
local searchBox = nil
local onlyOnlineCheck = nil

-- Colores de clase oficiales
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

function RosterTab:Refresh()
    if not summaryLabel or not rosterScrollChild then return end

    local members = ODD.Guild.Roster:GetCachedMembers()
    if #members == 0 and ODD.API.Forever:IsInGuild() then
        members = ODD.Guild.Roster:Refresh()
    end

    local onlineCount = 0
    for _, m in ipairs(members) do
        if m.online then onlineCount = onlineCount + 1 end
    end

    summaryLabel:SetText(string.format("Miembros en hermandad: %d  (En linea: |cFF00FF00%d|r)", #members, onlineCount))

    -- Ocultar todas las filas existentes antes de pintar las filtradas
    for _, r in ipairs(memberRows) do
        r:Hide()
    end

    -- Filtrar por texto de búsqueda y por casilla 'Solo conectados'
    local query = searchBox and searchBox:GetText():lower() or ""
    local onlyOnline = onlyOnlineCheck and (onlyOnlineCheck:GetChecked() == true) or false

    local filtered = {}
    for _, m in ipairs(members) do
        local matchesQuery = (query == "") or (m.name and m.name:lower():find(query, 1, true)) or (m.rankName and m.rankName:lower():find(query, 1, true))
        local matchesOnline = (not onlyOnline) or (m.online == true)
        if matchesQuery and matchesOnline then
            table.insert(filtered, m)
        end
    end

    -- Ordenar: primero los conectados, luego por rango/nombre
    table.sort(filtered, function(a, b)
        if a.online ~= b.online then
            return a.online == true
        end
        if a.rankIndex ~= b.rankIndex then
            return (a.rankIndex or 99) < (b.rankIndex or 99)
        end
        return (a.name or "") < (b.name or "")
    end)

    -- 1. Obtener datos del Leaderboard para saber quién es Rank 1 en bajas y puntos
    local rank1KillsName = nil
    local rank1PointsName = nil
    if ODD.Achievements and ODD.Achievements.Rankings then
        local killBoard = ODD.Achievements.Rankings:GetGnomeLeaderboard("kills")
        if killBoard and killBoard[1] and killBoard[1].kills and killBoard[1].kills > 0 then
            rank1KillsName = killBoard[1].name:lower()
        end
        local ptBoard = ODD.Achievements.Rankings:GetGnomeLeaderboard("points")
        if ptBoard and ptBoard[1] and ptBoard[1].points and ptBoard[1].points > 0 then
            rank1PointsName = ptBoard[1].name:lower()
        end
    end

    local globalDB = ODD.Database:GetGlobal()
    local profiles = (globalDB and globalDB.profiles) or {}

    local myName = (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "Tú"
    local myShortName = UnitName("player") or myName
    local myKills = 0
    local myPoints = 0
    local charDB = ODD.Database:GetChar()
    if charDB and charDB.observations and charDB.observations.gnomes then
        myKills = charDB.observations.gnomes.kills or 0
    end
    if ODD.Achievements and ODD.Achievements.Medals then
        myPoints = ODD.Achievements.Medals:GetPlayerAchievementPoints()
    end

    local function GetMemberStats(cleanName)
        if not cleanName or cleanName == "" then return 0, 0 end
        local isSame = ODD.API and ODD.API.Forever and ODD.API.Forever.IsSamePlayer
        if isSame and (isSame(ODD.API.Forever, cleanName, myName) or isSame(ODD.API.Forever, cleanName, myShortName)) then
            return myKills, myPoints
        end
        local cLower = cleanName:lower()
        if cLower == myName:lower() or cLower == myShortName:lower() then
            return myKills, myPoints
        end

        -- 1. Búsqueda directa por clave
        local prof = profiles[cleanName]
        if prof then
            return prof.gnomeKills or 0, prof.achievementPoints or 0
        end

        -- 2. Búsqueda insensible a mayúsculas o nombre parcial ("Nombre" vs "Nombre Apellido")
        for pName, pData in pairs(profiles) do
            if isSame and isSame(ODD.API.Forever, pName, cleanName) then
                return pData.gnomeKills or 0, pData.achievementPoints or 0
            end
            local pLower = pName:lower()
            if pLower == cLower or pLower:find("^" .. cLower) or cLower:find("^" .. pLower) then
                return pData.gnomeKills or 0, pData.achievementPoints or 0
            end
        end

        return 0, 0
    end

    local rowHeight = 22
    local currentY = 0

    for i, m in ipairs(filtered) do
        local row = memberRows[i]
        if not row then
            row = CreateFrame("Frame", nil, rosterScrollChild)
            row:SetSize(740, 20)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            row.bg = bg

            local rStatus = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rStatus:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.status = rStatus

            local rName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rName:SetPoint("LEFT", row, "LEFT", 52, 0)
            row.name = rName

            local rLvl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rLvl:SetPoint("LEFT", row, "LEFT", 195, 0)
            row.lvl = rLvl

            local rRank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rRank:SetPoint("LEFT", row, "LEFT", 245, 0)
            row.rank = rRank

            local rTitle = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rTitle:SetPoint("LEFT", row, "LEFT", 380, 0)
            row.title = rTitle

            local rZone = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            rZone:SetPoint("RIGHT", row, "RIGHT", -16, 0)
            row.zone = rZone

            -- Tooltip enriquecido al pasar el ratón por el miembro
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.3, 0.25, 0.1, 0.45)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.memberData then
                    local md = self.memberData
                    local cName = Ambiguate(md.name or "Desconocido", "none")
                    local cColor = CLASS_COLORS[md.className] or "FFFFFFFF"
                    GameTooltip:AddLine(string.format("|c%s%s|r (Nivel %s %s)", cColor, cName, tostring(md.level or "?"), md.className or ""), 1, 1, 1)
                    GameTooltip:AddLine(string.format("Rango de Hermandad: |cFFFFD100%s|r", md.rankName or "-"), 0.9, 0.9, 0.9)

                    if self.honoraryTitle then
                        GameTooltip:AddLine(string.format("Título ODD: |c%s%s|r", self.honoraryTitleColor or "FFFFFFFF", self.honoraryTitle), 1, 0.82, 0)
                    end
                    GameTooltip:AddLine(string.format("Bajas verificadas/declaradas: |cFFFFD100%d|r", self.kills or 0), 1, 1, 1)
                    GameTooltip:AddLine(string.format("Puntos de Logro: |cFF00FFCC%d pts|r", self.points or 0), 1, 1, 1)

                    if md.online then
                        GameTooltip:AddLine(string.format("Ubicación: |cFF00FF00%s|r", md.zone or "Mundo Abierto"), 0.8, 1, 0.8)
                    else
                        GameTooltip:AddLine("Estado: |cFF888888Desconectado|r", 0.6, 0.6, 0.6)
                    end
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(self)
                if self.rowIndex and self.rowIndex % 2 == 0 then
                    self.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
                else
                    self.bg:SetColorTexture(0.18, 0.18, 0.18, 0.35)
                end
                GameTooltip:Hide()
            end)

            memberRows[i] = row
        end

        row.rowIndex = i
        row.memberData = m
        row:SetPoint("TOPLEFT", rosterScrollChild, "TOPLEFT", 0, currentY)
        currentY = currentY - rowHeight

        if i % 2 == 0 then
            row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
        else
            row.bg:SetColorTexture(0.18, 0.18, 0.18, 0.35)
        end

        local classCol = CLASS_COLORS[m.className] or "FFFFFFFF"
        local cleanName = Ambiguate(m.name or "Desconocido", "none")
        local kCount, pCount = GetMemberStats(cleanName)
        row.kills = kCount
        row.points = pCount

        -- Calcular título honorífico
        local isR1Kills = (rank1KillsName and cleanName:lower() == rank1KillsName)
        local isR1Points = (rank1PointsName and cleanName:lower() == rank1PointsName)
        local hTitle, hColor = "Aspirante", "FF888888"
        if ODD.Achievements and ODD.Achievements.Rankings and ODD.Achievements.Rankings.GetHonoraryTitle then
            hTitle, hColor = ODD.Achievements.Rankings:GetHonoraryTitle(kCount, pCount, isR1Kills, isR1Points)
        end
        row.honoraryTitle = hTitle
        row.honoraryTitleColor = hColor

        if m.online then
            row.status:SetText("|cFF00FF00[ON]|r")
            row.name:SetText(string.format("|c%s%s|r", classCol, cleanName))
            row.lvl:SetText(string.format("|cFFFFD100%s|r", tostring(m.level or "?")))
            row.zone:SetText(m.zone or "Desconocida")
        else
            row.status:SetText("|cFF888888[OFF]|r")
            row.name:SetText(string.format("|cFF888888%s|r", cleanName))
            row.lvl:SetText(string.format("|cFF888888%s|r", tostring(m.level or "?")))
            row.zone:SetText("|cFF666666Desconectado|r")
        end

        row.rank:SetText(string.format("|cFFCCCCCC%s|r", m.rankName or "-"))
        row.title:SetText(string.format("|c%s%s|r", hColor, hTitle))
        row:Show()
    end

    rosterScrollChild:SetHeight(math.max(1, #filtered * rowHeight))
end

local function CreateActionButton(parent, label, x, y, width, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, 22)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetFrameLevel(parent:GetFrameLevel() + 3)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0.35, 0.12, 0.12, 0.9)
    btn.bg = bg

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fs:SetText(label)
    btn.fs = fs

    btn:SetScript("OnClick", onClick)
    return btn
end

function RosterTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_ROSTER"] .. " - Miembros de la Hermandad", -12)

    -- Panel resumen de miembros con borde de tema y florituras
    local summaryBox = ODD.UI.Components:CreateSectionBox(frame, 760, 32, true, 0.45)
    summaryBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)

    summaryLabel = summaryBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summaryLabel:SetPoint("LEFT", summaryBox, "LEFT", 12, 0)
    summaryLabel:SetText("Miembros en hermandad: Cargando...")

    -- Barra de búsqueda y controles
    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -78)
    searchLabel:SetText("Buscar miembro:")

    searchBox = CreateFrame("EditBox", "ODD_RosterSearchBox", frame, "InputBoxTemplate")
    searchBox:SetSize(160, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function()
        RosterTab:Refresh()
    end)

    -- Checkbox 'Solo conectados'
    onlyOnlineCheck = CreateFrame("CheckButton", nil, frame)
    onlyOnlineCheck:SetSize(20, 20)
    onlyOnlineCheck:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    onlyOnlineCheck:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    onlyOnlineCheck:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    onlyOnlineCheck:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    onlyOnlineCheck:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    onlyOnlineCheck:SetChecked(false)

    local checkLabel = onlyOnlineCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkLabel:SetPoint("LEFT", onlyOnlineCheck, "RIGHT", 4, 1)
    checkLabel:SetText("Solo en linea")

    onlyOnlineCheck:SetScript("OnClick", function()
        RosterTab:Refresh()
    end)

    -- Marco contenedor con borde para toda la lista de miembros
    local listContainer = ODD.UI.Components:CreateSectionBox(frame, 760, 286, true, 0.40)
    listContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -106)

    -- Encabezados de la tabla
    local headerFrame = CreateFrame("Frame", nil, listContainer)
    headerFrame:SetSize(750, 18)
    headerFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 6, -6)

    local colState = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colState:SetPoint("LEFT", headerFrame, "LEFT", 8, 0)
    colState:SetText("Est")

    local colName = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colName:SetPoint("LEFT", headerFrame, "LEFT", 52, 0)
    colName:SetText("Nombre")

    local colLvl = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colLvl:SetPoint("LEFT", headerFrame, "LEFT", 210, 0)
    colLvl:SetText("Nivel")

    local colRank = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colRank:SetPoint("LEFT", headerFrame, "LEFT", 245, 0)
    colRank:SetText("Rango")

    local colTitle = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colTitle:SetPoint("LEFT", headerFrame, "LEFT", 380, 0)
    colTitle:SetText("Título Honorífico ODD")

    local colZone = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colZone:SetPoint("RIGHT", headerFrame, "RIGHT", -30, 0)
    colZone:SetText("Zona / Estado")

    -- Tabla de Roster con Scroll dentro del contenedor con borde
    local scrollFrame = CreateFrame("ScrollFrame", "ODD_RosterScrollFrame", listContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(746, 252)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)

    rosterScrollChild = CreateFrame("Frame", nil, scrollFrame)
    rosterScrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(rosterScrollChild)

    frame:SetScript("OnShow", function()
        if ODD.API.Guild and ODD.API.Guild.RequestRoster then
            ODD.API.Guild:RequestRoster()
        end
        if ODD.Guild and ODD.Guild.Roster then
            ODD.Guild.Roster:Refresh()
        end
        RosterTab:Refresh()
    end)

    RosterTab:Refresh()
    return frame
end
