local addonName, addonTable = ...
local ODD = addonTable.ODD
local L = addonTable.L

local Dashboard = {}
ODD.UI.Dashboard = Dashboard

local mainFrame = nil
local activeTab = 1
local tabFrames = {}
local tabButtons = {}

local TAB_DEFS = {
    { name = "HQ", labelKey = "TAB_HQ", creator = function(p) return ODD.UI.HQTab:Create(p) end },
    { name = "Gnomometer", labelKey = "TAB_GNOMOMETER", creator = function(p) return ODD.UI.GnomometerTab:Create(p) end },
    { name = "PvP", labelKey = "TAB_PVP", creator = function(p) return ODD.UI.PvPTab:Create(p) end },
    { name = "Workshops", labelKey = "TAB_WORKSHOPS", creator = function(p) return ODD.UI.WorkshopsTab:Create(p) end },
    { name = "Roster", labelKey = "TAB_ROSTER", creator = function(p) return ODD.UI.RosterTab:Create(p) end },
    { name = "Settings", labelKey = "TAB_SETTINGS", creator = function(p) return ODD.UI.SettingsTab:Create(p) end },
}

local function SwitchTab(tabIndex)
    activeTab = tabIndex
    for i, f in ipairs(tabFrames) do
        if i == tabIndex then
            f:Show()
        else
            f:Hide()
        end
    end
    for i, btn in ipairs(tabButtons) do
        if i == tabIndex then
            btn.bg:SetColorTexture(0.5, 0.1, 0.1, 0.9) -- Rojo Horda activo
            btn.fs:SetTextColor(1, 1, 1, 1)
        else
            btn.bg:SetColorTexture(0.18, 0.18, 0.18, 0.8) -- Inactivo
            btn.fs:SetTextColor(0.8, 0.8, 0.8, 1)
        end
    end
end

function Dashboard:Create()
    if mainFrame then return mainFrame end

    mainFrame = CreateFrame("Frame", "ODD_MainDashboardFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(820, 520)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetToplevel(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:Hide()

    -- Marco temático ornamental Horda / Orgrimmar
    -- Textura como BACKGROUND del mainFrame sin capturar clics para no bloquear el contenido
    local hordeFrame = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -5)
    hordeFrame:SetTexture("Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Art\\frame_horde.png")
    hordeFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", -118, 285)
    hordeFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 118, -205)
    mainFrame.hordeFrame = hordeFrame

    -- Título de la ventana
    mainFrame.TitleBg:SetHeight(30)
    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.title:SetPoint("TOPLEFT", mainFrame.TitleBg, "TOPLEFT", 10, -5)
    mainFrame.title:SetText(L["ADDON_TITLE"] .. " v" .. ODD.version)

    -- Contenedor interior de pestañas
    local contentFrame = CreateFrame("Frame", nil, mainFrame)
    contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -40)
    contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 50)

    -- Generar botones de pestañas
    local prevBtn = nil
    for i, def in ipairs(TAB_DEFS) do
        local btn = CreateFrame("Button", "ODD_TabBtn_" .. i, mainFrame)
        btn:SetID(i)
        btn:SetSize(124, 26)
        btn:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
        
        -- Textura de fondo nativa
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn)
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        btn.bg = bg

        -- Texto
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
        fs:SetText(L[def.labelKey] or def.name)
        btn.fs = fs

        if i == 1 then
            btn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 22, 14)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end

        btn:SetScript("OnClick", function(self)
            SwitchTab(self:GetID())
        end)

        local tabContent = def.creator(contentFrame)
        tabContent:SetFrameLevel(contentFrame:GetFrameLevel() + 2)
        tabContent:Hide()
        table.insert(tabFrames, tabContent)
        table.insert(tabButtons, btn)
        prevBtn = btn
    end

    SwitchTab(1)
    return mainFrame
end

function ODD.UI:Initialize()
    Dashboard:Create()
    if ODD.UI.MinimapBtn and ODD.UI.MinimapBtn.Initialize then
        ODD.UI.MinimapBtn:Initialize()
    end
end

function ODD.UI:Toggle()
    local f = Dashboard:Create()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        -- Al abrir la ventana, disparar sincronización en vivo con la hermandad
        if ODD.Network and ODD.Network.Sync then
            ODD.Network.Sync:RequestGuildSync()
        end
    end
end
