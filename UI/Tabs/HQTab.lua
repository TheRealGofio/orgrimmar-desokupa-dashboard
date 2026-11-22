local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local HQTab = {}
ODD.UI.HQTab = HQTab

local pLabel = nil
local peerStatus = nil
local medalsScrollChild = nil
local medalRows = {}

function HQTab:RefreshPresence()
    if not ODD.Network or not ODD.Network.Sync or not peerStatus then return end
    local peers = ODD.Network.Sync:GetOnlinePeers()
    local count = 0
    local names = {}
    for name, _ in pairs(peers) do
        count = count + 1
        table.insert(names, name)
    end
    if count == 0 then
        peerStatus:SetText("Compañeros con ODD en linea: 0")
    else
        peerStatus:SetText(string.format("Compañeros con ODD en linea: |cFF00FF00%d|r (%s)", count, table.concat(names, ", ")))
    end
end

function HQTab:RefreshMedals()
    if not medalsScrollChild or not ODD.Achievements or not ODD.Achievements.Medals then return end

    local medals = ODD.Achievements.Medals:GetPlayerMedals()
    for _, r in ipairs(medalRows) do r:Hide() end

    local rowHeight = 36
    local currentY = 0

    for i, m in ipairs(medals) do
        local row = medalRows[i]
        if not row then
            row = CreateFrame("Frame", nil, medalsScrollChild)
            row:SetSize(740, 32)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            row.bg = bg

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(26, 26)
            icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.icon = icon

            local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            title:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -2)
            row.title = title

            local desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            desc:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 38, 2)
            row.desc = desc

            local prog = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            prog:SetPoint("RIGHT", row, "RIGHT", -16, 0)
            row.prog = prog

            medalRows[i] = row
        end

        row:SetPoint("TOPLEFT", medalsScrollChild, "TOPLEFT", 0, currentY)
        currentY = currentY - rowHeight

        row.icon:SetTexture(m.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.desc:SetText(m.desc)

        if m.completed then
            row.bg:SetColorTexture(0.1, 0.28, 0.1, 0.45)
            row.title:SetText(string.format("|cFFFFD100%s|r  |cFF00FF00[Completada]|r", m.name))
            row.prog:SetText(string.format("|cFF00FF00%d / %d|r", m.progress, m.maxReq))
            row.icon:SetDesaturated(false)
        else
            row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
            row.title:SetText(string.format("|cFF888888%s|r", m.name))
            row.prog:SetText(string.format("|cFF888888%d / %d|r", m.progress, m.maxReq))
            row.icon:SetDesaturated(true)
        end

        row:Show()
    end

    medalsScrollChild:SetHeight(math.max(1, #medals * rowHeight))
end

function HQTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_HQ"] .. " - Estado General de Hermandad", -12)

    -- Ficha del personaje local
    local profileBox = CreateFrame("Frame", nil, frame)
    profileBox:SetSize(760, 48)
    profileBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
    local pBg = profileBox:CreateTexture(nil, "BACKGROUND")
    pBg:SetAllPoints(profileBox)
    pBg:SetColorTexture(0.12, 0.12, 0.12, 0.5)

    pLabel = profileBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pLabel:SetPoint("TOPLEFT", profileBox, "TOPLEFT", 12, -8)
    pLabel:SetText("Cargando perfil...")

    local oLabel = profileBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    oLabel:SetPoint("BOTTOMLEFT", profileBox, "BOTTOMLEFT", 12, 8)
    oLabel:SetText("Origen: " .. L["STATUS_LOCAL_OBSERVED"])

    -- Botón de sincronización manual y monitor de compañeros
    local syncBtn = CreateFrame("Button", "ODD_SyncGuildBtn", frame)
    syncBtn:SetSize(160, 24)
    syncBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -96)
    syncBtn:SetFrameLevel(frame:GetFrameLevel() + 3)

    local syncBg = syncBtn:CreateTexture(nil, "BACKGROUND")
    syncBg:SetAllPoints(syncBtn)
    syncBg:SetColorTexture(0.5, 0.1, 0.1, 0.9)
    syncBtn.bg = syncBg

    local syncText = syncBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncText:SetPoint("CENTER", syncBtn, "CENTER", 0, 0)
    syncText:SetText("Sincronizar hermandad")

    syncBtn:SetScript("OnClick", function()
        if ODD.Network and ODD.Network.Sync then
            ODD.Network.Sync:TriggerManualSync()
        end
    end)

    peerStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    peerStatus:SetPoint("LEFT", syncBtn, "RIGHT", 16, 0)
    peerStatus:SetText("Compañeros con ODD en linea: 0")

    -- ========================================================
    -- PANEL DE MEDALLAS Y LOGROS INTERNOS
    -- ========================================================
    local medHeader = ODD.UI.Components:CreateSectionHeader(frame, "Medallas y Logros de Orgrimmar Desokupa:", -136)

    local scrollFrame = CreateFrame("ScrollFrame", "ODD_MedalsScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(760, 275)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -165)

    medalsScrollChild = CreateFrame("Frame", nil, scrollFrame)
    medalsScrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(medalsScrollChild)

    local function Refresh()
        local profile = ODD.Guild.Profiles:GetLocalProfile()
        local mainText = profile.mainCharacter and string.format(" (Main: %s)", profile.mainCharacter) or ""
        local roleText = profile.customRole and string.format(" [%s]", profile.customRole) or ""
        local pText = string.format("Personaje: |cFFFFD100%s%s%s|r  •  Clase: |cFFFFD100%s|r  •  Nivel: |cFFFFD100%s|r", 
            profile.name or UnitName("player") or "Desconocido", 
            mainText,
            roleText,
            profile.class or select(2, UnitClass("player")) or "Desconocido", 
            tostring(profile.level or UnitLevel("player") or "?"))
        pLabel:SetText(pText)

        HQTab:RefreshPresence()
        HQTab:RefreshMedals()
    end

    frame:SetScript("OnShow", Refresh)
    Refresh()

    return frame
end
