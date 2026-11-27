local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local HQTab = {}
ODD.UI.HQTab = HQTab

local pLabel = nil

-- Stat Cards
local statPersonalTotal = nil
local statGuildTotal = nil
local statTodayTotal = nil
local statWeekTotal = nil
local statAchievePoints = nil

-- Elementos de Contratos Semanales
local contractCards = {}
local contractTimerLabel = nil

-- Lista de tarjetas y bordes registrados para actualización en caliente
local registeredPanels = {}

function HQTab:RefreshPresence()
    -- Eliminado el mensaje de compañeros con ODD en línea según rediseño
end

-- Calcula eliminaciones locales (totales, hoy, esta semana) y de hermandad
function HQTab:CalculateStats()
    local charDB = ODD.Database:GetChar()
    local gnomes = charDB and charDB.observations and charDB.observations.gnomes
    local records = (gnomes and gnomes.records) or {}
    local personalTotal = (gnomes and gnomes.kills) or 0

    local now = time()
    local nowDate = date("*t", now)

    -- Inicio del día actual (00:00:00)
    local startOfToday = time({
        year = nowDate.year,
        month = nowDate.month,
        day = nowDate.day,
        hour = 0,
        min = 0,
        sec = 0
    })

    -- Inicio de la semana actual (Lunes a las 00:00:00)
    local daysSinceMonday = (nowDate.wday == 1) and 6 or (nowDate.wday - 2)
    local startOfWeek = startOfToday - (daysSinceMonday * 86400)

    local todayCount = 0
    local weekCount = 0

    for _, r in ipairs(records) do
        local stamp = r.timestamp or 0
        if stamp >= startOfToday then
            todayCount = todayCount + 1
        end
        if stamp >= startOfWeek then
            weekCount = weekCount + 1
        end
    end

    -- Total de hermandad: tu total propio + totales declarados por compañeros en ODDDB
    local guildTotal = personalTotal
    local myName = (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "Tú"
    local myFullName, myRealm = UnitFullName("player")
    local myCombinedName = (myFullName and myRealm and myRealm ~= "") and (myFullName .. "-" .. myRealm) or (myFullName or myName)

    local function IsMe(name)
        if not name then return false end
        if ODD.API and ODD.API.Forever and ODD.API.Forever.IsSamePlayer then
            if ODD.API.Forever:IsSamePlayer(name, myName) or ODD.API.Forever:IsSamePlayer(name, myCombinedName) then
                return true
            end
        end
        local cName = Ambiguate(name, "none"):lower()
        local cMyName = Ambiguate(myName, "none"):lower()
        local cComb = myCombinedName:lower()
        return (cName == cMyName) or (name:lower() == cComb) or (name:lower():find("^" .. cMyName)) or (cMyName:find("^" .. cName))
    end

    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.profiles then
        for name, profile in pairs(globalDB.profiles) do
            if not IsMe(name) and profile.gnomeKills and profile.gnomeKills > 0 then
                guildTotal = guildTotal + profile.gnomeKills
            end
        end
    end

    return {
        personalTotal = personalTotal,
        guildTotal = guildTotal,
        todayCount = todayCount,
        weekCount = weekCount,
    }
end

function HQTab:RefreshStats()
    local stats = self:CalculateStats()

    if statPersonalTotal then
        statPersonalTotal:SetText(string.format("|cFFFFD100%d|r", stats.personalTotal))
    end
    if statGuildTotal then
        statGuildTotal:SetText(string.format("|cFF00FFCC%d|r", stats.guildTotal))
    end
    if statTodayTotal then
        statTodayTotal:SetText(string.format("|cFF00FF00%d|r", stats.todayCount))
    end
    if statWeekTotal then
        statWeekTotal:SetText(string.format("|cFFFF8000%d|r", stats.weekCount))
    end

    if statAchievePoints then
        local myPts = 0
        if ODD.Achievements and ODD.Achievements.Medals then
            myPts = ODD.Achievements.Medals:GetPlayerAchievementPoints()
        end
        statAchievePoints:SetText(string.format("|cFF00FFCC%d|r", myPts))
    end
end

function HQTab:RefreshContracts()
    if not ODD.Guild or not ODD.Guild.Contracts then return end
    local progress = ODD.Guild.Contracts:GetProgress()

    if contractTimerLabel then
        contractTimerLabel:SetText(string.format("Reinicio en: |cFFFFD100%s|r", progress.timeRemaining or "--"))
    end

    local items = {
        { card = contractCards[1], data = progress.zone, kind = "TERRITORIAL" },
        { card = contractCards[2], data = progress.class, kind = "ESPECIALISTA" },
    }

    for _, it in ipairs(items) do
        local c = it.card
        local d = it.data
        if c and d then
            c.titleFs:SetText(string.format("|cFFFFFFFF%s|r", d.title or "Contrato"))
            c.badgeFs:SetText(it.kind == "TERRITORIAL" and ("|cFF00FFCC[ZONA: " .. (d.zone or "") .. "]|r") or ("|cFFFF8000[CLASE: Gnomo " .. (d.className or "") .. "]|r"))

            -- Barra y progreso
            local pStr = string.format("%d / %d (%d%%)", d.current or 0, d.target or 20, d.percent or 0)
            if d.isComplete then
                c.countFs:SetText("|cFF00FF00¡COMPLETADO!|r " .. pStr)
                c.fill:SetColorTexture(0.1, 0.8, 0.2, 0.9)
            else
                c.countFs:SetText(pStr)
                c.fill:SetColorTexture(0.85, 0.2, 0.1, 0.9)
            end

            local barMaxW = 280
            local w = math.max(2, math.floor((barMaxW * (d.percent or 0)) / 100))
            c.fill:SetWidth(w)
        end
    end
end

-- Helper para añadir florituras góticas/metálicas en las 4 esquinas de una caja
local function AttachCornerDecorations(frame)
    local corners = {}
    local size = 10
    local coords = {
        TL = { x = -2, y = 2,  coord = { 0.5, 0.625, 0.0, 0.125 } },
        TR = { x = 2,  y = 2,  coord = { 0.625, 0.5, 0.0, 0.125 } },
        BL = { x = -2, y = -2, coord = { 0.5, 0.625, 0.125, 0.0 } },
        BR = { x = 2,  y = -2, coord = { 0.625, 0.5, 0.125, 0.0 } },
    }

    local positions = {
        { "TOPLEFT", frame, "TOPLEFT", coords.TL.x, coords.TL.y, coords.TL.coord },
        { "TOPRIGHT", frame, "TOPRIGHT", coords.TR.x, coords.TR.y, coords.TR.coord },
        { "BOTTOMLEFT", frame, "BOTTOMLEFT", coords.BL.x, coords.BL.y, coords.BL.coord },
        { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", coords.BR.x, coords.BR.y, coords.BR.coord },
    }

    for _, p in ipairs(positions) do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
        tex:SetSize(size, size)
        tex:SetPoint(p[1], p[2], p[3], p[4], p[5])
        tex:SetTexCoord(p[6][1], p[6][2], p[6][3], p[6][4])
        table.insert(corners, tex)
    end
    return corners
end

-- Helper para crear tarjetas de estadísticas destacadas
local function CreateStatCard(parent, title, x, y, width, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    card:SetBackdropColor(0.0, 0.0, 0.0, 0.50) -- Fondo negro limpio y translúcido
    card:SetBackdropBorderColor(0.40, 0.10, 0.10, 0.80)

    local corners = AttachCornerDecorations(card)

    local tLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tLabel:SetPoint("TOP", card, "TOP", 0, -8)
    tLabel:SetText(title)

    local valLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    valLabel:SetPoint("CENTER", card, "CENTER", 0, -6)
    valLabel:SetText("0")

    table.insert(registeredPanels, { frame = card, corners = corners, kind = "card" })

    return valLabel
end

function HQTab:UpdateCardColors()
    local themePalette = ODD.UI.Dashboard and ODD.UI.Dashboard.GetActivePalette and ODD.UI.Dashboard:GetActivePalette()
    local borderRGBA, highlightRGB
    if themePalette and themePalette.tabBorder then
        borderRGBA = { themePalette.tabBorder[1], themePalette.tabBorder[2], themePalette.tabBorder[3], 0.85 }
        highlightRGB = themePalette.highlight or { borderRGBA[1], borderRGBA[2], borderRGBA[3] }
    else
        borderRGBA = { 0.45, 0.12, 0.12, 0.85 }
        highlightRGB = { 0.90, 0.25, 0.25 }
    end

    for _, item in ipairs(registeredPanels) do
        if item.frame and item.frame.SetBackdropBorderColor then
            item.frame:SetBackdropBorderColor(borderRGBA[1], borderRGBA[2], borderRGBA[3], borderRGBA[4])
            item.frame:SetBackdropColor(0.0, 0.0, 0.0, (item.kind == "model") and 0.40 or 0.50)
        end
        if item.corners then
            for _, cornerTex in ipairs(item.corners) do
                cornerTex:SetVertexColor(highlightRGB[1], highlightRGB[2], highlightRGB[3], 0.95)
            end
        end
        if item.barBg then
            item.barBg:SetColorTexture(0.12, 0.12, 0.14, 0.70)
        end
    end
end

function HQTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, "Panel General - Estadísticas de Desalojo", -10)

    -- Ficha del personaje local (lado izquierdo)
    local profileBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    profileBox:SetSize(510, 48)
    profileBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    profileBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    profileBox:SetBackdropColor(0.0, 0.0, 0.0, 0.45)
    profileBox:SetBackdropBorderColor(0.40, 0.10, 0.10, 0.70)
    local pCorners = AttachCornerDecorations(profileBox)
    table.insert(registeredPanels, { frame = profileBox, corners = pCorners, kind = "profile" })

    pLabel = profileBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pLabel:SetPoint("TOPLEFT", profileBox, "TOPLEFT", 12, -8)
    pLabel:SetText("Cargando perfil...")

    local oLabel = profileBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    oLabel:SetPoint("BOTTOMLEFT", profileBox, "BOTTOMLEFT", 12, 8)
    oLabel:SetText("Origen: " .. L["STATUS_LOCAL_OBSERVED"])

    -- ========================================================
    -- MODELO 3D NATIVO DEL PERSONAJE
    -- ========================================================
    local modelFrame = CreateFrame("PlayerModel", "ODD_HQPlayerModel", frame, "BackdropTemplate")
    modelFrame:SetSize(210, 220)
    modelFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -10)
    modelFrame:SetFrameLevel(frame:GetFrameLevel() + 2)

    modelFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    modelFrame:SetBackdropColor(0.0, 0.0, 0.0, 0.40)
    modelFrame:SetBackdropBorderColor(0.40, 0.10, 0.10, 0.70)
    local mCorners = AttachCornerDecorations(modelFrame)
    table.insert(registeredPanels, { frame = modelFrame, corners = mCorners, kind = "model" })

    local mHint = modelFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mHint:SetPoint("BOTTOM", modelFrame, "BOTTOM", 0, 4)
    mHint:SetText("|cFF666666Arrastra para rotar|r")

    local function UpdatePlayerModel()
        modelFrame:ClearModel()
        modelFrame:SetUnit("player")
        modelFrame:SetPortraitZoom(0)
        modelFrame:SetRotation(0)
    end

    modelFrame:EnableMouse(true)
    local isDragging = false
    local prevMouseX = 0
    modelFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            prevMouseX = GetCursorPosition()
        end
    end)
    modelFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            isDragging = false
        end
    end)
    modelFrame:SetScript("OnUpdate", function(self)
        if isDragging then
            local currentX = GetCursorPosition()
            local diff = (currentX - prevMouseX) * 0.02
            self:SetRotation(self:GetFacing() + diff)
            prevMouseX = currentX
        end
    end)

    -- ========================================================
    -- TARJETAS DE ESTADÍSTICAS Y PUNTOS DE LOGRO
    -- Fila superior (3 tarjetas): Tus Bajas Totales | Bajas Hermandad | Puntos de Logro
    -- Fila inferior (2 tarjetas): Bajas de Hoy | Bajas de Esta Semana
    -- ========================================================
    ODD.UI.Components:CreateSectionHeader(frame, "Resumen Global de Bajas y Logros:", -92)

    local cardW = 164
    local cardH = 60
    local cardGap = 9

    -- Fila 1 (Y: -116)
    statPersonalTotal = CreateStatCard(frame, "Tus Bajas Totales", 16, -116, cardW, cardH)
    statGuildTotal = CreateStatCard(frame, "Bajas de Hermandad", 16 + (cardW + cardGap) * 1, -116, cardW, cardH)
    statAchievePoints = CreateStatCard(frame, "Puntos de Logro", 16 + (cardW + cardGap) * 2, -116, cardW, cardH)

    -- Fila 2 (Y: -182)
    local cardW2 = 250
    statTodayTotal = CreateStatCard(frame, "Bajas de Hoy", 16, -182, cardW2, 48)
    statWeekTotal = CreateStatCard(frame, "Bajas de Esta Semana", 16 + cardW2 + 10, -182, cardW2, 48)

    if ODD.UI.Dashboard and ODD.UI.Dashboard.EnableFrameDrag then
        ODD.UI.Dashboard:EnableFrameDrag(profileBox)
    end

    -- ========================================================
    -- CONTRATOS SEMANALES DE HERMANDAD (OBJETIVOS DETERMINISTAS)
    -- ========================================================
    local contractSectionY = -242
    ODD.UI.Components:CreateSectionHeader(frame, "Contratos Semanales de Desalojo (Objetivos de Hermandad):", contractSectionY)

    contractTimerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    contractTimerLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, contractSectionY)
    contractTimerLabel:SetText("Reinicio en: --")

    local contractContainer = CreateFrame("Frame", nil, frame)
    contractContainer:SetSize(760, 95)
    contractContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, contractSectionY - 22)

    for i = 1, 2 do
        local cBox = CreateFrame("Frame", nil, contractContainer, "BackdropTemplate")
        cBox:SetSize(370, 86)
        cBox:SetPoint("TOPLEFT", contractContainer, "TOPLEFT", (i == 1) and 0 or 390, 0)

        cBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        cBox:SetBackdropColor(0.0, 0.0, 0.0, 0.50)
        cBox:SetBackdropBorderColor(0.40, 0.10, 0.10, 0.70)
        local cCorners = AttachCornerDecorations(cBox)

        -- Fila 1: Badge de Zona / Clase (arriba a la izquierda)
        local badgeFs = cBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        badgeFs:SetPoint("TOPLEFT", cBox, "TOPLEFT", 12, -9)
        badgeFs:SetText(i == 1 and "|cFF00FFCC[ZONA]|r" or "|cFFFF8000[CLASE]|r")
        cBox.badgeFs = badgeFs

        -- Fila 2: Nombre de la misión (debajo del badge, para que tenga todo el ancho)
        local titleFs = cBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        titleFs:SetPoint("TOPLEFT", badgeFs, "BOTTOMLEFT", 0, -4)
        titleFs:SetPoint("RIGHT", cBox, "RIGHT", -12, 0)
        titleFs:SetJustifyH("LEFT")
        titleFs:SetText("Cargando contrato...")
        cBox.titleFs = titleFs

        -- Fila 3: Barra de progreso y texto de bajas
        local barBg = cBox:CreateTexture(nil, "BACKGROUND")
        barBg:SetPoint("BOTTOMLEFT", cBox, "BOTTOMLEFT", 12, 12)
        barBg:SetSize(240, 12)
        barBg:SetColorTexture(0.12, 0.12, 0.14, 0.70)
        cBox.barBg = barBg

        local fill = cBox:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
        fill:SetSize(0, 12)
        fill:SetColorTexture(0.85, 0.2, 0.1, 0.9)
        cBox.fill = fill

        local countFs = cBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countFs:SetPoint("LEFT", barBg, "RIGHT", 8, 0)
        countFs:SetText("0 / 20 (0%)")
        cBox.countFs = countFs

        table.insert(registeredPanels, { frame = cBox, corners = cCorners, barBg = barBg, kind = "contract" })

        contractCards[i] = cBox
    end

    local function Refresh()
        if ODD.Network and ODD.Network.Sync then
            ODD.Network.Sync:RequestGuildSync()
        end

        local profile = ODD.Guild.Profiles:GetLocalProfile()
        local roleText = profile.customRole and string.format(" [%s]", profile.customRole) or ""
        local pText = string.format("Personaje: |cFFFFD100%s%s|r   •   Clase: |cFFFFD100%s|r   •   Nivel: |cFFFFD100%s|r", 
            profile.name or (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "Desconocido", 
            roleText,
            profile.class or select(2, UnitClass("player")) or "Desconocido", 
            tostring(profile.level or UnitLevel("player") or "?"))
        pLabel:SetText(pText)

        HQTab:RefreshStats()
        HQTab:RefreshContracts()
        HQTab:UpdateCardColors()
        UpdatePlayerModel()
    end

    frame:SetScript("OnShow", Refresh)
    Refresh()

    return frame
end
