local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local MinimapBtn = {}
ODD.UI = ODD.UI or {}
ODD.UI.MinimapBtn = MinimapBtn

local button = nil

local function UpdatePosition(angle)
    if not button then return end
    local radius = 80
    local rad = math.rad(angle or 220)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
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
    button:SetFrameLevel(8)
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
    border:SetSize(52, 52)
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

    -- Clic para abrir / cerrar el Dashboard
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            ODD.UI:Toggle()
        end
    end)

    -- Tooltip informativo
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFFF8000Orgrimmar Desokupa Dashboard|r", 1, 1, 1)
        GameTooltip:AddLine("Clic izquierdo: Abrir / Cerrar panel", 0.2, 1, 0.2)
        GameTooltip:AddLine("Arrastrar: Mover alrededor del minimapa", 0.8, 0.8, 0.8)

        local charDB = ODD.Database:GetChar()
        local kills = (charDB and charDB.observations and charDB.observations.gnomes and charDB.observations.gnomes.kills) or 0
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Gnomos abatidos: |cFFFFD100%d|r", kills), 1, 0.8, 0)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Arrastre suave circular alrededor del minimapa
    local isDragging = false
    button:RegisterForDrag("RightButton", "LeftButton")

    button:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() or IsControlKeyDown() then
            isDragging = true
        end
    end)

    button:SetScript("OnMouseDown", function(self, btn)
        if btn == "RightButton" then
            isDragging = true
        end
    end)

    button:SetScript("OnMouseUp", function(self, btn)
        if isDragging then
            isDragging = false
        end
    end)

    button:SetScript("OnUpdate", function(self)
        if isDragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale

            local deg = math.deg(math.atan2(cy - my, cx - mx))
            if deg < 0 then deg = deg + 360 end

            UpdatePosition(deg)
            if globalDB and globalDB.settings then
                globalDB.settings.minimapPos = deg
            end
        end
    end)
end
