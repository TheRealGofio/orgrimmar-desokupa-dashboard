local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Radar = {}
ODD.Gnomes = ODD.Gnomes or {}
ODD.Gnomes.Radar = Radar

local alertButton = nil
local hideTimer = nil
local recentAlerts = {} -- [guid] = timestamp
local ALERT_COOLDOWN = 30 -- Segundos antes de volver a alertar del mismo gnomo

-- Colores de clase estándar de WoW
local CLASS_COLORS = {
    ["WARRIOR"]     = "FFC79C6E",
    ["PALADIN"]     = "FFF58CBA",
    ["HUNTER"]      = "FFABD473",
    ["ROGUE"]       = "FFFFF569",
    ["PRIEST"]      = "FFFFFFFF",
    ["DEATHKNIGHT"] = "FFC41F3B",
    ["SHAMAN"]      = "FF0070DE",
    ["MAGE"]        = "FF69CCF0",
    ["WARLOCK"]     = "FF9482C9",
    ["MONK"]        = "FF00FF96",
    ["DRUID"]       = "FFFF7D0A",
    ["DEMONHUNTER"] = "FFA330C9",
    ["EVOKER"]      = "FF33937F",
}

-- Nombres en español de clases estándar
local CLASS_LOCALIZED = {
    ["WARRIOR"]     = "Guerrero",
    ["PALADIN"]     = "Paladín",
    ["HUNTER"]      = "Cazador",
    ["ROGUE"]       = "Pícaro",
    ["PRIEST"]      = "Sacerdote",
    ["DEATHKNIGHT"] = "Caballero de la Muerte",
    ["SHAMAN"]      = "Chamán",
    ["MAGE"]        = "Mago",
    ["WARLOCK"]     = "Brujo",
    ["MONK"]        = "Monje",
    ["DRUID"]       = "Druida",
    ["DEMONHUNTER"] = "Cazador de Demonios",
    ["EVOKER"]      = "Evocador",
}

-- Obtiene el color de dificultad (Gris, Verde, Amarillo, Naranja, Rojo) según el nivel del enemigo
local function GetDifficultyColorHex(enemyLevel)
    local num = tonumber(enemyLevel)
    if not num or num <= 0 then
        -- Calavera / nivel desconocido o boss: Rojo
        return "FFFF2020", 1.0, 0.15, 0.15
    end

    -- 1. Intentar API nativa GetCreatureDifficultyColor o GetQuestDifficultyColor
    local colorTable = nil
    if type(GetCreatureDifficultyColor) == "function" then
        local ok, c = pcall(GetCreatureDifficultyColor, num)
        if ok and type(c) == "table" and c.r then
            colorTable = c
        end
    end
    if not colorTable and type(GetQuestDifficultyColor) == "function" then
        local ok, c = pcall(GetQuestDifficultyColor, num)
        if ok and type(c) == "table" and c.r then
            colorTable = c
        end
    end

    if colorTable then
        local r = math.min(255, math.max(0, math.floor((colorTable.r or 1) * 255 + 0.5)))
        local g = math.min(255, math.max(0, math.floor((colorTable.g or 1) * 255 + 0.5)))
        local b = math.min(255, math.max(0, math.floor((colorTable.b or 1) * 255 + 0.5)))
        local hex = string.format("FF%02X%02X%02X", r, g, b)
        return hex, colorTable.r or 1, colorTable.g or 1, colorTable.b or 1
    end

    -- 2. Fallback según fórmula de dificultad estándar de WoW (diferencia de nivel)
    local playerLevel = UnitLevel("player") or 60
    local diff = num - playerLevel

    if diff >= 5 then
        -- Rojo (Muy difícil / Peligro)
        return "FFFF2020", 1.0, 0.13, 0.13
    elseif diff >= 3 then
        -- Naranja (Difícil)
        return "FFFF7F00", 1.0, 0.50, 0.0
    elseif diff >= -2 then
        -- Amarillo (Nivel parejo)
        return "FFFFFF00", 1.0, 1.0, 0.0
    elseif diff >= -7 then
        -- Verde (Fácil)
        return "FF40C040", 0.25, 0.75, 0.25
    else
        -- Gris (Trivial)
        return "FF808080", 0.5, 0.5, 0.5
    end
end

-- Crea o reutiliza el botón interactivo de alerta estilo RareScanner con modelo 3D
local function GetAlertButton()
    if alertButton then return alertButton end

    -- SecureActionButtonTemplate permite targetear al hacer clic izquierdo sin provocar taint
    alertButton = CreateFrame("Button", "ODD_GnomeRadarAlertButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    alertButton:SetSize(410, 84)
    alertButton:SetPoint("TOP", UIParent, "TOP", 0, -140)
    alertButton:SetFrameStrata("HIGH")
    alertButton:SetClampedToScreen(true)
    alertButton:SetMovable(true)
    alertButton:EnableMouse(true)
    alertButton:RegisterForClicks("AnyUp", "AnyDown")
    -- En WoW, registrar drag en "LeftButton" en un botón seguro intercepta el OnMouseDown y
    -- rompe la ejecución del macro seguro. Usamos "RightButton" o Shift-Left para arrastrar.
    alertButton:RegisterForDrag("RightButton")

    -- Restaurar posición guardada si existe en DB
    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.settings and globalDB.settings.radarPos then
        local p = globalDB.settings.radarPos
        alertButton:ClearAllPoints()
        alertButton:SetPoint(p.point or "TOP", UIParent, p.relPoint or "TOP", p.x or 0, p.y or -140)
    end

    alertButton:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    alertButton:SetScript("OnDragStop", function(self)
        if not InCombatLockdown() then
            self:StopMovingOrSizing()
            local point, _, relPoint, x, y = self:GetPoint()
            local gDB = ODD.Database:GetGlobal()
            if gDB then
                gDB.settings = gDB.settings or {}
                gDB.settings.radarPos = { point = point, relPoint = relPoint, x = x, y = y }
                _G["ODDDB"] = gDB
            end
        end
    end)

    -- Fondo translúcido oscuro con tono adaptable
    local bg = alertButton:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(alertButton)
    bg:SetColorTexture(0.12, 0.03, 0.03, 0.92)
    alertButton.bg = bg

    -- Borde de tooltip de Blizzard
    alertButton:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
    })
    alertButton:SetBackdropBorderColor(0.85, 0.2, 0.1, 0.9)

    -- Marco modelo 3D del Gnomo (PlayerModel)
    local modelView = CreateFrame("PlayerModel", "ODD_RadarPlayerModel", alertButton)
    modelView:SetSize(70, 70)
    modelView:SetPoint("LEFT", alertButton, "LEFT", 7, 0)
    modelView:EnableMouse(false) -- Permitir que los clics atraviesen al botón principal para targetear
    alertButton.ModelView = modelView

    -- Barra / Cabecera
    local title = alertButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", modelView, "TOPRIGHT", 10, -9)
    title:SetPoint("RIGHT", alertButton, "RIGHT", -30, 0)
    title:SetJustifyH("LEFT")
    title:SetText("|cFFFF2020¡ALERTA RADAR: GNOMO DETECTADO!|r")
    alertButton.title = title

    -- Nombre y clase
    local nameFs = alertButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameFs:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    nameFs:SetPoint("RIGHT", alertButton, "RIGHT", -30, 0)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetText("Gnomo")
    alertButton.nameFs = nameFs

    -- Subtexto (Nivel / Némesis / Instrucción clic)
    local subFs = alertButton:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subFs:SetPoint("TOPLEFT", nameFs, "BOTTOMLEFT", 0, -3)
    subFs:SetPoint("RIGHT", alertButton, "RIGHT", -10, 0)
    subFs:SetJustifyH("LEFT")
    subFs:SetText("|cFF888888Clic para seleccionar objetivo|r")
    alertButton.subFs = subFs

    -- Botón de cerrar (X) en la esquina superior derecha
    local closeBtn = CreateFrame("Button", nil, alertButton)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", alertButton, "TOPRIGHT", -5, -5)
    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints()
    closeBg:SetColorTexture(0.5, 0.1, 0.1, 0.8)
    local closeFs = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeFs:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeFs:SetText("X")
    closeBtn:SetScript("OnClick", function()
        alertButton:Hide()
    end)

    -- Configuración segura inicial para targetear al hacer clic izquierdo
    alertButton:SetAttribute("type", "macro")
    alertButton:SetAttribute("type1", "macro")

    alertButton:Hide()
    return alertButton
end

-- Dispara la alerta sonora y visual al detectar un gnomo enemigo
function Radar:TriggerAlert(guid, name, classFile, level, unitToken)
    if not ODD.Database or not ODD.Database:GetSetting("enableGnomeRadar") then
        return
    end

    local now = time()
    if guid and recentAlerts[guid] and (now - recentAlerts[guid]) < ALERT_COOLDOWN then
        return
    end

    if guid then
        recentAlerts[guid] = now
    end

    -- 1. Sonido de radar
    if ODD.Audio and ODD.Audio.PlayRadarAlertSound then
        ODD.Audio:PlayRadarAlertSound()
    end

    -- 2. Alerta visual interactiva
    local btn = GetAlertButton()
    local cleanName = name or "Gnomo desconocido"
    local colorHex = CLASS_COLORS[classFile] or "FFFFFFFF"
    local localizedClass = CLASS_LOCALIZED[classFile] or classFile or ""

    -- Cálculo del color de dificultad según el nivel (Gris, Verde, Amarillo, Naranja, Rojo)
    local diffHex, diffR, diffG, diffB = GetDifficultyColorHex(level)

    -- Cabecera con el color de dificultad del nivel
    btn.title:SetText(string.format("|c%s¡ALERTA RADAR: GNOMO DETECTADO!|r", diffHex))

    -- Color del borde del marco acorde a la peligrosidad del gnomo
    btn:SetBackdropBorderColor(diffR, diffG, diffB, 0.95)

    -- Nombre con el color oficial de clase de WoW
    btn.nameFs:SetText(string.format("|c%s%s|r", colorHex, cleanName))

    -- Comprobar si este gnomo es una Némesis registrada
    local isNemesis = false
    local charDB = ODD.Database:GetChar()
    if charDB and charDB.observations and charDB.observations.pvp and charDB.observations.pvp.nemesis then
        if guid and charDB.observations.pvp.nemesis[guid] then
            isNemesis = true
        end
    end

    local lvlStr = (level and tostring(level) ~= "??") and string.format("Nivel %s", tostring(level)) or "Nivel ??"
    local levelColored = string.format("|c%s%s|r", diffHex, lvlStr)

    if isNemesis then
        btn.subFs:SetText(string.format("|cFFFF0000[¡TU NÉMESIS!]|r %s %s • |cFF00FF00Clic para target|r", levelColored, localizedClass))
    else
        btn.subFs:SetText(string.format("%s %s • |cFF00FF00Clic para target|r", levelColored, localizedClass))
    end

    -- Actualizar macro seguro para targetearlo con clic izquierdo
    if not InCombatLockdown() then
        -- En WoW Forever los personajes tienen Nombre y Apellido.
        -- Para que /targetexact y /target funcionen al 100%:
        -- Extraemos el primer nombre (ej. 'Argemus') y el nombre completo.
        local firstName = cleanName:match("^(%S+)") or cleanName
        local macroLines = {
            "/cleartarget",
            string.format("/targetexact %s", cleanName),
        }
        if firstName ~= cleanName then
            table.insert(macroLines, string.format("/targetexact %s", firstName))
        end
        table.insert(macroLines, string.format("/target %s", firstName))

        local macroText = table.concat(macroLines, "\n")
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("type1", "macro")
        btn:SetAttribute("macrotext", macroText)
        btn:SetAttribute("macrotext1", macroText)
    end

    -- Actualizar modelo 3D del gnomo (PlayerModel)
    if btn.ModelView then
        btn.ModelView:ClearModel()
        local modelLoaded = false

        -- Si tenemos el unitToken activo ("target", "mouseover", placa "nameplateN")
        if unitToken and UnitExists(unitToken) and type(btn.ModelView.SetUnit) == "function" then
            local okUnit = pcall(btn.ModelView.SetUnit, btn.ModelView, unitToken)
            if okUnit then
                modelLoaded = true
            end
        end

        -- Si no se pudo cargar por SetUnit (ej. ya salió de rango visual), usar fallback de modelo gnomo
        if not modelLoaded and type(btn.ModelView.SetCreature) == "function" then
            -- Fallback a criatura o modelo de gnomo
            pcall(btn.ModelView.SetCreature, btn.ModelView, 6593) -- Gnomo universal
        end

        btn.ModelView:SetPortraitZoom(0.6) -- Zoom a medio torso y cara
        btn.ModelView:SetRotation(0.2)
    end

    btn:Show()

    -- Mensaje de log discreto
    ODD:Log("|cFFFF2020[RADAR]|r Gnomo detectado: %s (%s %s)", cleanName, lvlStr, classFile or "")

    -- Auto-ocultar tras 7 segundos si el jugador no interactúa
    if hideTimer then
        hideTimer:Cancel()
    end
    hideTimer = C_Timer.NewTimer(7.0, function()
        if btn and btn:IsShown() and not btn:IsMouseOver() then
            btn:Hide()
        end
    end)
end

function Radar:Reset()
    recentAlerts = {}
end
