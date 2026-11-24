local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local HQTab = {}
ODD.UI.HQTab = HQTab

local pLabel = nil
local peerStatus = nil

-- Stat Cards
local statPersonalTotal = nil
local statGuildTotal = nil
local statTodayTotal = nil
local statWeekTotal = nil

-- Elementos de Contratos Semanales
local contractCards = {}
local contractTimerLabel = nil

local lastKillDetails = nil
local topKillersList = nil

function HQTab:RefreshPresence()
    if not ODD.Network or not ODD.Network.Sync or not peerStatus then return end
    local peers = ODD.Network.Sync:GetOnlinePeers()
    local count = 0
    local names = {}
    for name, _ in pairs(peers) do
        count = count + 1
        table.insert(names, name)
    end
    if count == 0 then
        peerStatus:SetText("Compañeros con ODD en línea: 0")
    else
        peerStatus:SetText(string.format("Compañeros con ODD en línea: |cFF00FF00%d|r (%s)", count, table.concat(names, ", ")))
    end
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
    -- wday: 1 = Domingo, 2 = Lunes, ..., 7 = Sábado
    local daysSinceMonday = (nowDate.wday == 1) and 6 or (nowDate.wday - 2)
    local startOfWeek = startOfToday - (daysSinceMonday * 86400)

    local todayCount = 0
    local weekCount = 0
    local lastRecord = nil

    for _, r in ipairs(records) do
        local stamp = r.timestamp or 0
        if stamp >= startOfToday then
            todayCount = todayCount + 1
        end
        if stamp >= startOfWeek then
            weekCount = weekCount + 1
        end
        if not lastRecord or stamp > (lastRecord.timestamp or 0) then
            lastRecord = r
        end
    end

    -- Total de hermandad: tu total propio + totales declarados por compañeros en ODDDB
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

    local topContributors = {
        { name = myName, kills = personalTotal, isSelf = true }
    }

    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.profiles then
        for name, profile in pairs(globalDB.profiles) do
            if not IsMe(name) and profile.gnomeKills and profile.gnomeKills > 0 then
                guildTotal = guildTotal + profile.gnomeKills
                table.insert(topContributors, {
                    name = name,
                    kills = profile.gnomeKills,
                    isSelf = false
                })
            end
        end
    end

    table.sort(topContributors, function(a, b) return a.kills > b.kills end)

    return {
        personalTotal = personalTotal,
        guildTotal = guildTotal,
        todayCount = todayCount,
        weekCount = weekCount,
        lastRecord = lastRecord,
        topContributors = topContributors,
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

    if lastKillDetails then
        if stats.lastRecord then
            local r = stats.lastRecord
            local dateStr = date("%Y-%m-%d %H:%M", r.timestamp or time())
            local extra = ""
            if r.victimName then
                extra = string.format(" - |cFFFFD100%s|r (%s Nivel %s)", r.victimName, r.victimClass or "?", tostring(r.victimLevel or "?"))
            end
            lastKillDetails:SetText(string.format("Último desalojo: %s en |cFFFFFFFF%s|r%s", dateStr, r.zone or "Mundo Abierto", extra))
        else
            lastKillDetails:SetText("Último desalojo: Ninguna baja registrada aún.")
        end
    end

    if topKillersList then
        local lines = {}
        for i = 1, math.min(6, #stats.topContributors) do
            local c = stats.topContributors[i]
            local tag = c.isSelf and " |cFF888888(Tú)|r" or ""
            table.insert(lines, string.format("%d. |cFFFFFFFF%s|r%s: |cFFFFD100%d|r bajas", i, c.name, tag, c.kills))
        end
        topKillersList:SetText(table.concat(lines, "\n"))
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

            local barMaxW = 220
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

    return valLabel
end

function HQTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, "Panel General - Estadísticas de Desalojo", -12)

    -- Ficha del personaje local
    local profileBox = CreateFrame("Frame", nil, frame)
    profileBox:SetSize(620, 48)
    profileBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    local pBg = profileBox:CreateTexture(nil, "BACKGROUND")
    pBg:SetAllPoints(profileBox)
    pBg:SetColorTexture(0.12, 0.12, 0.12, 0.5)

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
    modelFrame:SetSize(100, 100)
    modelFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -18)
    modelFrame:SetFrameLevel(frame:GetFrameLevel() + 2)

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

    -- Estado de sincronización P2P
    local syncBox = CreateFrame("Frame", nil, frame)
    syncBox:SetSize(620, 24)
    syncBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -90)

    local pulseDot = syncBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pulseDot:SetPoint("LEFT", syncBox, "LEFT", 0, 0)
    pulseDot:SetText("|cFF00FF00[SYNC P2P]|r")

    peerStatus = syncBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    peerStatus:SetPoint("LEFT", pulseDot, "RIGHT", 8, 0)
    peerStatus:SetText("Compañeros con ODD en línea: 0")

    -- ========================================================
    -- 4 TARJETAS GRANDES DE ESTADÍSTICAS
    -- ========================================================
    ODD.UI.Components:CreateSectionHeader(frame, "Resumen Global de Bajas:", -124)

    local cardWidth = 180
    local cardHeight = 65
    local cardSpacing = 13

    statPersonalTotal = CreateStatCard(frame, "Tus Bajas Totales", 16, -150, cardWidth, cardHeight)
    statGuildTotal = CreateStatCard(frame, "Bajas de Hermandad", 16 + (cardWidth + cardSpacing) * 1, -150, cardWidth, cardHeight)
    statTodayTotal = CreateStatCard(frame, "Bajas de Hoy", 16 + (cardWidth + cardSpacing) * 2, -150, cardWidth, cardHeight)
    statWeekTotal = CreateStatCard(frame, "Bajas de Esta Semana", 16 + (cardWidth + cardSpacing) * 3, -150, cardWidth, cardHeight)

    if ODD.UI.Dashboard and ODD.UI.Dashboard.EnableFrameDrag then
        ODD.UI.Dashboard:EnableFrameDrag(profileBox)
        ODD.UI.Dashboard:EnableFrameDrag(syncBox)
    end

    -- ========================================================
    -- CONTRATOS SEMANALES DE HERMANDAD (P2P DETERMINISTAS)
    -- ========================================================
    local contractSectionY = -228
    local cHeader = ODD.UI.Components:CreateSectionHeader(frame, "Contratos Semanales de Desalojo (Objetivos de Hermandad):", contractSectionY)

    contractTimerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    contractTimerLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, contractSectionY)
    contractTimerLabel:SetText("Reinicio en: --")

    local contractContainer = CreateFrame("Frame", nil, frame)
    contractContainer:SetSize(760, 76)
    contractContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, contractSectionY - 20)

    for i = 1, 2 do
        local cBox = CreateFrame("Frame", nil, contractContainer)
        cBox:SetSize(370, 72)
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
        badgeFs:SetPoint("TOPLEFT", cBox, "TOPLEFT", 10, -7)
        badgeFs:SetText(i == 1 and "|cFF00FFCC[ZONA]|r" or "|cFFFF8000[CLASE]|r")
        cBox.badgeFs = badgeFs

        -- Fila 2: Nombre de la misión (debajo del badge, para que tenga todo el ancho)
        local titleFs = cBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        titleFs:SetPoint("TOPLEFT", badgeFs, "BOTTOMLEFT", 0, -2)
        titleFs:SetPoint("RIGHT", cBox, "RIGHT", -10, 0)
        titleFs:SetJustifyH("LEFT")
        titleFs:SetText("Cargando contrato...")
        cBox.titleFs = titleFs

        -- Fila 3: Barra de progreso y texto de bajas
        local barBg = cBox:CreateTexture(nil, "BACKGROUND")
        barBg:SetPoint("BOTTOMLEFT", cBox, "BOTTOMLEFT", 10, 10)
        barBg:SetSize(220, 10)
        barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        cBox.barBg = barBg

        local fill = cBox:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
        fill:SetSize(0, 10)
        fill:SetColorTexture(0.85, 0.2, 0.1, 0.9)
        cBox.fill = fill

        local countFs = cBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countFs:SetPoint("LEFT", barBg, "RIGHT", 8, 0)
        countFs:SetText("0 / 20 (0%)")
        cBox.countFs = countFs

        contractCards[i] = cBox
    end

    -- ========================================================
    -- DETALLES ADICIONALES Y CONTRIBUCIÓN
    -- ========================================================
    local bottomBox = CreateFrame("Frame", nil, frame)
    bottomBox:SetSize(760, 90)
    bottomBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -326)
    local bBg = bottomBox:CreateTexture(nil, "BACKGROUND")
    bBg:SetAllPoints(bottomBox)
    bBg:SetColorTexture(0.08, 0.08, 0.08, 0.6)

    -- Última baja
    lastKillDetails = bottomBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lastKillDetails:SetPoint("TOPLEFT", bottomBox, "TOPLEFT", 14, -10)
    lastKillDetails:SetText("Último desalojo: Calculando...")

    -- Subcabecera contribución
    local contribHeader = bottomBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    contribHeader:SetPoint("TOPLEFT", bottomBox, "TOPLEFT", 14, -34)
    contribHeader:SetText("|cFFFFD100Máximos Exterminadores de la Hermandad:|r")

    -- Lista Top 6
    topKillersList = bottomBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    topKillersList:SetPoint("TOPLEFT", bottomBox, "TOPLEFT", 14, -54)
    topKillersList:SetJustifyH("LEFT")
    topKillersList:SetSpacing(2)
    topKillersList:SetText("1. Tú: 0 bajas")

    local function Refresh()
        if ODD.Network and ODD.Network.Sync then
            ODD.Network.Sync:RequestGuildSync()
        end

        local profile = ODD.Guild.Profiles:GetLocalProfile()
        local roleText = profile.customRole and string.format(" [%s]", profile.customRole) or ""
        local myPts = 0
        if ODD.Achievements and ODD.Achievements.Medals then
            myPts = ODD.Achievements.Medals:GetPlayerAchievementPoints()
        end
        local pText = string.format("Personaje: |cFFFFD100%s%s|r  •  Clase: |cFFFFD100%s|r  •  Nivel: |cFFFFD100%s|r  •  Puntos de Logro: |cFF00FFCC%d pts|r", 
            profile.name or UnitName("player") or "Desconocido", 
            roleText,
            profile.class or select(2, UnitClass("player")) or "Desconocido", 
            tostring(profile.level or UnitLevel("player") or "?"),
            myPts)
        pLabel:SetText(pText)

        HQTab:RefreshPresence()
        HQTab:RefreshStats()
        HQTab:RefreshContracts()
        UpdatePlayerModel()
    end

    frame:SetScript("OnShow", Refresh)
    Refresh()

    return frame
end
