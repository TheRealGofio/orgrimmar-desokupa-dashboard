local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local HUD = {}
ODD.UI = ODD.UI or {}
ODD.UI.HUD = HUD

local hudFrame = nil

function HUD:Create()
    if hudFrame then return hudFrame end

    -- Dimensiones del marco del HUD (380x95 para dar amplitud, nitidez y holgura al diseño)
    hudFrame = CreateFrame("Frame", "ODD_HUDFrame", UIParent)
    hudFrame:SetSize(380, 95)
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

    -- Textura Horda generada (hud_banner_2.png)
    local bgTex = hudFrame:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(hudFrame)
    bgTex:SetTexture("Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Art\\hud_banner_2.png")
    bgTex:SetTexCoord(0, 1, 0, 1)
    hudFrame.bgTex = bgTex

    -- Botón de cerrar HUD (X) situado discretamente en la esquina metálica
    local closeBtn = CreateFrame("Button", nil, hudFrame)
    closeBtn:SetSize(14, 14)
    closeBtn:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", -56, -20)
    local closeFs = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeFs:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeFs:SetText("|cFF888888X|r")
    closeBtn:SetScript("OnEnter", function() closeFs:SetText("|cFFFF2020X|r") end)
    closeBtn:SetScript("OnLeave", function() closeFs:SetText("|cFF888888X|r") end)
    closeBtn:SetScript("OnClick", function()
        HUD:SetShown(false)
    end)

    -- Columna Izquierda - Fila 1: Hoy (dentro de la zona oscura libre de tela roja)
    local labelToday = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelToday:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 82, -36)
    labelToday:SetText("|cFFB0B0B0Hoy:|r")
    labelToday:SetShadowColor(0, 0, 0, 1)
    labelToday:SetShadowOffset(1, -1)

    local valToday = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valToday:SetPoint("LEFT", labelToday, "RIGHT", 5, 0)
    valToday:SetText("|cFF00FF000|r")
    valToday:SetShadowColor(0, 0, 0, 1)
    valToday:SetShadowOffset(1, -1)
    hudFrame.valToday = valToday

    -- Columna Derecha - Fila 1: Semana
    local labelWeek = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelWeek:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 204, -36)
    labelWeek:SetText("|cFFB0B0B0Semana:|r")
    labelWeek:SetShadowColor(0, 0, 0, 1)
    labelWeek:SetShadowOffset(1, -1)

    local valWeek = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valWeek:SetPoint("LEFT", labelWeek, "RIGHT", 5, 0)
    valWeek:SetText("|cFFFF80000|r")
    valWeek:SetShadowColor(0, 0, 0, 1)
    valWeek:SetShadowOffset(1, -1)
    hudFrame.valWeek = valWeek

    -- Columna Izquierda - Fila 2: Mis Bajas
    local labelPersonal = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelPersonal:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 82, -56)
    labelPersonal:SetText("|cFFB0B0B0Tus Bajas:|r")
    labelPersonal:SetShadowColor(0, 0, 0, 1)
    labelPersonal:SetShadowOffset(1, -1)

    local valPersonal = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valPersonal:SetPoint("LEFT", labelPersonal, "RIGHT", 5, 0)
    valPersonal:SetText("|cFFFFD1000|r")
    valPersonal:SetShadowColor(0, 0, 0, 1)
    valPersonal:SetShadowOffset(1, -1)
    hudFrame.valPersonal = valPersonal

    -- Columna Derecha - Fila 2: Hermandad
    local labelGuild = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelGuild:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 204, -56)
    labelGuild:SetText("|cFFB0B0B0Hermandad:|r")
    labelGuild:SetShadowColor(0, 0, 0, 1)
    labelGuild:SetShadowOffset(1, -1)

    local valGuild = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valGuild:SetPoint("LEFT", labelGuild, "RIGHT", 5, 0)
    valGuild:SetText("|cFF00FFCC0|r")
    valGuild:SetShadowColor(0, 0, 0, 1)
    valGuild:SetShadowOffset(1, -1)
    hudFrame.valGuild = valGuild

    -- Clic derecho abre/cierra el panel principal
    hudFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if ODD.UI and ODD.UI.Toggle then
                ODD.UI:Toggle()
            end
        end
    end)

    -- Tooltip informativo al pasar el ratón
    hudFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("ODD - Panel Rápido", 1, 0.82, 0)
        GameTooltip:AddLine("Arrastra con Clic Izquierdo para mover.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Clic Derecho para abrir el Dashboard.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    hudFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
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

    hudFrame.valToday:SetText(string.format("|cFF00FF00%d|r", todayCount))
    hudFrame.valWeek:SetText(string.format("|cFFFF8000%d|r", weekCount))
    hudFrame.valPersonal:SetText(string.format("|cFFFFD100%d|r", personalTotal))
    hudFrame.valGuild:SetText(string.format("|cFF00FFCC%d|r", guildTotal))
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
