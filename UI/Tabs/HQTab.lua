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
    local topContributors = {
        { name = myName, kills = personalTotal, isSelf = true }
    }

    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.profiles then
        for name, profile in pairs(globalDB.profiles) do
            if name ~= myName and profile.gnomeKills and profile.gnomeKills > 0 then
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
    profileBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
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
    modelFrame:SetSize(115, 115)
    modelFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -26)
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

    -- ========================================================
    -- DETALLES ADICIONALES Y CONTRIBUCIÓN
    -- ========================================================
    local bottomBox = CreateFrame("Frame", nil, frame)
    bottomBox:SetSize(760, 190)
    bottomBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -228)
    local bBg = bottomBox:CreateTexture(nil, "BACKGROUND")
    bBg:SetAllPoints(bottomBox)
    bBg:SetColorTexture(0.08, 0.08, 0.08, 0.6)

    -- Última baja
    lastKillDetails = bottomBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lastKillDetails:SetPoint("TOPLEFT", bottomBox, "TOPLEFT", 14, -14)
    lastKillDetails:SetText("Último desalojo: Calculando...")

    -- Subcabecera contribución
    local contribHeader = bottomBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    contribHeader:SetPoint("TOPLEFT", bottomBox, "TOPLEFT", 14, -46)
    contribHeader:SetText("|cFFFFD100Máximos Exterminadores de la Hermandad:|r")

    -- Lista Top 6
    topKillersList = bottomBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    topKillersList:SetPoint("TOPLEFT", bottomBox, "TOPLEFT", 14, -70)
    topKillersList:SetJustifyH("LEFT")
    topKillersList:SetSpacing(4)
    topKillersList:SetText("1. Tú: 0 bajas")

    local function Refresh()
        if ODD.Network and ODD.Network.Sync then
            ODD.Network.Sync:RequestGuildSync()
        end

        local profile = ODD.Guild.Profiles:GetLocalProfile()
        local mainText = profile.mainCharacter and string.format(" (Main: %s)", profile.mainCharacter) or ""
        local roleText = profile.customRole and string.format(" [%s]", profile.customRole) or ""
        local pText = string.format("Personaje: |cFFFFD100%s%s%s|r  •  Clase: |cFFFFD100%s|r  •  Nivel: |cFFFFD100%s|r", 
            profile.name or UnitName("player") or "Desconocido", 
            mainText,
            roleText,
            profile.class or select(2, UnitClass("player")) or "Desconocido", 
            tostring(profile.level or UnitLevel("player") or "?"))
        pLabel:SetText(pText)

        HQTab:RefreshPresence()
        HQTab:RefreshStats()
        UpdatePlayerModel()
    end

    frame:SetScript("OnShow", Refresh)
    Refresh()

    return frame
end
