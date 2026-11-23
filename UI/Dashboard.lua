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
            btn.bg:SetColorTexture(0.5, 0.1, 0.1, 0.95) -- Rojo Horda activo
            btn.fs:SetTextColor(1, 1, 1, 1)
        else
            btn.bg:SetColorTexture(0.12, 0.12, 0.12, 0.85) -- Inactivo negro carbón
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

    -- Ventana principal sin plantilla metálica gris para mimetizar totalmente con el fondo negro de frame_4
    mainFrame = CreateFrame("Frame", "ODD_MainDashboardFrame", UIParent)
    mainFrame:SetSize(830, 520)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetToplevel(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:Hide()

    -- Fondo negro sólido nativo (mimetizado con el fondo negro de frame_4)
    local solidBlackBg = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solidBlackBg:SetAllPoints(mainFrame)
    solidBlackBg:SetColorTexture(0, 0, 0, 1)
    mainFrame.solidBlackBg = solidBlackBg

    -- Registrar la ventana en el gestor nativo de ESC de World of Warcraft
    _G["ODD_MainDashboardFrame"] = mainFrame
    table.insert(UISpecialFrames, "ODD_MainDashboardFrame")

    -- Botón de cierre elegante estilo Horda
    local closeBtn = CreateFrame("Button", "ODD_MainCloseBtn", mainFrame, "UIPanelCloseButton")
    closeBtn:SetSize(32, 32)
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -20, -56)
    closeBtn:SetFrameLevel(mainFrame:GetFrameLevel() + 25)
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    mainFrame.CloseButton = closeBtn

    -- Contenedor interior de pestañas perfectamente encuadrado dentro del fondo negro de frame_4
    -- Pestañas subidas al interior del lienzo negro (BOTTOMLEFT a 70px)
    local contentFrame = CreateFrame("Frame", "ODD_DashboardContentFrame", mainFrame)
    contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, 36)
    contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 102)
    contentFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 2)
    Dashboard:EnableFrameDrag(contentFrame)

    -- Generar botones de pestañas (ancho ajustado a 104px para quedar holgadamente entre los postes verticales)
    local prevBtn = nil
    for i, def in ipairs(TAB_DEFS) do
        local btn = CreateFrame("Button", "ODD_TabBtn_" .. i, mainFrame)
        btn:SetID(i)
        btn:SetSize(104, 26)
        btn:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
        
        -- Textura de fondo mimetizada
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn)
        bg:SetColorTexture(0.12, 0.12, 0.12, 0.85)
        btn.bg = bg

        -- Borde sutil
        local border = btn:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        border:SetColorTexture(0.3, 0.1, 0.1, 0.6)

        -- Texto
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
        fs:SetText(L[def.labelKey] or def.name)
        btn.fs = fs

        if i == 1 then
            btn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 50, 70)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 3, 0)
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
    -- MARCO TEMÁTICO ORNAMENTAL HORDA (frame_4.png: 1600x1600)
    -- ========================================================
    -- Capa de fondo que dibuja la ilustración completa (marco de madera + fondo negro)
    -- Se ubica en BACKGROUND (subnivel -5) detrás del contentFrame para que los textos y estadísticas se pinten encima
    local hordeFrameTex = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -5)
    hordeFrameTex:SetTexture("Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Art\\frame_4.png")
    hordeFrameTex:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", -173, 340)
    hordeFrameTex:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 173, -316)
    mainFrame.hordeFrameTex = hordeFrameTex

    -- Frame interactivo que abarca todo el tamaño exterior de la imagen para permitir arrastre desde la madera
    local artDragFrame = CreateFrame("Frame", "ODD_ArtDragFrame", mainFrame)
    artDragFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", -173, 340)
    artDragFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 173, -316)
    artDragFrame:SetFrameLevel(mainFrame:GetFrameLevel() - 1)
    Dashboard:EnableFrameDrag(artDragFrame)

    SwitchTab(1)
    return mainFrame
end

function ODD.UI:Initialize()
    Dashboard:Create()
    if ODD.UI.MinimapBtn and ODD.UI.MinimapBtn.Initialize then
        ODD.UI.MinimapBtn:Initialize()
    end
    if ODD.UI.HUD and ODD.Database:GetSetting("showHUD") then
        ODD.UI.HUD:SetShown(true)
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
