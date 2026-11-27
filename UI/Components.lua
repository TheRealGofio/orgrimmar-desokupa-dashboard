local addonName, addonTable = ...
local ODD = addonTable.ODD

local Components = {}
ODD.UI.Components = Components

local sectionHeaders = {}
local registeredThemedFrames = {}

-- Helper para añadir florituras en las esquinas de cualquier caja
function Components:AttachCornerFlourishes(frame)
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

-- Crea un contenedor/caja estilizado con fondo negro translúcido y borde del tema
function Components:CreateSectionBox(parent, width, height, withFlourishes, bgAlpha)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    local alpha = bgAlpha or 0.50
    box:SetBackdropColor(0.0, 0.0, 0.0, alpha)

    local corners = nil
    if withFlourishes ~= false then
        corners = Components:AttachCornerFlourishes(box)
    end

    table.insert(registeredThemedFrames, { frame = box, corners = corners, alpha = alpha })
    Components:ApplyThemeToFrame(box, corners, alpha)
    return box
end

-- Registra cualquier frame existente (como botones de sonido o scrollframes) para que actualice sus bordes
function Components:RegisterThemedFrame(frame, corners, bgAlpha)
    local alpha = bgAlpha or 0.50
    table.insert(registeredThemedFrames, { frame = frame, corners = corners, alpha = alpha })
    Components:ApplyThemeToFrame(frame, corners, alpha)
end

-- Aplica el color del tema a un frame específico
function Components:ApplyThemeToFrame(box, corners, alpha)
    local p = ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.GetActivePalette and ODD.UI.Dashboard:GetActivePalette()
    local borderRGBA, highlightRGB
    if p and p.tabBorder then
        borderRGBA = { p.tabBorder[1], p.tabBorder[2], p.tabBorder[3], 0.85 }
        highlightRGB = p.highlight or { borderRGBA[1], borderRGBA[2], borderRGBA[3] }
    else
        borderRGBA = { 0.45, 0.12, 0.12, 0.85 }
        highlightRGB = { 0.90, 0.25, 0.25 }
    end

    if box and box.SetBackdropBorderColor then
        box:SetBackdropBorderColor(borderRGBA[1], borderRGBA[2], borderRGBA[3], borderRGBA[4])
        box:SetBackdropColor(0.0, 0.0, 0.0, alpha or 0.50)
    end
    if corners then
        for _, c in ipairs(corners) do
            c:SetVertexColor(highlightRGB[1], highlightRGB[2], highlightRGB[3], 0.95)
        end
    end
end

-- Crea una sección o panel con título y estado
function Components:CreateSectionHeader(parent, title, yOffset)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    fs:SetText(title)

    table.insert(sectionHeaders, fs)

    -- Si hay un tema activo con color de acento, tintar la cabecera
    if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.GetActivePalette then
        local p = ODD.UI.Dashboard:GetActivePalette()
        if p and p.highlight then
            fs:SetTextColor(p.highlight[1], p.highlight[2], p.highlight[3], 1)
        end
    end
    return fs
end

-- Actualiza todos los frames y cabeceras registrados cuando cambia el tema
function Components:UpdateHeadersTheme(palette)
    if not palette then return end
    for _, fs in ipairs(sectionHeaders) do
        if fs and fs.SetTextColor and palette.highlight then
            fs:SetTextColor(palette.highlight[1], palette.highlight[2], palette.highlight[3], 1)
        end
    end

    for _, entry in ipairs(registeredThemedFrames) do
        Components:ApplyThemeToFrame(entry.frame, entry.corners, entry.alpha)
    end
end

-- Mensaje de estado estándar (declarado, observado, fase pendiente)
function Components:CreateStatusLabel(parent, text, yOffset, colorHex)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    if colorHex then
        fs:SetText(string.format("|c%s%s|r", colorHex, text))
    else
        fs:SetText(text)
    end
    return fs
end
