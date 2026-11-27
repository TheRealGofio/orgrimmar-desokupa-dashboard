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

-- Paletas de color para cajas y paneles de información
HQTab.PALETTES = {
    classic = {
        name = "Horda Oscuro (Defecto)",
        border = { 0.30, 0.10, 0.10, 0.60 },
        bg = { 0.12, 0.12, 0.12, 0.65 },
        modelBorder = { 0.25, 0.12, 0.08, 0.50 },
        modelBg = { 0.06, 0.06, 0.06, 0.45 },
        barBg = { 0.20, 0.20, 0.20, 0.80 },
        hex = "FFAA3333",
    },
    crema = {
        name = "Crema / Pergamino",
        border = { 0.96, 0.90, 0.78, 0.85 }, -- #F5E6C8
        bg = { 0.18, 0.16, 0.14, 0.75 },
        modelBorder = { 0.96, 0.90, 0.78, 0.60 },
        modelBg = { 0.10, 0.09, 0.08, 0.55 },
        barBg = { 0.25, 0.22, 0.18, 0.85 },
        hex = "FFF5E6C8",
    },
    ambar = {
        name = "Ámbar Suave",
        border = { 0.91, 0.71, 0.29, 0.85 }, -- #E8B44A
        bg = { 0.20, 0.16, 0.10, 0.75 },
        modelBorder = { 0.91, 0.71, 0.29, 0.60 },
        modelBg = { 0.12, 0.09, 0.05, 0.55 },
        barBg = { 0.28, 0.22, 0.12, 0.85 },
        hex = "FFE8B44A",
    },
    hueso = {
        name = "Hueso Neutro",
        border = { 0.93, 0.89, 0.82, 0.85 }, -- #EDE3D0
        bg = { 0.16, 0.16, 0.15, 0.75 },
        modelBorder = { 0.93, 0.89, 0.82, 0.60 },
        modelBg = { 0.09, 0.09, 0.09, 0.55 },
        barBg = { 0.24, 0.23, 0.22, 0.85 },
        hex = "FFEDE3D0",
    },
}

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

-- Helper para crear tarjetas de estadísticas destacadas
local function CreateStatCard(parent, title, x, y, width, height)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, height)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(card)
    bg:SetColorTexture(0.12, 0.12, 0.12, 0.65)

    local border = card:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.3, 0.1, 0.1, 0.4)

    local tLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tLabel:SetPoint("TOP", card, "TOP", 0, -8)
    tLabel:SetText(title)

    local valLabel = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    valLabel:SetPoint("CENTER", card, "CENTER", 0, -6)
    valLabel:SetText("0")

    table.insert(registeredPanels, { bg = bg, border = border, kind = "card" })

    return valLabel
end

function HQTab:UpdateCardColors()
    local curKey = (ODD.Database and ODD.Database:GetSetting("cardColor")) or "classic"
    local p = HQTab.PALETTES[curKey] or HQTab.PALETTES.classic

    for _, item in ipairs(registeredPanels) do
        if item.kind == "card" then
            if item.bg and p.bg then
                item.bg:SetColorTexture(p.bg[1], p.bg[2], p.bg[3], p.bg[4])
            end
            if item.border and p.border then
                item.border:SetColorTexture(p.border[1], p.border[2], p.border[3], p.border[4])
            end
        elseif item.kind == "model" then
            if item.bg and p.modelBg then
                item.bg:SetColorTexture(p.modelBg[1], p.modelBg[2], p.modelBg[3], p.modelBg[4])
            end
            if item.border and p.modelBorder then
                item.border:SetColorTexture(p.modelBorder[1], p.modelBorder[2], p.modelBorder[3], p.modelBorder[4])
            end
        elseif item.kind == "contract" then
            if item.bg and p.bg then
                item.bg:SetColorTexture(p.bg[1], p.bg[2], p.bg[3], p.bg[4])
            end
            if item.border and p.border then
                item.border:SetColorTexture(p.border[1], p.border[2], p.border[3], p.border[4])
            end
            if item.barBg and p.barBg then
                item.barBg:SetColorTexture(p.barBg[1], p.barBg[2], p.barBg[3], p.barBg[4])
            end
        elseif item.kind == "profile" then
            if item.bg and p.bg then
                item.bg:SetColorTexture(p.bg[1], p.bg[2], p.bg[3], 0.55)
            end
            if item.border and p.border then
                item.border:SetColorTexture(p.border[1], p.border[2], p.border[3], p.border[4] * 0.7)
            end
        end
    end
end

function HQTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, "Panel General - Estadísticas de Desalojo", -10)

    -- Ficha del personaje local (lado izquierdo)
    local profileBox = CreateFrame("Frame", nil, frame)
    profileBox:SetSize(510, 48)
    profileBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    local pBg = profileBox:CreateTexture(nil, "BACKGROUND")
    pBg:SetAllPoints(profileBox)
    pBg:SetColorTexture(0.12, 0.12, 0.12, 0.5)

    local pBorder = profileBox:CreateTexture(nil, "BORDER")
    pBorder:SetPoint("TOPLEFT", profileBox, "TOPLEFT", 0, 0)
    pBorder:SetPoint("BOTTOMRIGHT", profileBox, "BOTTOMRIGHT", 0, 0)
    pBorder:SetColorTexture(0.25, 0.12, 0.08, 0.3)
    table.insert(registeredPanels, { bg = pBg, border = pBorder, kind = "profile" })

    pLabel = profileBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pLabel:SetPoint("TOPLEFT", profileBox, "TOPLEFT", 12, -8)
    pLabel:SetText("Cargando perfil...")

    local oLabel = profileBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    oLabel:SetPoint("BOTTOMLEFT", profileBox, "BOTTOMLEFT", 12, 8)
    oLabel:SetText("Origen: " .. L["STATUS_LOCAL_OBSERVED"])

    -- ========================================================
    -- MODELO 3D NATIVO DEL PERSONAJE
    -- ========================================================
    local modelFrame = CreateFrame("PlayerModel", "ODD_HQPlayerModel", frame)
    modelFrame:SetSize(210, 220)
    modelFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -10)
    modelFrame:SetFrameLevel(frame:GetFrameLevel() + 2)

    -- Fondo y marco sutil para realzar el modelo 3D
    local mBg = modelFrame:CreateTexture(nil, "BACKGROUND")
    mBg:SetAllPoints(modelFrame)
    mBg:SetColorTexture(0.06, 0.06, 0.06, 0.45)

    local mBorder = modelFrame:CreateTexture(nil, "BORDER")
    mBorder:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 0, 0)
    mBorder:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", 0, 0)
    mBorder:SetColorTexture(0.25, 0.12, 0.08, 0.5)
    table.insert(registeredPanels, { bg = mBg, border = mBorder, kind = "model" })

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
        local cBox = CreateFrame("Frame", nil, contractContainer)
        cBox:SetSize(370, 86)
        cBox:SetPoint("TOPLEFT", contractContainer, "TOPLEFT", (i == 1) and 0 or 390, 0)

        local cBg = cBox:CreateTexture(nil, "BACKGROUND")
        cBg:SetAllPoints(cBox)
        cBg:SetColorTexture(0.12, 0.12, 0.12, 0.6)

        local cBorder = cBox:CreateTexture(nil, "BORDER")
        cBorder:SetPoint("TOPLEFT", cBox, "TOPLEFT", 0, 0)
        cBorder:SetPoint("BOTTOMRIGHT", cBox, "BOTTOMRIGHT", 0, 0)
        cBorder:SetColorTexture(0.3, 0.1, 0.1, 0.4)

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
        barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
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

        table.insert(registeredPanels, { bg = cBg, border = cBorder, barBg = barBg, kind = "contract" })

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
