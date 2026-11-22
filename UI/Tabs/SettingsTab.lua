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
    -- BLOQUE 1: IDENTIDAD Y ROL DECLARADO
    -- ========================================================
    local profileHeader = ODD.UI.Components:CreateSectionHeader(frame, "Perfil Declarado en Hermandad:", -38)

    local mainLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -66)
    mainLabel:SetText("Personaje Principal (Main):")

    mainEditBox = CreateFrame("EditBox", "ODD_MainCharEditBox", frame, "InputBoxTemplate")
    mainEditBox:SetSize(160, 20)
    mainEditBox:SetPoint("LEFT", mainLabel, "RIGHT", 10, 0)
    mainEditBox:SetAutoFocus(false)
    mainEditBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText():gsub("%s+", "")
        ODD.Guild.Profiles:SetMainCharacter(text ~= "" and text or nil)
    end)

    local roleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roleLabel:SetPoint("LEFT", mainEditBox, "RIGHT", 30, 0)
    roleLabel:SetText("Rol preferido:")

    local currentRoleIndex = 1
    local roleBtn = CreateFrame("Button", "ODD_RoleSelectorBtn", frame)
    roleBtn:SetSize(130, 22)
    roleBtn:SetPoint("LEFT", roleLabel, "RIGHT", 10, 0)
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

    CreateCheck("Compartir presencia y version de ODD", "sharePresence", -132)
    CreateCheck("Compartir rol y personaje principal (Main)", "shareProfile", -160)
    CreateCheck("Compartir estadisticas de combate declaradas", "shareStats", -188)
    CreateCheck("Compartir recetas y profesiones conocidas", "shareTrades", -216)
    CreateCheck("Silenciar anuncios de hermandad (NO enviar bajas por /g)", "muteGuildAnnouncements", -244)

    local function RefreshSettings()
        local profile = ODD.Guild.Profiles:GetLocalProfile()
        if mainEditBox then
            mainEditBox:SetText(profile.mainCharacter or "")
        end
        UpdateRoleDisplay()

        for _, btn in ipairs(checkboxes) do
            local currentVal = ODD.Database:GetSetting(btn.settingKey)
            btn:SetChecked(currentVal == true)
        end
    end

    frame:SetScript("OnShow", RefreshSettings)
    RefreshSettings()

    return frame
end
