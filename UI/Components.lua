local addonName, addonTable = ...
local ODD = addonTable.ODD

local Components = {}
ODD.UI.Components = Components

local sectionHeaders = {}

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

-- Actualiza todas las cabeceras registradas al cambiar de tema en caliente
function Components:UpdateHeadersTheme(palette)
    if not palette or not palette.highlight then return end
    for _, fs in ipairs(sectionHeaders) do
        if fs and fs.SetTextColor then
            fs:SetTextColor(palette.highlight[1], palette.highlight[2], palette.highlight[3], 1)
        end
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
