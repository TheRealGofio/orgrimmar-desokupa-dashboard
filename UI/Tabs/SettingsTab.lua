local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local SettingsTab = {}
ODD.UI.SettingsTab = SettingsTab

local checkboxes = {}
local mainEditBox = nil
local roleDropdown = nil
local roleOptions = {"DPS", "Tanque", "Sanador", "Desokupador", "Artesano"}

function SettingsTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_SETTINGS"] .. " - Configuracion y Perfil", -12)

    -- ========================================================
    -- BLOQUE 1: ROL PREFERIDO Y TEMA DEL MARCO
    -- ========================================================
    local profileHeader = ODD.UI.Components:CreateSectionHeader(frame, "Personalización y Rol:", -38)

    local roleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -66)
    roleLabel:SetText("Rol preferido:")

    local currentRoleIndex = 1
    local roleBtn = CreateFrame("Button", "ODD_RoleSelectorBtn", frame)
    roleBtn:SetSize(140, 22)
    roleBtn:SetPoint("LEFT", roleLabel, "RIGHT", 12, 0)
    roleBtn:SetFrameLevel(frame:GetFrameLevel() + 3)
    local rBg = roleBtn:CreateTexture(nil, "BACKGROUND")
    rBg:SetAllPoints(roleBtn)
    rBg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    local rFs = roleBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rFs:SetPoint("CENTER", roleBtn, "CENTER", 0, 0)
    roleBtn.fs = rFs

    local function UpdateRoleDisplay()
        local profile = ODD.Guild.Profiles:GetLocalProfile()
        local r = profile.customRole or "DPS"
        rFs:SetText(string.format("|cFFFFD100%s|r (clic cambia)", r))
    end

    roleBtn:SetScript("OnClick", function()
        currentRoleIndex = (currentRoleIndex % #roleOptions) + 1
        local newRole = roleOptions[currentRoleIndex]
        ODD.Guild.Profiles:SetCustomRole(newRole)
        UpdateRoleDisplay()
        ODD:Log("Rol declarado actualizado a: %s", newRole)
    end)

    -- Selector de Tema Visual del Marco
    local themeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    themeLabel:SetPoint("LEFT", roleBtn, "RIGHT", 28, 0)
    themeLabel:SetText("Tema del Marco:")

    local themeOptions = {
        { key = "classic", name = "Orco Clásico",   color = "FFFFD100" },
        { key = "molten",  name = "Hierro y Magma",  color = "FFFF4000" },
        { key = "fel",     name = "Añublo Vil",      color = "FF00FF00" },
        { key = "frost",   name = "Hielo Rasganorte",color = "FF00CCFF" },
        { key = "troll",   name = "Vudú Trol",       color = "FFAA44FF" },
    }

    local themeBtn = CreateFrame("Button", "ODD_ThemeSelectorBtn", frame)
    themeBtn:SetSize(180, 22)
    themeBtn:SetPoint("LEFT", themeLabel, "RIGHT", 12, 0)
    themeBtn:SetFrameLevel(frame:GetFrameLevel() + 3)
    local tBg = themeBtn:CreateTexture(nil, "BACKGROUND")
    tBg:SetAllPoints(themeBtn)
    tBg:SetColorTexture(0.18, 0.18, 0.22, 0.9)
    local tFs = themeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tFs:SetPoint("CENTER", themeBtn, "CENTER", 0, 0)
    themeBtn.fs = tFs

    local function UpdateThemeDisplay()
        local curKey = (ODD.Database and ODD.Database:GetSetting("theme")) or "classic"
        local found = themeOptions[1]
        for _, opt in ipairs(themeOptions) do
            if opt.key == curKey then
                found = opt
                break
            end
        end
        tFs:SetText(string.format("|c%s%s|r (clic cambia)", found.color, found.name))
    end

    themeBtn:SetScript("OnClick", function()
        local curKey = (ODD.Database and ODD.Database:GetSetting("theme")) or "classic"
        local nextIdx = 1
        for idx, opt in ipairs(themeOptions) do
            if opt.key == curKey then
                nextIdx = (idx % #themeOptions) + 1
                break
            end
        end
        local newTheme = themeOptions[nextIdx]
        if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.SetTheme then
            ODD.UI.Dashboard:SetTheme(newTheme.key)
        else
            ODD.Database:SetSetting("theme", newTheme.key)
        end
        UpdateThemeDisplay()
    end)

    -- Selector de Zoom / Escala con Botones [-] [+] estables y limpios
    local scaleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -96)
    scaleLabel:SetText("Tamaño / Zoom:")

    -- Botón de reducir [-]
    local minusBtn = CreateFrame("Button", "ODD_ScaleMinusBtn", frame)
    minusBtn:SetSize(24, 22)
    minusBtn:SetPoint("LEFT", scaleLabel, "RIGHT", 14, 0)
    minusBtn:SetFrameLevel(frame:GetFrameLevel() + 3)
    local mBg = minusBtn:CreateTexture(nil, "BACKGROUND")
    mBg:SetAllPoints(minusBtn)
    mBg:SetColorTexture(0.25, 0.1, 0.1, 0.9)
    local mFs = minusBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mFs:SetPoint("CENTER", minusBtn, "CENTER", 0, 0)
    mFs:SetText("|cFFFFFFFF-|r")
    minusBtn.fs = mFs

    -- Indicador numérico central
    local scaleValFs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleValFs:SetPoint("LEFT", minusBtn, "RIGHT", 12, 0)
    scaleValFs:SetText("100%")

    -- Botón de aumentar [+]
    local plusBtn = CreateFrame("Button", "ODD_ScalePlusBtn", frame)
    plusBtn:SetSize(24, 22)
    plusBtn:SetPoint("LEFT", scaleValFs, "RIGHT", 12, 0)
    plusBtn:SetFrameLevel(frame:GetFrameLevel() + 3)
    local pBg = plusBtn:CreateTexture(nil, "BACKGROUND")
    pBg:SetAllPoints(plusBtn)
    pBg:SetColorTexture(0.1, 0.25, 0.1, 0.9)
    local pFs = plusBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pFs:SetPoint("CENTER", plusBtn, "CENTER", 0, 0)
    pFs:SetText("|cFFFFFFFF+|r")
    plusBtn.fs = pFs

    local function UpdateScaleDisplay()
        local curScale = (ODD.Database and ODD.Database:GetSetting("uiScale")) or 1.0
        local pct = math.floor(curScale * 100 + 0.5)
        scaleValFs:SetText(string.format("|cFF00FFCC%d%%|r", pct))
    end

    minusBtn:SetScript("OnClick", function()
        local curScale = (ODD.Database and ODD.Database:GetSetting("uiScale")) or 1.0
        local newScale = math.max(0.65, curScale - 0.05)
        if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.ApplyScale then
            ODD.UI.Dashboard:ApplyScale(newScale)
        elseif ODD.Database then
            ODD.Database:SetSetting("uiScale", newScale)
        end
        UpdateScaleDisplay()
    end)

    plusBtn:SetScript("OnClick", function()
        local curScale = (ODD.Database and ODD.Database:GetSetting("uiScale")) or 1.0
        local newScale = math.min(1.25, curScale + 0.05)
        if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.ApplyScale then
            ODD.UI.Dashboard:ApplyScale(newScale)
        elseif ODD.Database then
            ODD.Database:SetSetting("uiScale", newScale)
        end
        UpdateScaleDisplay()
    end)

    -- Botón de Reset 100%
    local resetScaleBtn = CreateFrame("Button", "ODD_ScaleResetBtn", frame)
    resetScaleBtn:SetSize(70, 22)
    resetScaleBtn:SetPoint("LEFT", plusBtn, "RIGHT", 14, 0)
    resetScaleBtn:SetFrameLevel(frame:GetFrameLevel() + 3)
    local rBg = resetScaleBtn:CreateTexture(nil, "BACKGROUND")
    rBg:SetAllPoints(resetScaleBtn)
    rBg:SetColorTexture(0.18, 0.18, 0.22, 0.9)
    local rFs = resetScaleBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rFs:SetPoint("CENTER", resetScaleBtn, "CENTER", 0, 0)
    rFs:SetText("100%")
    resetScaleBtn.fs = rFs

    resetScaleBtn:SetScript("OnClick", function()
        if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.ApplyScale then
            ODD.UI.Dashboard:ApplyScale(1.0)
        elseif ODD.Database then
            ODD.Database:SetSetting("uiScale", 1.0)
        end
        UpdateScaleDisplay()
    end)

    -- Botón de auto-ajuste según resolución
    local autoScaleBtn = CreateFrame("Button", "ODD_AutoScaleBtn", frame)
    autoScaleBtn:SetSize(110, 22)
    autoScaleBtn:SetPoint("LEFT", resetScaleBtn, "RIGHT", 10, 0)
    autoScaleBtn:SetFrameLevel(frame:GetFrameLevel() + 3)
    local asBg = autoScaleBtn:CreateTexture(nil, "BACKGROUND")
    asBg:SetAllPoints(autoScaleBtn)
    asBg:SetColorTexture(0.14, 0.22, 0.14, 0.9)
    local asFs = autoScaleBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    asFs:SetPoint("CENTER", autoScaleBtn, "CENTER", 0, 0)
    asFs:SetText("|cFF00FF00Auto-Ajustar|r")
    autoScaleBtn.fs = asFs

    autoScaleBtn:SetScript("OnClick", function()
        if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.ApplyScale then
            local applied = ODD.UI.Dashboard:ApplyScale(0) -- 0 fuerza el cálculo automático inteligente
            UpdateScaleDisplay()
            ODD:Log("Escala auto-ajustada según pantalla: %d%%", math.floor(applied * 100))
        end
    end)

    -- ========================================================
    -- BLOQUE 2: PRIVACIDAD Y SINCRONIZACION
    -- ========================================================
    local privHeader = ODD.UI.Components:CreateSectionHeader(frame, "Privacidad y Red P2P:", -126)

    checkboxes = {}
    local function CreateCheck(label, settingKey, yOffset)
        local btn = CreateFrame("CheckButton", nil, frame)
        btn:SetSize(22, 22)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, yOffset)

        btn:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        btn:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        btn:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        btn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", btn, "RIGHT", 6, 1)
        text:SetText(label)

        btn.settingKey = settingKey

        btn:SetScript("OnClick", function(self)
            ODD.Database:SetSetting(settingKey, self:GetChecked() == true)
            -- Si se modifica la visibilidad de testing tools, refrescar pestañas
            if settingKey == "showTestingTools" then
                if ODD.UI.GnomometerTab and ODD.UI.GnomometerTab.Refresh then ODD.UI.GnomometerTab:Refresh() end
                if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then ODD.UI.PvPTab:Refresh() end
                if ODD.UI.HistoryTab and ODD.UI.HistoryTab.Refresh then ODD.UI.HistoryTab:Refresh() end
                if ODD.UI.HQTab and ODD.UI.HQTab.RefreshMedals then ODD.UI.HQTab:RefreshMedals() end
            end
        end)

        table.insert(checkboxes, btn)
        return btn
    end

    CreateCheck("Compartir presencia y versión de ODD", "sharePresence", -150)
    CreateCheck("Compartir rol en la hermandad", "shareProfile", -174)
    CreateCheck("Compartir estadísticas de combate declaradas", "shareStats", -198)
    CreateCheck("Silenciar anuncios de hermandad (NO enviar bajas por /g)", "muteGuildAnnouncements", -222)
    CreateCheck("Silenciar efectos de sonido (kill de gnomo y logros)", "muteSounds", -246)
    CreateCheck("Activar Radar de Proximidad (alerta sonora al avistar gnomos)", "enableGnomeRadar", -270)

    -- ========================================================
    -- BLOQUE 3: HUD FLOTANTE EN PANTALLA (ESTILO GRS)
    -- ========================================================
    local hudHeader = ODD.UI.Components:CreateSectionHeader(frame, "HUD Flotante (Rastreador en Pantalla):", -304)

    local hudToggleBtn = CreateFrame("Button", "ODD_HUDToggleSettingsBtn", frame)
    hudToggleBtn:SetSize(160, 24)
    hudToggleBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -330)
    local hBg = hudToggleBtn:CreateTexture(nil, "BACKGROUND")
    hBg:SetAllPoints()
    hBg:SetColorTexture(0.25, 0.1, 0.1, 0.9)
    hudToggleBtn.bg = hBg

    local hFs = hudToggleBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hFs:SetPoint("CENTER", hudToggleBtn, "CENTER", 0, 0)
    hudToggleBtn.fs = hFs

    local function UpdateHUDButtonDisplay()
        local isEnabled = ODD.Database:GetSetting("showHUD") == true
        if isEnabled then
            hudToggleBtn.bg:SetColorTexture(0.1, 0.35, 0.1, 0.9)
            hudToggleBtn.fs:SetText("HUD: |cFF00FF00ACTIVADO|r")
        else
            hudToggleBtn.bg:SetColorTexture(0.3, 0.1, 0.1, 0.9)
            hudToggleBtn.fs:SetText("HUD: |cFFFF0000DESACTIVADO|r")
        end
    end

    hudToggleBtn:SetScript("OnClick", function()
        if ODD.UI and ODD.UI.HUD then
            ODD.UI.HUD:Toggle()
            UpdateHUDButtonDisplay()
        end
    end)

    local hudDesc = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hudDesc:SetPoint("LEFT", hudToggleBtn, "RIGHT", 14, 0)
    hudDesc:SetText("Muestra una tarjeta compacta y arrastrable con las bajas de hoy, semana y hermandad.")

    local function RefreshSettings()
        UpdateRoleDisplay()
        UpdateThemeDisplay()
        UpdateScaleDisplay()

        for _, btn in ipairs(checkboxes) do
            local currentVal = ODD.Database:GetSetting(btn.settingKey)
            btn:SetChecked(currentVal == true)
        end
        UpdateHUDButtonDisplay()
    end

    frame:SetScript("OnShow", RefreshSettings)
    RefreshSettings()

    return frame
end
