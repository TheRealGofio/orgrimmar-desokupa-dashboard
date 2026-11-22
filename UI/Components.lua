local addonName, addonTable = ...
local ODD = addonTable.ODD

local Components = {}
ODD.UI.Components = Components

-- Crea una sección o panel con título y estado
function Components:CreateSectionHeader(parent, title, yOffset)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    fs:SetText(title)
    return fs
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
