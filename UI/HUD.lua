local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local HUD = {}
ODD.UI = ODD.UI or {}
ODD.UI.HUD = HUD

local hudFrame = nil

function HUD:Create()
    if hudFrame then return hudFrame end

    hudFrame = CreateFrame("Frame", "ODD_HUDFrame", UIParent)
    hudFrame:SetSize(220, 68)
    hudFrame:SetFrameStrata("MEDIUM")
    hudFrame:SetClampedToScreen(true)
    hudFrame:SetMovable(true)
    hudFrame:EnableMouse(true)
    hudFrame:RegisterForDrag("LeftButton")

    -- Restaurar posición guardada o anclar arriba centrado por defecto
    hudFrame:SetPoint("TOP", UIParent, "TOP", 0, -80)

    hudFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    hudFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Guardar coordenadas
        local point, _, relPoint, x, y = self:GetPoint()
        local globalDB = ODD.Database:GetGlobal()
        if globalDB then
            globalDB.settings = globalDB.settings or {}
            globalDB.settings.hudPos = { point = point, relPoint = relPoint, x = x, y = y }
            _G["ODDDB"] = globalDB
        end
    end)

    -- Fondo translúcido oscuro con borde sutil Horda
    local bg = hudFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(hudFrame)
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.75)
    hudFrame.bg = bg

    local border = hudFrame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.4, 0.1, 0.1, 0.6)

    -- Cabecera / Título
    local title = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 8, -6)
    title:SetText("|cFFFFD100ODD - Orgrimmar Desokupa|r")
    hudFrame.title = title

    -- Botón de cerrar HUD (X)
    local closeBtn = CreateFrame("Button", nil, hudFrame)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", -4, -4)
    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints()
    closeBg:SetColorTexture(0.6, 0.1, 0.1, 0.8)
    local closeFs = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeFs:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeFs:SetText("X")
    closeBtn:SetScript("OnClick", function()
        HUD:SetShown(false)
    end)

    -- Línea 1: Bajas de hoy y de la semana
    local line1 = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line1:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 8, -26)
    line1:SetText("Hoy: |cFF00FF000|r   •   Semana: |cFFFF80000|r")
    hudFrame.line1 = line1

    -- Línea 2: Total personal y de hermandad
    local line2 = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line2:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 8, -44)
    line2:SetText("Total: |cFFFFD1000|r   •   Guild: |cFF00FFCC0|r")
    hudFrame.line2 = line2

    -- Clic derecho abre/cierra el panel principal
    hudFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if ODD.UI and ODD.UI.Toggle then
                ODD.UI:Toggle()
            end
        end
    end)

    -- Restaurar posición previa si existe en DB
    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.settings and globalDB.settings.hudPos then
        local p = globalDB.settings.hudPos
        hudFrame:ClearAllPoints()
        hudFrame:SetPoint(p.point or "TOP", UIParent, p.relPoint or "TOP", p.x or 0, p.y or -80)
    end

    hudFrame:Hide()
    return hudFrame
end

function HUD:Refresh()
    if not hudFrame or not hudFrame:IsShown() then return end

    local charDB = ODD.Database:GetChar()
    local gnomes = charDB and charDB.observations and charDB.observations.gnomes
    local records = (gnomes and gnomes.records) or {}
    local personalTotal = (gnomes and gnomes.kills) or 0

    local now = time()
    local nowDate = date("*t", now)
    local startOfToday = time({ year = nowDate.year, month = nowDate.month, day = nowDate.day, hour = 0, min = 0, sec = 0 })
    local daysSinceMonday = (nowDate.wday == 1) and 6 or (nowDate.wday - 2)
    local startOfWeek = startOfToday - (daysSinceMonday * 86400)

    local todayCount = 0
    local weekCount = 0
    for _, r in ipairs(records) do
        local stamp = r.timestamp or 0
        if stamp >= startOfToday then todayCount = todayCount + 1 end
        if stamp >= startOfWeek then weekCount = weekCount + 1 end
    end

    local guildTotal = personalTotal
    local myName = UnitName("player") or "Tú"
    local myFullName, myRealm = UnitFullName("player")
    local myCombinedName = (myFullName and myRealm and myRealm ~= "") and (myFullName .. "-" .. myRealm) or (myFullName or myName)

    local function IsMe(name)
        if not name then return false end
        local cName = Ambiguate(name, "none"):lower()
        local cMyName = Ambiguate(myName, "none"):lower()
        local cComb = myCombinedName:lower()
        return (cName == cMyName) or (name:lower() == cComb) or (name:lower():find("^" .. cMyName))
    end

    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.profiles then
        for name, profile in pairs(globalDB.profiles) do
            if not IsMe(name) and profile.gnomeKills and profile.gnomeKills > 0 then
                guildTotal = guildTotal + profile.gnomeKills
            end
        end
    end

    hudFrame.line1:SetText(string.format("Hoy: |cFF00FF00%d|r   •   Semana: |cFFFF8000%d|r", todayCount, weekCount))
    hudFrame.line2:SetText(string.format("Tus Bajas: |cFFFFD100%d|r   •   Guild: |cFF00FFCC%d|r", personalTotal, guildTotal))
end

function HUD:SetShown(show)
    local f = self:Create()
    if show then
        f:Show()
        self:Refresh()
        ODD.Database:SetSetting("showHUD", true)
    else
        f:Hide()
        ODD.Database:SetSetting("showHUD", false)
    end
end

function HUD:Toggle()
    local f = self:Create()
    self:SetShown(not f:IsShown())
end
