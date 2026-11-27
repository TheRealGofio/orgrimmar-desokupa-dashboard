local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local SoundboardTab = {}
ODD.UI = ODD.UI or {}
ODD.UI.SoundboardTab = SoundboardTab

local frame = nil
local scrollChild = nil
local scrollFrame = nil
local searchBox = nil
local popoutTile = nil
local soundButtons = {}
local filterTab = "ALL" -- "ALL", "FAV", "TRIGGERS"
local currentScope = "GUILD" -- "GUILD", "GROUP"
local filterAllBtn, filterFavBtn, filterTrigBtn = nil, nil, nil
local scopeBtn = nil
local muteBtn = nil
local countLabel = nil
local triggerContainer = nil

-- Paleta armónica de colores para insignias de iniciales
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
    for w in name:gmatch("%S+") do
        table.insert(words, w)
    end
    if #words >= 2 then
        local first = words[1]:sub(1, 1):upper()
        local second = words[2]:sub(1, 1):upper()
        return first .. second
    elseif #words == 1 then
        return words[1]:sub(1, math.min(2, #words[1])):upper()
    else
        return "SB"
    end
end

-- ==========================================================
-- Menú flotante desplegable para seleccionar sonido del trigger
-- ==========================================================
local dropDownMenu = nil
local activeDropKey = nil
local activeDropBtn = nil

local function CreateDropDown()
    if dropDownMenu then return dropDownMenu end

    dropDownMenu = CreateFrame("Frame", "ODD_SBDropDown", UIParent, "BackdropTemplate")
    dropDownMenu:SetSize(200, 220)
    dropDownMenu:SetFrameStrata("TOOLTIP")
    dropDownMenu:SetClampedToScreen(true)
    dropDownMenu:EnableMouse(true)
    dropDownMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    dropDownMenu:SetBackdropBorderColor(0.85, 0.65, 0.20, 1.0)

    local dScroll = CreateFrame("ScrollFrame", "ODD_SBDropScroll", dropDownMenu, "UIPanelScrollFrameTemplate")
    dScroll:SetPoint("TOPLEFT", dropDownMenu, "TOPLEFT", 6, -6)
    dScroll:SetPoint("BOTTOMRIGHT", dropDownMenu, "BOTTOMRIGHT", -22, 6)

    local dContent = CreateFrame("Frame", nil, dScroll)
    dContent:SetSize(170, 1)
    dScroll:SetScrollChild(dContent)

    dropDownMenu.content = dContent
    dropDownMenu.buttons = {}
    dropDownMenu:Hide()

    return dropDownMenu
end

local function OpenSoundDropDown(anchorBtn, dbSettingKey, triggerType)
    local menu = CreateDropDown()
    if menu:IsShown() and activeDropKey == dbSettingKey then
        menu:Hide()
        return
    end

    activeDropKey = dbSettingKey
    activeDropBtn = anchorBtn

    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMRIGHT", 0, -2)

    local sounds = (ODD.Soundboard and ODD.Soundboard.Sounds) or {}
    local dContent = menu.content

    local options = {}
    local defaultLabel = ODD.Soundboard:GetSoundDisplayName("", triggerType)
    table.insert(options, { id = "", name = defaultLabel })
    for _, s in ipairs(sounds) do
        table.insert(options, { id = s.id, name = s.name })
    end

    local itemHeight = 22
    local yPos = -2

    for i, opt in ipairs(options) do
        local btn = menu.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, dContent)
            btn:SetHeight(itemHeight)
            btn:SetNormalFontObject("GameFontHighlightSmall")
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", btn, "LEFT", 4, 0)
            txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
            txt:SetJustifyH("LEFT")
            btn.label = txt

            menu.buttons[i] = btn
        end

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", dContent, "TOPLEFT", 2, yPos)
        btn:SetPoint("TOPRIGHT", dContent, "TOPRIGHT", -2, yPos)
        btn.label:SetText(opt.name)

        local currentVal = ODD.Database:GetSetting(activeDropKey) or ""
        if currentVal == opt.id then
            btn.label:SetTextColor(1, 0.85, 0.2)
        else
            btn.label:SetTextColor(0.9, 0.9, 0.9)
        end

        btn:SetScript("OnClick", function()
            ODD.Database:SetSetting(activeDropKey, opt.id)
            if activeDropBtn then
                activeDropBtn:SetText(string.format("%s >", opt.name))
            end
            menu:Hide()
        end)

        btn:Show()
        yPos = yPos - itemHeight
    end

    for j = #options + 1, #menu.buttons do
        menu.buttons[j]:Hide()
    end

    local totalH = math.min(math.abs(yPos) + 8, 220)
    dContent:SetHeight(math.abs(yPos) + 8)
    menu:SetHeight(totalH)
    menu:Show()
end

function SoundboardTab:Create(parent)
    if frame then return frame end

    frame = CreateFrame("Frame", "ODD_SoundboardTabFrame", parent)
    frame:SetAllPoints(parent)

    -- Encabezado de la pestaña
    local header = ODD.UI.Components:CreateSectionHeader(frame, "Soundboard de Hermandad:", -12)

    -- Barra superior de controles: Búsqueda, Filtros, Ámbito y Mute
    local controlBar = CreateFrame("Frame", nil, frame)
    controlBar:SetSize(760, 26)
    controlBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)

    -- Caja de búsqueda
    local sBox = CreateFrame("EditBox", nil, controlBar, "InputBoxTemplate")
    sBox:SetSize(140, 20)
    sBox:SetPoint("LEFT", controlBar, "LEFT", 6, 0)
    sBox:SetAutoFocus(false)
    sBox:SetFontObject("GameFontHighlightSmall")
    searchBox = sBox

    local sPlaceholder = sBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sPlaceholder:SetPoint("LEFT", sBox, "LEFT", 4, 0)
    sPlaceholder:SetText("Buscar sonido...")

    sBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        if txt and txt ~= "" then
            sPlaceholder:Hide()
        else
            sPlaceholder:Show()
        end
        SoundboardTab:Refresh()
    end)
    sBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    -- Pestañas internas: [Todos] [Favoritos] [Eventos/Ajustes]
    filterAllBtn = CreateFrame("Button", nil, controlBar)
    filterAllBtn:SetSize(60, 20)
    filterAllBtn:SetPoint("LEFT", sBox, "RIGHT", 10, 0)
    filterAllBtn:SetNormalFontObject("GameFontHighlightSmall")
    filterAllBtn:SetScript("OnClick", function()
        filterTab = "ALL"
        SoundboardTab:Refresh()
    end)

    filterFavBtn = CreateFrame("Button", nil, controlBar)
    filterFavBtn:SetSize(78, 20)
    filterFavBtn:SetPoint("LEFT", filterAllBtn, "RIGHT", 4, 0)
    filterFavBtn:SetNormalFontObject("GameFontHighlightSmall")
    filterFavBtn:SetScript("OnClick", function()
        filterTab = "FAV"
        SoundboardTab:Refresh()
    end)

    filterTrigBtn = CreateFrame("Button", nil, controlBar)
    filterTrigBtn:SetSize(72, 20)
    filterTrigBtn:SetPoint("LEFT", filterFavBtn, "RIGHT", 4, 0)
    filterTrigBtn:SetNormalFontObject("GameFontHighlightSmall")
    filterTrigBtn:SetScript("OnClick", function()
        filterTab = "TRIGGERS"
        SoundboardTab:Refresh()
    end)

    -- Indicador de ámbito: Solo Grupo / Banda (Hermandad desactivada)
    scopeBtn = CreateFrame("Button", nil, controlBar)
    scopeBtn:SetSize(130, 20)
    scopeBtn:SetPoint("LEFT", filterTrigBtn, "RIGHT", 10, 0)
    scopeBtn:SetNormalFontObject("GameFontHighlightSmall")
    scopeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Canal de Transmisión", 1, 0.82, 0)
        GameTooltip:AddLine("Los sonidos se transmiten exclusivamente a los miembros de tu grupo o banda.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Si estás solo, el sonido solo sonará para ti.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    scopeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Botón de Mute rápido
    muteBtn = CreateFrame("Button", nil, controlBar)
    muteBtn:SetSize(86, 20)
    muteBtn:SetPoint("LEFT", scopeBtn, "RIGHT", 8, 0)
    muteBtn:SetNormalFontObject("GameFontHighlightSmall")
    muteBtn:SetScript("OnClick", function()
        local isMuted = ODD.Database:GetSetting("muteSoundboard") or false
        ODD.Database:SetSetting("muteSoundboard", not isMuted)
        SoundboardTab:RefreshControls()
    end)

    -- Contador de sonidos mostrados
    countLabel = controlBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countLabel:SetPoint("RIGHT", controlBar, "RIGHT", -10, 0)
    countLabel:SetText("")

    -- ScrollFrame y contenedor de sonidos
    scrollFrame = CreateFrame("ScrollFrame", "ODD_SoundboardScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", controlBar, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 8)

    scrollChild = CreateFrame("Frame", "ODD_SoundboardScrollChild", scrollFrame)
    scrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- ==========================================================
    -- PANEL DE AJUSTES DE EVENTOS / TRIGGERS AUTOMÁTICOS
    -- ==========================================================
    triggerContainer = CreateFrame("Frame", "ODD_SBTriggerContainer", frame)
    triggerContainer:SetPoint("TOPLEFT", controlBar, "BOTTOMLEFT", 0, -8)
    triggerContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 8)
    triggerContainer:Hide()

    local function CreateTriggerCard(parent, titleText, iconTex, prevAnchor, checkKey, soundKey, trigType)
        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        card:SetHeight(48)
        card:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -8)
        card:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
        card:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        card:SetBackdropBorderColor(0.40, 0.25, 0.15, 0.7)

        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", card, "LEFT", 10, 0)
        icon:SetTexture(iconTex)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local chk = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
        chk:SetSize(22, 22)
        chk:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        chk:SetChecked(ODD.Database:GetSetting(checkKey) or false)
        chk:SetScript("OnClick", function(self)
            ODD.Database:SetSetting(checkKey, self:GetChecked())
        end)
        card.chk = chk

        local lbl = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", chk, "RIGHT", 6, 0)
        lbl:SetText(titleText)

        local btnSound = CreateFrame("Button", nil, card)
        btnSound:SetSize(180, 24)
        btnSound:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        btnSound:SetNormalFontObject("GameFontHighlightSmall")

        local btnBg = btnSound:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints(true)
        btnBg:SetColorTexture(0.18, 0.14, 0.12, 0.9)
        btnSound.bg = btnBg

        local btnBorder = CreateFrame("Frame", nil, btnSound, "BackdropTemplate")
        btnBorder:SetAllPoints(true)
        btnBorder:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        btnBorder:SetBackdropBorderColor(0.6, 0.4, 0.2, 0.8)

        local currentSId = ODD.Database:GetSetting(soundKey)
        btnSound:SetText(string.format("%s >", ODD.Soundboard:GetSoundDisplayName(currentSId, trigType)))

        btnSound:SetScript("OnClick", function(self)
            OpenSoundDropDown(self, soundKey, trigType)
        end)
        card.btnSound = btnSound

        return card
    end

    local trigHeader = triggerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    trigHeader:SetPoint("TOPLEFT", triggerContainer, "TOPLEFT", 6, -2)
    trigHeader:SetText("Disparadores Automáticos (Sonidos en Eventos del Juego):")

    local cardLevel = CreateTriggerCard(triggerContainer, "Subida de Nivel (Ding!)", "Interface\\Icons\\Spell_Holy_PrayerOfFortitude", trigHeader, "sbTriggerLevelUp", "sbTriggerLevelUpSound", "levelUp")
    local cardBoss = CreateTriggerCard(triggerContainer, "Victoria en Jefe de Mazmorra / Banda", "Interface\\Icons\\INV_Misc_Head_Dragon_01", cardLevel, "sbTriggerBossKill", "sbTriggerBossKillSound", "bossKill")
    local cardDead = CreateTriggerCard(triggerContainer, "Muerte del Personaje / Wipe", "Interface\\Icons\\Ability_Creature_Cursed_02", cardBoss, "sbTriggerDeath", "sbTriggerDeathSound", "death")
    local cardLoot = CreateTriggerCard(triggerContainer, "Botín / Drop de Objeto Raro o Épico", "Interface\\Icons\\INV_Box_01", cardDead, "sbTriggerLoot", "sbTriggerLootSound", "loot")

    cardLoot:SetHeight(60)

    local chkGreens = CreateFrame("CheckButton", nil, cardLoot, "UICheckButtonTemplate")
    chkGreens:SetSize(18, 18)
    chkGreens:SetPoint("TOPLEFT", cardLoot.chk, "BOTTOMLEFT", 0, -2)
    chkGreens:SetChecked(ODD.Database:GetSetting("sbTriggerLootGreens") or false)
    chkGreens:SetScript("OnClick", function(self)
        ODD.Database:SetSetting("sbTriggerLootGreens", self:GetChecked())
    end)
    local lblGreens = cardLoot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lblGreens:SetPoint("LEFT", chkGreens, "RIGHT", 4, 0)
    lblGreens:SetText("|cFF1EFF00Incluir poco común (verde)|r")

    local note = triggerContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", cardLoot, "BOTTOMLEFT", 6, -14)
    note:SetPoint("RIGHT", triggerContainer, "RIGHT", -10, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Nota: Estos eventos disparan el sonido configurado en tu cliente y lo transmiten silenciosamente a tu Grupo o Banda si estás en uno.")

    self:RefreshControls()
    self:Refresh()

    return frame
end

function SoundboardTab:RefreshControls()
    if not frame then return end

    if filterAllBtn and filterFavBtn and filterTrigBtn then
        filterAllBtn:SetText(filterTab == "ALL" and "|cFFFFD100[Todos]|r" or "|cFF888888[Todos]|r")
        filterFavBtn:SetText(filterTab == "FAV" and "|cFFFFD100[Favoritos]|r" or "|cFF888888[Favoritos]|r")
        filterTrigBtn:SetText(filterTab == "TRIGGERS" and "|cFFFFD100[Eventos]|r" or "|cFF888888[Eventos]|r")
    end

    if scopeBtn then
        scopeBtn:SetText("Canal: |cFF00CCFF[Grupo/Raid]|r")
    end

    if muteBtn then
        local isMuted = (ODD.Soundboard and ODD.Soundboard:IsMuted()) or false
        if isMuted then
            muteBtn:SetText("|cFFFF2020[Silenciado]|r")
        else
            muteBtn:SetText("|cFF00FF00[Sonido ON]|r")
        end
    end
end

function SoundboardTab:Refresh()
    if not frame then return end
    if dropDownMenu then dropDownMenu:Hide() end

    self:RefreshControls()

    if filterTab == "TRIGGERS" then
        if scrollFrame then scrollFrame:Hide() end
        if searchBox then searchBox:Hide() end
        if triggerContainer then triggerContainer:Show() end
        if countLabel then countLabel:SetText("") end
        return
    else
        if triggerContainer then triggerContainer:Hide() end
        if scrollFrame then scrollFrame:Show() end
        if searchBox then searchBox:Show() end
    end

    local sounds = (ODD.Soundboard and ODD.Soundboard.Sounds) or {}
    local searchText = searchBox and searchBox:GetText():lower() or ""

    local filtered = {}
    for _, s in ipairs(sounds) do
        local isFav = ODD.Soundboard:IsFavorite(s.id)
        local matchTab = (filterTab == "ALL") or (filterTab == "FAV" and isFav)
        local matchSearch = true

        if searchText ~= "" then
            local n = s.name:lower()
            local d = (s.desc or ""):lower()
            local id = s.id:lower()
            if not n:find(searchText, 1, true) and not d:find(searchText, 1, true) and not id:find(searchText, 1, true) then
                matchSearch = false
            end
        end

        if matchTab and matchSearch then
            table.insert(filtered, s)
        end
    end

    if countLabel then
        countLabel:SetText(string.format("Sonidos: |cFFFFD100%d|r de %d", #filtered, #sounds))
    end

    for _, b in ipairs(soundButtons) do
        b:Hide()
    end

    local cols = 4
    local btnWidth = 178
    local btnHeight = 36
    local gapX = 10
    local gapY = 6

    -- Tarjeta Especial #1: Botón Destacado de Ventana Flotante / Popout
    if not popoutTile then
        popoutTile = CreateFrame("Button", "ODD_SBPopoutTile", scrollChild, "BackdropTemplate")
        popoutTile:SetSize(btnWidth, btnHeight)

        local pBg = popoutTile:CreateTexture(nil, "BACKGROUND")
        pBg:SetAllPoints(true)
        pBg:SetColorTexture(0.20, 0.14, 0.04, 0.95) -- Tono ámbar/oro oscuro destacado
        popoutTile.bg = pBg

        popoutTile:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        popoutTile:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9) -- Borde dorado brillante

        local pBadge = popoutTile:CreateTexture(nil, "ARTWORK")
        pBadge:SetSize(24, 24)
        pBadge:SetPoint("LEFT", popoutTile, "LEFT", 7, 0)
        pBadge:SetColorTexture(0.40, 0.30, 0.05, 1.0)

        local pBadgeText = popoutTile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pBadgeText:SetPoint("CENTER", pBadge, "CENTER", 0, 0)
        pBadgeText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        pBadgeText:SetTextColor(1, 0.85, 0.1, 1)
        pBadgeText:SetText("[^]")

        local pTitle = popoutTile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pTitle:SetPoint("LEFT", pBadge, "RIGHT", 7, 0)
        pTitle:SetPoint("RIGHT", popoutTile, "RIGHT", -6, 0)
        pTitle:SetJustifyH("LEFT")
        pTitle:SetText("|cFFFFD100Ventana Flotante|r")

        popoutTile:SetScript("OnClick", function()
            if ODD.UI and ODD.UI.SoundboardModal then
                ODD.UI.SoundboardModal:Toggle()
            end
        end)

        popoutTile:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.35, 0.25, 0.08, 1.0)
            self:SetBackdropBorderColor(1.0, 0.95, 0.3, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Abrir Soundboard Flotante", 1, 0.85, 0.2)
            GameTooltip:AddLine("Abre el soundboard en una ventana pequeña, independiente y redimensionable.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("|cFF00FF00Clic:|r Abrir ventana independiente", 0.5, 1, 0.5)
            GameTooltip:Show()
        end)
        popoutTile:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0.20, 0.14, 0.04, 0.95)
            self:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
            GameTooltip:Hide()
        end)
    end

    -- Posicionar la tarjeta de Ventana Flotante en la posición 0 (primera casilla de la cuadrícula)
    popoutTile:ClearAllPoints()
    popoutTile:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4)
    popoutTile:Show()

    -- Los sonidos empiezan a colocarse a partir del índice 1 (segunda casilla)
    for i, s in ipairs(filtered) do
        local btn = soundButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn:SetSize(btnWidth, btnHeight)

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bg:SetColorTexture(0.14, 0.12, 0.12, 0.85)
            btn.bg = bg

            local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
            border:SetAllPoints(true)
            border:SetFrameLevel(btn:GetFrameLevel()) -- Mantener a nivel de fondo para no tapar el texto
            border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            btn.border = border
            if ODD.UI and ODD.UI.Components and ODD.UI.Components.RegisterThemedFrame then
                ODD.UI.Components:RegisterThemedFrame(border, nil, 0.0)
            end

            local badge = btn:CreateTexture(nil, "ARTWORK")
            badge:SetSize(24, 24)
            badge:SetPoint("LEFT", btn, "LEFT", 7, 0)
            btn.badge = badge

            local badgeText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            badgeText:SetPoint("CENTER", badge, "CENTER", 0, 0)
            badgeText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            btn.badgeText = badgeText

            local title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            title:SetPoint("LEFT", badge, "RIGHT", 7, 0)
            title:SetPoint("RIGHT", btn, "RIGHT", -26, 0)
            title:SetJustifyH("LEFT")
            title:SetWordWrap(false)
            title:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE") -- Tipografía nítida y brillante con reborde
            btn.title = title

            local fav = CreateFrame("Button", nil, btn)
            fav:SetSize(20, 20)
            fav:SetPoint("RIGHT", btn, "RIGHT", -4, 0)

            local favIcon = fav:CreateTexture(nil, "OVERLAY")
            favIcon:SetSize(14, 14)
            favIcon:SetPoint("CENTER", fav, "CENTER", 0, 0)
            favIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
            fav.icon = favIcon
            btn.fav = fav

            btn:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.20, 0.20, 0.22, 0.95)
                local p = ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.GetActivePalette and ODD.UI.Dashboard:GetActivePalette()
                if p and p.highlight then
                    self.border:SetBackdropBorderColor(p.highlight[1], p.highlight[2], p.highlight[3], 1.0)
                else
                    self.border:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.soundData.name, 1, 0.82, 0)
                if self.soundData.desc and self.soundData.desc ~= "" then
                    GameTooltip:AddLine(self.soundData.desc, 0.8, 0.8, 0.8, true)
                end
                GameTooltip:AddLine("|cFF00FF00Clic:|r Reproducir y transmitir a Grupo/Banda", 0.5, 1, 0.5)
                GameTooltip:AddLine("|cFFFFFF00Shift + Clic:|r Crear macro en tus barras de acción", 1, 0.82, 0)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0.14, 0.12, 0.12, 0.85)
                if ODD.UI and ODD.UI.Components and ODD.UI.Components.ApplyThemeToFrame then
                    ODD.UI.Components:ApplyThemeToFrame(self.border, nil, 0.65)
                end
                GameTooltip:Hide()
            end)

            soundButtons[i] = btn
        end

        -- Desplazamos un espacio (i en lugar de i-1) porque la posición 0 la ocupa popoutTile
        local slotIndex = i
        local col = slotIndex % cols
        local row = math.floor(slotIndex / cols)
        local posX = col * (btnWidth + gapX) + 4
        local posY = -row * (btnHeight + gapY) - 4

        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", posX, posY)
        btn.soundData = s

        local color = GetBadgeColor(s.id)
        btn.badge:SetColorTexture(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.9)
        btn.badgeText:SetTextColor(color.r, color.g, color.b, 1)
        btn.badgeText:SetText(GetSoundInitials(s.name))

        btn.title:SetText(string.format("|cFFFFFFFF%s|r", s.name))

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
            if filterTab == "FAV" then
                SoundboardTab:Refresh()
            end
        end)

        btn.fav:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if ODD.Soundboard:IsFavorite(s.id) then
                GameTooltip:SetText("Quitar de Favoritos", 1, 0.3, 0.3)
            else
                GameTooltip:SetText("Añadir a Favoritos", 1, 0.85, 0.2)
            end
            GameTooltip:Show()
        end)
        btn.fav:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

    local totalSlots = #filtered + 1
    local totalRows = math.ceil(totalSlots / cols)
    local totalHeight = totalRows * (btnHeight + gapY) + 20
    scrollChild:SetHeight(math.max(totalHeight, 300))
end
