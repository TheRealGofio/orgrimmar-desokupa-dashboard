local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local SoundboardModal = {}
ODD.UI = ODD.UI or {}
ODD.UI.SoundboardModal = SoundboardModal

local modalFrame = nil
local searchBox = nil
local scrollFrame = nil
local contentFrame = nil
local soundButtons = {}
local filterTab = "ALL" -- "ALL", "FAV"
local currentScope = "GUILD"
local filterAllBtn, filterFavBtn = nil, nil
local scopeBtn = nil
local muteBtn = nil
local countLabel = nil

local BADGE_PALETTES = {
    { r = 0.85, g = 0.25, b = 0.20 },
    { r = 0.95, g = 0.65, b = 0.15 },
    { r = 0.20, g = 0.75, b = 0.40 },
    { r = 0.25, g = 0.65, b = 0.95 },
    { r = 0.75, g = 0.40, b = 0.90 },
    { r = 0.90, g = 0.45, b = 0.65 },
    { r = 0.80, g = 0.80, b = 0.25 },
    { r = 0.30, g = 0.85, b = 0.80 },
}

local function GetBadgeColor(soundId)
    local hash = 0
    local str = tostring(soundId or "sound")
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 1000000
    end
    local idx = (hash % #BADGE_PALETTES) + 1
    return BADGE_PALETTES[idx]
end

local function GetSoundInitials(name)
    if not name or name == "" then return "SB" end
    local words = {}
    for w in name:gmatch("%S+") do table.insert(words, w) end
    if #words >= 2 then
        return words[1]:sub(1, 1):upper() .. words[2]:sub(1, 1):upper()
    elseif #words == 1 then
        return words[1]:sub(1, math.min(2, #words[1])):upper()
    else
        return "SB"
    end
end

function SoundboardModal:Create()
    if modalFrame then return modalFrame end

    local globalDB = ODD.Database:GetGlobal()
    local savedW = (globalDB and globalDB.sbModalWidth) or 360
    local savedH = (globalDB and globalDB.sbModalHeight) or 420

    modalFrame = CreateFrame("Frame", "ODD_SoundboardModalFrame", UIParent, "BackdropTemplate")
    modalFrame:SetSize(savedW, savedH)
    modalFrame:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
    modalFrame:SetFrameStrata("HIGH")
    modalFrame:SetToplevel(true)
    modalFrame:SetMovable(true)
    modalFrame:SetResizable(true)
    modalFrame:EnableMouse(true)
    modalFrame:SetClampedToScreen(true)

    if modalFrame.SetMinResize then
        modalFrame:SetMinResize(280, 260)
        modalFrame:SetMaxResize(700, 800)
    elseif modalFrame.SetResizeBounds then
        modalFrame:SetResizeBounds(280, 260, 700, 800)
    end

    modalFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 24, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    modalFrame:SetBackdropBorderColor(0.85, 0.65, 0.20, 1.0)

    -- Arrastre de ventana
    modalFrame:RegisterForDrag("LeftButton")
    modalFrame:SetScript("OnDragStart", modalFrame.StartMoving)
    modalFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left = self:GetLeft()
        local top = self:GetTop()
        if left and top and globalDB then
            globalDB.sbModalLeft = left
            globalDB.sbModalTop = top
        end
    end)

    -- Restaurar posición guardada
    if globalDB and globalDB.sbModalLeft and globalDB.sbModalTop then
        modalFrame:ClearAllPoints()
        modalFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", globalDB.sbModalLeft, globalDB.sbModalTop)
    end

    -- ==========================================================
    -- Cabecera
    -- ==========================================================
    local title = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", modalFrame, "TOPLEFT", 12, -10)
    title:SetText("|cFFFFD100Soundboard|r |cFF888888(ODD)|r")

    local closeBtn = CreateFrame("Button", nil, modalFrame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", modalFrame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        modalFrame:Hide()
    end)

    -- Botón de Mute rápido en cabecera
    muteBtn = CreateFrame("Button", nil, modalFrame)
    muteBtn:SetSize(72, 18)
    muteBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    muteBtn:SetNormalFontObject("GameFontHighlightSmall")
    muteBtn:SetScript("OnClick", function()
        local isMuted = ODD.Database:GetSetting("muteSoundboard") or false
        ODD.Database:SetSetting("muteSoundboard", not isMuted)
        SoundboardModal:RefreshControls()
        if ODD.UI and ODD.UI.SoundboardTab and ODD.UI.SoundboardTab.RefreshControls then
            ODD.UI.SoundboardTab:RefreshControls()
        end
    end)

    -- Barra de controles
    local topBar = CreateFrame("Frame", nil, modalFrame)
    topBar:SetPoint("TOPLEFT", modalFrame, "TOPLEFT", 10, -32)
    topBar:SetPoint("TOPRIGHT", modalFrame, "TOPRIGHT", -10, -32)
    topBar:SetHeight(24)

    searchBox = CreateFrame("EditBox", nil, topBar, "InputBoxTemplate")
    searchBox:SetSize(110, 18)
    searchBox:SetPoint("LEFT", topBar, "LEFT", 4, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlightSmall")

    local sPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
    sPlaceholder:SetText("Buscar...")

    searchBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        if txt and txt ~= "" then sPlaceholder:Hide() else sPlaceholder:Show() end
        SoundboardModal:RefreshList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    filterAllBtn = CreateFrame("Button", nil, topBar)
    filterAllBtn:SetSize(54, 18)
    filterAllBtn:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    filterAllBtn:SetNormalFontObject("GameFontHighlightSmall")
    filterAllBtn:SetScript("OnClick", function()
        filterTab = "ALL"
        SoundboardModal:RefreshList()
    end)

    filterFavBtn = CreateFrame("Button", nil, topBar)
    filterFavBtn:SetSize(66, 18)
    filterFavBtn:SetPoint("LEFT", filterAllBtn, "RIGHT", 4, 0)
    filterFavBtn:SetNormalFontObject("GameFontHighlightSmall")
    filterFavBtn:SetScript("OnClick", function()
        filterTab = "FAV"
        SoundboardModal:RefreshList()
    end)

    scopeBtn = CreateFrame("Button", nil, topBar)
    scopeBtn:SetSize(90, 18)
    scopeBtn:SetPoint("RIGHT", topBar, "RIGHT", -4, 0)
    scopeBtn:SetNormalFontObject("GameFontHighlightSmall")
    scopeBtn:SetScript("OnClick", function()
        if currentScope == "GUILD" then currentScope = "GROUP" else currentScope = "GUILD" end
        ODD.Database:SetSetting("soundboardScope", currentScope)
        SoundboardModal:RefreshControls()
        if ODD.UI and ODD.UI.SoundboardTab and ODD.UI.SoundboardTab.RefreshControls then
            ODD.UI.SoundboardTab:RefreshControls()
        end
    end)

    -- ScrollFrame y Rejilla
    scrollFrame = CreateFrame("ScrollFrame", "ODD_SBModalScrollFrame", modalFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", modalFrame, "BOTTOMRIGHT", -24, 26)

    contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(300, 1)
    scrollFrame:SetScrollChild(contentFrame)

    -- Barra inferior con contador y Resize Grip
    local bottomBar = CreateFrame("Frame", nil, modalFrame)
    bottomBar:SetPoint("BOTTOMLEFT", modalFrame, "BOTTOMLEFT", 10, 4)
    bottomBar:SetPoint("BOTTOMRIGHT", modalFrame, "BOTTOMRIGHT", -10, 4)
    bottomBar:SetHeight(20)

    countLabel = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countLabel:SetPoint("LEFT", bottomBar, "LEFT", 4, 0)
    countLabel:SetText("")

    -- Resize Grip
    local resizeGrip = CreateFrame("Button", nil, modalFrame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", modalFrame, "BOTTOMRIGHT", -3, 3)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

    resizeGrip:SetScript("OnMouseDown", function()
        local left = modalFrame:GetLeft()
        local top = modalFrame:GetTop()
        if left and top then
            modalFrame:ClearAllPoints()
            modalFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        modalFrame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        modalFrame:StopMovingOrSizing()
        local left = modalFrame:GetLeft()
        local top = modalFrame:GetTop()
        local w, h = modalFrame:GetSize()
        local gDB = ODD.Database:GetGlobal()
        if gDB then
            gDB.sbModalLeft = left
            gDB.sbModalTop = top
            gDB.sbModalWidth = w
            gDB.sbModalHeight = h
        end
        SoundboardModal:RefreshList()
    end)

    modalFrame:SetScript("OnSizeChanged", function()
        SoundboardModal:RefreshList()
    end)

    modalFrame:Hide()
    return modalFrame
end

function SoundboardModal:RefreshControls()
    if not modalFrame then return end

    if filterAllBtn and filterFavBtn then
        filterAllBtn:SetText(filterTab == "ALL" and "|cFFFFD100[Todos]|r" or "|cFF888888[Todos]|r")
        filterFavBtn:SetText(filterTab == "FAV" and "|cFFFFD100[Favs]|r" or "|cFF888888[Favs]|r")
    end

    local scope = ODD.Database:GetSetting("soundboardScope") or currentScope or "GUILD"
    currentScope = scope
    if scopeBtn then
        scopeBtn:SetText(scope == "GUILD" and "|cFF00FF00[Hermandad]|r" or "|cFF00CCFF[Grupo]|r")
    end

    if muteBtn then
        local isMuted = (ODD.Soundboard and ODD.Soundboard:IsMuted()) or false
        muteBtn:SetText(isMuted and "|cFFFF2020[Muted]|r" or "|cFF00FF00[Audio ON]|r")
    end
end

function SoundboardModal:RefreshList()
    if not modalFrame or not contentFrame then return end

    self:RefreshControls()

    local sounds = (ODD.Soundboard and ODD.Soundboard.Sounds) or {}
    local searchText = searchBox and searchBox:GetText():lower() or ""

    local filtered = {}
    for _, s in ipairs(sounds) do
        local isFav = ODD.Soundboard:IsFavorite(s.id)
        local matchTab = (filterTab == "ALL") or (filterTab == "FAV" and isFav)
        local matchSearch = true

        if searchText ~= "" then
            local n = s.name:lower()
            local id = s.id:lower()
            if not n:find(searchText, 1, true) and not id:find(searchText, 1, true) then
                matchSearch = false
            end
        end

        if matchTab and matchSearch then
            table.insert(filtered, s)
        end
    end

    if countLabel then
        countLabel:SetText(string.format("%d clips", #filtered))
    end

    for _, b in ipairs(soundButtons) do b:Hide() end

    -- Cálculo adaptativo de columnas según ancho actual
    local availWidth = scrollFrame:GetWidth() - 20
    contentFrame:SetWidth(availWidth)

    local minColWidth = 145
    local cols = math.floor(availWidth / minColWidth)
    if cols < 1 then cols = 1 end
    if cols > 4 then cols = 4 end

    local gap = 6
    local btnWidth = math.floor((availWidth - ((cols - 1) * gap)) / cols)
    local btnHeight = 32

    for i, s in ipairs(filtered) do
        local btn = soundButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, contentFrame)
            btn:SetNormalFontObject("GameFontHighlightSmall")

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bg:SetColorTexture(0.14, 0.12, 0.12, 0.90)
            btn.bg = bg

            local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
            border:SetAllPoints(true)
            border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            border:SetBackdropBorderColor(0.40, 0.25, 0.15, 0.7)
            btn.border = border

            local badge = btn:CreateTexture(nil, "ARTWORK")
            badge:SetSize(22, 22)
            badge:SetPoint("LEFT", btn, "LEFT", 5, 0)
            btn.badge = badge

            local badgeText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            badgeText:SetPoint("CENTER", badge, "CENTER", 0, 0)
            badgeText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            btn.badgeText = badgeText

            local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            title:SetPoint("LEFT", badge, "RIGHT", 5, 0)
            title:SetPoint("RIGHT", btn, "RIGHT", -22, 0)
            title:SetJustifyH("LEFT")
            title:SetWordWrap(false)
            btn.title = title

            local fav = CreateFrame("Button", nil, btn)
            fav:SetSize(18, 18)
            fav:SetPoint("RIGHT", btn, "RIGHT", -2, 0)

            local favIcon = fav:CreateTexture(nil, "OVERLAY")
            favIcon:SetSize(12, 12)
            favIcon:SetPoint("CENTER", fav, "CENTER", 0, 0)
            favIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
            fav.icon = favIcon
            btn.fav = fav

            btn:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.28, 0.16, 0.12, 0.95)
                self.border:SetBackdropBorderColor(0.85, 0.65, 0.20, 1.0)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.soundData.name, 1, 0.82, 0)
                local scopeTxt = (currentScope == "GUILD") and "Hermandad" or "Grupo"
                GameTooltip:AddLine("|cFF00FF00Clic:|r Transmitir a " .. scopeTxt, 0.5, 1, 0.5)
                GameTooltip:AddLine("|cFFFFFF00Shift + Clic:|r Crear macro en tus barras", 1, 0.82, 0)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0.14, 0.12, 0.12, 0.90)
                self.border:SetBackdropBorderColor(0.40, 0.25, 0.15, 0.7)
                GameTooltip:Hide()
            end)

            soundButtons[i] = btn
        end

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local posX = col * (btnWidth + gap)
        local posY = -row * (btnHeight + gap) - 2

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", posX, posY)
        btn:SetSize(btnWidth, btnHeight)
        btn.soundData = s

        local color = GetBadgeColor(s.id)
        btn.badge:SetColorTexture(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.9)
        btn.badgeText:SetTextColor(color.r, color.g, color.b, 1)
        btn.badgeText:SetText(GetSoundInitials(s.name))

        btn.title:SetText(string.format("|cFFFFD100%s|r", s.name))

        local isFav = ODD.Soundboard:IsFavorite(s.id)
        if isFav then
            btn.fav.icon:SetVertexColor(1, 0.85, 0.1, 1.0)
        else
            btn.fav.icon:SetVertexColor(0.35, 0.35, 0.35, 0.45)
        end

        btn.fav:SetScript("OnClick", function()
            local nowFav = ODD.Soundboard:ToggleFavorite(s.id)
            if nowFav then
                btn.fav.icon:SetVertexColor(1, 0.85, 0.1, 1.0)
            else
                btn.fav.icon:SetVertexColor(0.35, 0.35, 0.35, 0.45)
            end
            if filterTab == "FAV" then SoundboardModal:RefreshList() end
            if ODD.UI and ODD.UI.SoundboardTab and ODD.UI.SoundboardTab.Refresh then
                ODD.UI.SoundboardTab:Refresh()
            end
        end)

        btn:SetScript("OnClick", function(self)
            if IsShiftKeyDown and IsShiftKeyDown() then
                if ODD.Soundboard and ODD.Soundboard.CreateSoundMacro then
                    ODD.Soundboard:CreateSoundMacro(s.id)
                end
            else
                if ODD.Soundboard then
                    ODD.Soundboard:TriggerSound(s.id, currentScope)
                end
            end
        end)

        btn:Show()
    end

    local totalRows = math.ceil(#filtered / cols)
    local totalH = totalRows * (btnHeight + gap) + 12
    contentFrame:SetHeight(math.max(totalH, 50))
end

function SoundboardModal:Toggle()
    local f = self:Create()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        self:RefreshList()
    end
end
