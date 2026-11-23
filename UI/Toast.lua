local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Toast = {}
ODD.UI.Toast = Toast

local toastFrame = nil
local hideTimer = nil

function Toast:Show(title, subtitle, iconTexture)
    if not toastFrame then
        toastFrame = CreateFrame("Button", "ODD_AchievementToastFrame", UIParent)
        toastFrame:SetSize(320, 64)
        toastFrame:SetPoint("TOP", UIParent, "TOP", 0, -140)
        toastFrame:SetFrameStrata("DIALOG")
        toastFrame:SetMovable(true)
        toastFrame:EnableMouse(true)
        toastFrame:RegisterForDrag("LeftButton")
        toastFrame:SetScript("OnDragStart", toastFrame.StartMoving)
        toastFrame:SetScript("OnDragStop", toastFrame.StopMovingOrSizing)

        -- Fondo estilo Horda
        local bg = toastFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(toastFrame)
        bg:SetColorTexture(0.12, 0.04, 0.04, 0.92)
        toastFrame.bg = bg

        -- Borde
        local border = CreateFrame("Frame", nil, toastFrame, "BackdropTemplate")
        border:SetAllPoints(toastFrame)
        border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
        })
        border:SetBackdropBorderColor(1, 0.82, 0, 0.8)

        -- Icono del logro
        local icon = toastFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(42, 42)
        icon:SetPoint("LEFT", toastFrame, "LEFT", 12, 0)
        toastFrame.icon = icon

        -- Cabecera
        local header = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        header:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
        header:SetText("|cFFFFD100¡LOGRO DESOKUPADO!|r")
        toastFrame.header = header

        -- Título del logro
        local titleFs = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFs:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
        toastFrame.titleFs = titleFs

        -- Subtítulo / Descripción
        local subFs = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        subFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -2)
        toastFrame.subFs = subFs

        -- Botón de cierre en la esquina superior derecha (X)
        local closeBtn = CreateFrame("Button", nil, toastFrame, "UIPanelCloseButton")
        closeBtn:SetSize(22, 22)
        closeBtn:SetPoint("TOPRIGHT", toastFrame, "TOPRIGHT", -2, -2)
        closeBtn:SetScript("OnClick", function()
            toastFrame:Hide()
        end)

        -- Clic directo en el toast también lo cierra
        toastFrame:SetScript("OnClick", function(self)
            self:Hide()
        end)
    end

    toastFrame.icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    toastFrame.titleFs:SetText(title or "Logro Obtenido")
    toastFrame.subFs:SetText(subtitle or "")

    -- Sonido personalizado de logro (con fallback a sonido nativo)
    if ODD.Audio and ODD.Audio.PlayAchievementSound then
        ODD.Audio:PlayAchievementSound()
    elseif type(PlaySound) == "function" then
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 888)
    end

    toastFrame:Show()

    -- Auto-ocultar tras 7 segundos si el usuario no lo quita antes
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(7, function()
        if toastFrame and toastFrame:IsShown() then
            toastFrame:Hide()
        end
    end)
end
