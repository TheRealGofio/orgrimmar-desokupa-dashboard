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

    -- Filtrar por texto de búsqueda y por casilla 'Solo conectados'
    local query = searchBox and searchBox:GetText():lower() or ""
    local onlyOnline = onlyOnlineCheck and onlyOnlineCheck:GetChecked() or false

    local filtered = {}
    for _, m in ipairs(members) do
        local matchesQuery = (query == "") or (m.name and m.name:lower():find(query)) or (m.rankName and m.rankName:lower():find(query))
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

    -- Ocultar filas existentes
    for _, r in ipairs(memberRows) do r:Hide() end

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
            rLvl:SetPoint("LEFT", row, "LEFT", 210, 0)
            row.lvl = rLvl

            local rRank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rRank:SetPoint("LEFT", row, "LEFT", 270, 0)
            row.rank = rRank

            local rZone = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            rZone:SetPoint("RIGHT", row, "RIGHT", -16, 0)
            row.zone = rZone

            memberRows[i] = row
        end

        row:SetPoint("TOPLEFT", rosterScrollChild, "TOPLEFT", 0, currentY)
        currentY = currentY - rowHeight

        if i % 2 == 0 then
            row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
        else
            row.bg:SetColorTexture(0.18, 0.18, 0.18, 0.35)
        end

        local classCol = CLASS_COLORS[m.className] or "FFFFFFFF"
        local cleanName = Ambiguate(m.name or "Desconocido", "none")

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

    -- Panel resumen de miembros
    local summaryBox = CreateFrame("Frame", nil, frame)
    summaryBox:SetSize(760, 32)
    summaryBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
    local sBg = summaryBox:CreateTexture(nil, "BACKGROUND")
    sBg:SetAllPoints(summaryBox)
    sBg:SetColorTexture(0.12, 0.12, 0.12, 0.5)

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

    -- Botón de refresco manual
    CreateActionButton(frame, "Refrescar Roster", 430, -76, 120, function()
        if ODD.Guild and ODD.Guild.Roster then
            ODD.API.Guild:RequestRoster()
            ODD.Guild.Roster:Refresh()
            RosterTab:Refresh()
        end
    end)

    -- Encabezados de la tabla
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetSize(760, 18)
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -110)

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
    colRank:SetPoint("LEFT", headerFrame, "LEFT", 270, 0)
    colRank:SetText("Rango")

    local colZone = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colZone:SetPoint("RIGHT", headerFrame, "RIGHT", -30, 0)
    colZone:SetText("Zona / Estado")

    -- Tabla de Roster con Scroll
    local scrollFrame = CreateFrame("ScrollFrame", "ODD_RosterScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(760, 260)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)

    rosterScrollChild = CreateFrame("Frame", nil, scrollFrame)
    rosterScrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(rosterScrollChild)

    frame:SetScript("OnShow", function()
        RosterTab:Refresh()
    end)

    RosterTab:Refresh()
    return frame
end
