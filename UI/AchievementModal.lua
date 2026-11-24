local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Modal = {}
ODD.UI = ODD.UI or {}
ODD.UI.AchievementModal = Modal

local modalFrame = nil

local function EnsureModalFrame()
    if modalFrame then return modalFrame end

    modalFrame = CreateFrame("Frame", "ODD_AchievementModalFrame", UIParent, "BackdropTemplate")
    modalFrame:SetSize(460, 115)
    modalFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    modalFrame:SetFrameStrata("DIALOG")
    modalFrame:SetClampedToScreen(true)
    modalFrame:SetMovable(true)
    modalFrame:EnableMouse(true)
    modalFrame:RegisterForDrag("LeftButton")
    modalFrame:SetScript("OnDragStart", modalFrame.StartMoving)
    modalFrame:SetScript("OnDragStop", modalFrame.StopMovingOrSizing)

    -- Fondo translúcido oscuro con tono Horda / Forja
    local bg = modalFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(modalFrame)
    bg:SetColorTexture(0.08, 0.04, 0.04, 0.96)
    modalFrame.bg = bg

    -- Borde dorado de logro de WoW
    modalFrame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
    })
    modalFrame:SetBackdropBorderColor(1, 0.82, 0, 0.95)

    -- Icono del logro con marco circular/cuadrado
    local icon = modalFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(54, 54)
    icon:SetPoint("LEFT", modalFrame, "LEFT", 14, 0)
    modalFrame.icon = icon

    -- Borde del icono
    local iconBorder = modalFrame:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(58, 58)
    iconBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
    iconBorder:SetColorTexture(0.3, 0.2, 0.05, 0.6)

    -- Cabecera dorada estilo Retail: "LOGRO DE HERMANDAD • [Puntos]"
    local headerFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerFs:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
    headerFs:SetText("|cFFFFD100LOGRO DE HERMANDAD|r")
    modalFrame.headerFs = headerFs

    -- Puntos de logro (esquina superior derecha, estilo escudo retail)
    local pointsFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pointsFs:SetPoint("TOPRIGHT", modalFrame, "TOPRIGHT", -36, -10)
    pointsFs:SetText("|cFF00FFCC+10 pts|r")
    modalFrame.pointsFs = pointsFs

    -- Título del logro (Nombre de la medalla)
    local titleFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    titleFs:SetPoint("TOPLEFT", headerFs, "BOTTOMLEFT", 0, -3)
    titleFs:SetPoint("RIGHT", modalFrame, "RIGHT", -36, 0)
    titleFs:SetJustifyH("LEFT")
    titleFs:SetText("Nombre del Logro")
    modalFrame.titleFs = titleFs

    -- Descripción de la hazaña
    local descFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    descFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -4)
    descFs:SetPoint("RIGHT", modalFrame, "RIGHT", -16, 0)
    descFs:SetJustifyH("LEFT")
    descFs:SetSpacing(2)
    descFs:SetText("Descripción del logro.")
    modalFrame.descFs = descFs

    -- Pie: "Conseguido por [Jugador] el [Fecha / Hora]"
    local footerFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerFs:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 14, 2)
    footerFs:SetPoint("RIGHT", modalFrame, "RIGHT", -16, 0)
    footerFs:SetJustifyH("LEFT")
    footerFs:SetText("Conseguido por...")
    modalFrame.footerFs = footerFs

    -- Botón de cerrar (X) en la esquina superior derecha
    local closeBtn = CreateFrame("Button", nil, modalFrame)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", modalFrame, "TOPRIGHT", -6, -6)
    local closeFs = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeFs:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeFs:SetText("|cFF888888X|r")
    closeBtn:SetScript("OnEnter", function() closeFs:SetText("|cFFFF2020X|r") end)
    closeBtn:SetScript("OnLeave", function() closeFs:SetText("|cFF888888X|r") end)
    closeBtn:SetScript("OnClick", function()
        modalFrame:Hide()
    end)

    modalFrame:Hide()
    return modalFrame
end

-- Muestra el modal detallado del logro estilo Retail
function Modal:Show(medalId, playerName, timestamp, points)
    local f = EnsureModalFrame()

    local medalDef = ODD.Achievements and ODD.Achievements.Medals and ODD.Achievements.Medals:GetMedalByID(medalId)
    local name = medalDef and medalDef.name or "Hazaña Desokupa"
    local desc = medalDef and medalDef.desc or "Hazaña de exterminio de gnomos en mundo abierto."
    local icon = medalDef and medalDef.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    local pts = points or (medalDef and medalDef.points) or 10

    f.icon:SetTexture(icon)
    f.titleFs:SetText(string.format("|cFFFFFFFF%s|r", name))
    f.descFs:SetText(desc)
    f.pointsFs:SetText(string.format("|cFF00FFCC+%d pts|r", pts))

    local pName = playerName or (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "Compañero"
    local dateStr = date("%d/%m/%Y a las %H:%M", timestamp or time())

    f.footerFs:SetText(string.format("Conseguido por |cFFFFD100%s|r el |cFF888888%s|r", pName, dateStr))

    f:Show()
end
