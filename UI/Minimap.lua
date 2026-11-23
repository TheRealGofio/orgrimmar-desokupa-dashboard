local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local MinimapBtn = {}
ODD.UI = ODD.UI or {}
ODD.UI.MinimapBtn = MinimapBtn

local button = nil

local function UpdatePosition(angle)
    if not button then return end
    -- En WoW, el radio del minimapa estándar es su ancho/2 (~70px) + margen (~10-12px) = ~82-84px
    -- O calculado dinámicamente según el tamaño real del Minimap:
    local miniW = (Minimap and Minimap:GetWidth()) or 140
    local radius = (miniW * 0.5) + 11
    local rad = math.rad(angle or 220)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", cos * radius, sin * radius)
end

function MinimapBtn:Initialize()
    if button then return end

    local globalDB = ODD.Database:GetGlobal()
    if not globalDB then return end
    globalDB.settings = globalDB.settings or {}
    local currentAngle = globalDB.settings.minimapPos or 220

    button = CreateFrame("Button", "ODD_MinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 5) + 8)
    button:EnableMouse(true)
    button:SetMovable(true)

    -- Icono nativo de Gnomo
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Head_Gnome_01")
    button.icon = icon

    -- Borde circular estándar de Blizzard para botones de minimapa
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    -- Textura de brillo al pasar el ratón por encima
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(20, 20)
    highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    button.highlight = highlight

    -- Posicionar alrededor del minimapa
    UpdatePosition(currentAngle)

    -- Clics: Clic Izquierdo abre/cierra panel, Clic Derecho alterna HUD compacto
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            ODD.UI:Toggle()
        elseif btn == "RightButton" then
            if ODD.UI and ODD.UI.HUD then
                ODD.UI.HUD:Toggle()
            end
        end
    end)

    -- Tooltip informativo
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFFF8000Orgrimmar Desokupa Dashboard|r", 1, 1, 1)
        GameTooltip:AddLine("Clic izquierdo: Abrir / Cerrar panel", 0.2, 1, 0.2)
        GameTooltip:AddLine("Clic derecho: Mostrar / Ocultar HUD compacto", 1, 0.8, 0)
        GameTooltip:AddLine("Arrastrar (clic izquierdo): Mover por el minimapa", 0.8, 0.8, 0.8)

        local charDB = ODD.Database:GetChar()
        local kills = (charDB and charDB.observations and charDB.observations.gnomes and charDB.observations.gnomes.kills) or 0
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Gnomos abatidos: |cFFFFD100%d|r", kills), 1, 0.8, 0)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Arrastre suave circular con Clic Izquierdo (estándar de addons de WoW)
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end

            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale

            local deg = math.deg(math.atan2(cy - my, cx - mx))
            if deg < 0 then deg = deg + 360 end

            UpdatePosition(deg)
            local gDB = ODD.Database:GetGlobal()
            if gDB and gDB.settings then
                gDB.settings.minimapPos = deg
                _G["ODDDB"] = gDB
            end
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
end
