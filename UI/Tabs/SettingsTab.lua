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
    -- BLOQUE 1: ROL PREFERIDO EN HERMANDAD
    -- ========================================================
    local profileHeader = ODD.UI.Components:CreateSectionHeader(frame, "Rol en Hermandad:", -38)

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

    -- ========================================================
    -- BLOQUE 2: PRIVACIDAD Y SINCRONIZACION
    -- ========================================================
    local privHeader = ODD.UI.Components:CreateSectionHeader(frame, "Privacidad y Red P2P:", -106)

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
                if ODD.UI.WorkshopsTab and ODD.UI.WorkshopsTab.Refresh then ODD.UI.WorkshopsTab:Refresh() end
                if ODD.UI.HQTab and ODD.UI.HQTab.RefreshMedals then ODD.UI.HQTab:RefreshMedals() end
            end
        end)

        table.insert(checkboxes, btn)
        return btn
    end

    CreateCheck("Compartir presencia y versión de ODD", "sharePresence", -132)
    CreateCheck("Compartir rol en la hermandad", "shareProfile", -160)
    CreateCheck("Compartir estadísticas de combate declaradas", "shareStats", -188)
    CreateCheck("Compartir recetas y profesiones conocidas", "shareTrades", -216)
    CreateCheck("Silenciar anuncios de hermandad (NO enviar bajas por /g)", "muteGuildAnnouncements", -244)
    CreateCheck("Silenciar efectos de sonido (kill de gnomo y logros)", "muteSounds", -272)

    -- ========================================================
    -- BLOQUE 3: HUD FLOTANTE EN PANTALLA (ESTILO GRS)
    -- ========================================================
    local hudHeader = ODD.UI.Components:CreateSectionHeader(frame, "HUD Flotante (Rastreador en Pantalla):", -304)

    local hudToggleBtn = CreateFrame("Button", "ODD_HUDToggleSettingsBtn", frame)
    hudToggleBtn:SetSize(160, 26)
    hudToggleBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -332)
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
