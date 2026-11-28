local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Modal = {}
ODD.UI = ODD.UI or {}
ODD.UI.AchievementModal = Modal

local modalFrame = nil

local function EnsureModalFrame()
    if modalFrame then return modalFrame end

    modalFrame = CreateFrame("Frame", "ODD_AchievementModalFrame", UIParent, "BackdropTemplate")
    modalFrame:SetSize(490, 168)
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

    -- Icono del logro con marco
    local icon = modalFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(52, 52)
    icon:SetPoint("TOPLEFT", modalFrame, "TOPLEFT", 16, -16)
    modalFrame.icon = icon

    -- Borde sutil del icono
    local iconBorder = modalFrame:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(56, 56)
    iconBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
    iconBorder:SetColorTexture(0.3, 0.2, 0.05, 0.6)

    -- Cabecera dorada estilo Retail: "LOGRO DE HERMANDAD"
    local headerFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerFs:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
    headerFs:SetText("|cFFFFD100LOGRO DE HERMANDAD|r")
    modalFrame.headerFs = headerFs

    -- Puntos de logro (esquina superior derecha, estilo escudo retail)
    local pointsFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pointsFs:SetPoint("TOPRIGHT", modalFrame, "TOPRIGHT", -36, -14)
    pointsFs:SetText("|cFF00FFCC+10 pts|r")
    modalFrame.pointsFs = pointsFs

    -- Título del logro (Nombre de la medalla)
    local titleFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    titleFs:SetPoint("TOPLEFT", headerFs, "BOTTOMLEFT", 0, -5)
    titleFs:SetPoint("RIGHT", pointsFs, "LEFT", -10, 0)
    titleFs:SetJustifyH("LEFT")
    titleFs:SetText("Nombre del Logro")
    modalFrame.titleFs = titleFs

    -- Descripción de la hazaña (con suficiente separación y altura)
    local descFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    descFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -6)
    descFs:SetPoint("RIGHT", modalFrame, "RIGHT", -20, 0)
    descFs:SetJustifyH("LEFT")
    descFs:SetSpacing(3)
    descFs:SetText("Descripción del logro.")
    modalFrame.descFs = descFs

    -- Barra de progreso visual dentro del modal
    local barContainer = CreateFrame("Frame", nil, modalFrame)
    barContainer:SetSize(450, 18)
    barContainer:SetPoint("TOPLEFT", descFs, "BOTTOMLEFT", 0, -10)
    modalFrame.barContainer = barContainer

    local barBg = barContainer:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(barContainer)
    barBg:SetColorTexture(0.12, 0.12, 0.14, 0.90)
    modalFrame.barBg = barBg

    local barFill = barContainer:CreateTexture(nil, "ARTWORK")
    barFill:SetPoint("LEFT", barContainer, "LEFT", 0, 0)
    barFill:SetSize(0, 18)
    barFill:SetColorTexture(0.85, 0.45, 0.10, 0.95)
    modalFrame.barFill = barFill

    local barText = barContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barText:SetPoint("CENTER", barContainer, "CENTER", 0, 0)
    barText:SetText("0 / 10 (0%)")
    modalFrame.barText = barText

    -- Línea divisoria sutil antes del pie
    local divider = modalFrame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("BOTTOMLEFT", modalFrame, "BOTTOMLEFT", 16, 34)
    divider:SetPoint("BOTTOMRIGHT", modalFrame, "BOTTOMRIGHT", -16, 34)
    divider:SetHeight(1)
    divider:SetColorTexture(1, 0.82, 0, 0.25)

    -- Pie: "Conseguido por [Jugador] el [Fecha / Hora]" o progreso
    local footerFs = modalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerFs:SetPoint("BOTTOMLEFT", modalFrame, "BOTTOMLEFT", 18, 12)
    footerFs:SetPoint("BOTTOMRIGHT", modalFrame, "BOTTOMRIGHT", -18, 12)
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
function Modal:Show(medalId, playerName, timestamp, points, currentProg, maxGoal)
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
    
    local ts = tonumber(timestamp) or 0
    local prog = tonumber(currentProg)
    local goal = tonumber(maxGoal)

    -- Si no vienen prog o goal por chat, intentar deducir el progreso local si es propio o existe la definición
    if not prog and medalDef then
        goal = medalDef.req or medalDef.reqClassCount or medalDef.reqZoneCount or medalDef.reqGray or medalDef.reqEating or medalDef.reqMounted or medalDef.reqGuildGroup or medalDef.reqSessionKills or medalDef.reqBG or 1
        if ts > 0 then
            prog = goal
        else
            prog = 0
        end
    end

    goal = (goal and goal > 0) and goal or 1
    prog = prog or (ts > 0 and goal or 0)
    prog = math.min(prog, goal)

    local totalWidth = 450
    local pct = math.min(1, math.max(0, prog / goal))
    f.barFill:SetWidth(math.floor(totalWidth * pct))

    if ts > 0 or prog >= goal then
        local dateStr = (ts > 0) and date("%d/%m/%Y a las %H:%M", ts) or "Recientemente"
        f.barFill:SetColorTexture(0.15, 0.65, 0.15, 0.95) -- Verde completado
        f.barText:SetText(string.format("|cFFFFFFFFCompletado (%d / %d)|r", goal, goal))
        f.footerFs:SetText(string.format("Conseguido por |cFFFFD100%s|r el |cFF888888%s|r", pName, dateStr))
    else
        f.barFill:SetColorTexture(0.85, 0.45, 0.10, 0.95) -- Naranja en curso
        f.barText:SetText(string.format("|cFFFFD100Progreso: %d / %d (%.0f%%)|r", prog, goal, pct * 100))
        f.footerFs:SetText(string.format("Compartido por |cFFFFD100%s|r (|cFFFF8000En progreso: %d/%d|r)", pName, prog, goal))
    end

    f:Show()
end
