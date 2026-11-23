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
    { name = "Medals", labelKey = "TAB_MEDALS", creator = function(p) return ODD.UI.MedalsTab:Create(p) end },
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

-- Helper global para habilitar arrastre suave desde cualquier frame o pestaña hija
function Dashboard:EnableFrameDrag(f)
    if not f or f == mainFrame then return end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:HookScript("OnDragStart", function()
        if mainFrame and mainFrame:IsShown() then
            mainFrame:StartMoving()
        end
    end)
    f:HookScript("OnDragStop", function()
        if mainFrame then
            mainFrame:StopMovingOrSizing()
        end
    end)
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

    -- Título de la ventana
    mainFrame.TitleBg:SetHeight(30)
    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.title:SetPoint("TOPLEFT", mainFrame.TitleBg, "TOPLEFT", 10, -5)
    mainFrame.title:SetText(L["ADDON_TITLE"] .. " v" .. ODD.version)

    -- Contenedor interior de pestañas
    local contentFrame = CreateFrame("Frame", "ODD_DashboardContentFrame", mainFrame)
    contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -40)
    contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 50)
    Dashboard:EnableFrameDrag(contentFrame)

    -- Generar botones de pestañas (ancho ajustado a 106px para albergar 7 pestañas)
    local prevBtn = nil
    for i, def in ipairs(TAB_DEFS) do
        local btn = CreateFrame("Button", "ODD_TabBtn_" .. i, mainFrame)
        btn:SetID(i)
        btn:SetSize(106, 26)
        btn:SetFrameLevel(mainFrame:GetFrameLevel() + 20)
        
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
        Dashboard:EnableFrameDrag(tabContent)

        table.insert(tabFrames, tabContent)
        table.insert(tabButtons, btn)
        prevBtn = btn
    end

    -- ========================================================
    -- MARCO TEMÁTICO ORNAMENTAL HORDA / ORGRIMMAR (FONDO ARRASTRABLE + OVERLAY VISUAL)
    -- ========================================================
    -- Frame que abarca todo el tamaño de la imagen exterior (incluyendo los salientes de 118px y 285px)
    -- Permite agarrar y arrastrar la ventana pinchando directamente en cualquier parte de la ilustración exterior
    local artDragFrame = CreateFrame("Frame", "ODD_ArtDragFrame", mainFrame)
    artDragFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", -118, 285)
    artDragFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 118, -205)
    artDragFrame:SetFrameLevel(mainFrame:GetFrameLevel() - 1)
    Dashboard:EnableFrameDrag(artDragFrame)

    -- Capa visual superior para que la textura pinte por ENCIMA de los bordes metálicos de la ventana
    local hordeOverlay = CreateFrame("Frame", "ODD_HordeFrameOverlay", mainFrame)
    hordeOverlay:SetAllPoints(mainFrame)
    hordeOverlay:SetFrameLevel(mainFrame:GetFrameLevel() + 15)
    hordeOverlay:EnableMouse(false) -- No bloquea los botones y controles interiores

    local hordeFrameTex = hordeOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    hordeFrameTex:SetTexture("Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Art\\frame_horde.png")
    hordeFrameTex:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", -118, 285)
    hordeFrameTex:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 118, -205)
    mainFrame.hordeFrameTex = hordeFrameTex

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
