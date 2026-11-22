local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local WorkshopsTab = {}
ODD.UI.WorkshopsTab = WorkshopsTab

local myProfsLabel = nil
local craftersScrollChild = nil
local crafterRows = {}
local searchBox = nil
local selectedCategory = "TODAS"
local categoryButtons = {}

-- Categorías de profesiones oficiales de WoW Forever (Clásico Horda)
local PROFESSIONS_LIST = {
    { id = "TODAS", label = "Todas" },
    { id = "Alquimia", label = "Alquimia" },
    { id = "Herrería", label = "Herreria" },
    { id = "Encantamiento", label = "Encantamiento" },
    { id = "Ingeniería", label = "Ingenieria" },
    { id = "Peletería", label = "Peleteria" },
    { id = "Sastrería", label = "Sastreria" },
    { id = "Cocina", label = "Cocina" },
}

function WorkshopsTab:Refresh()
    if not myProfsLabel or not craftersScrollChild then return end

    -- 1. Mostrar profesiones locales
    local mySkills = ODD.Professions.Scanner:GetLocalProfessions()
    if #mySkills == 0 then
        myProfsLabel:SetText("Tus profesiones: Ninguna detectada (o abre tu libro de habilidades).")
    else
        local profTexts = {}
        for _, p in ipairs(mySkills) do
            table.insert(profTexts, string.format("|cFFFFD100%s|r (%d/%d)", p.name, p.level, p.maxLevel))
        end
        myProfsLabel:SetText("Tus profesiones: " .. table.concat(profTexts, "   •   "))
    end

    -- 2. Lista de artesanos de la hermandad (Búsqueda por texto + Filtro por botón de profesión)
    local query = searchBox and searchBox:GetText() or ""
    local results = ODD.Professions.Scanner:SearchCrafters(query)

    -- Aplicar filtro del botón de categoría seleccionado
    if selectedCategory ~= "TODAS" then
        local filtered = {}
        local catLower = selectedCategory:lower()
        for _, r in ipairs(results) do
            local profLower = (r.profession or ""):lower()
            if profLower:find(catLower) 
               or (catLower == "herrería" and profLower:find("herreria"))
               or (catLower == "ingeniería" and profLower:find("ingenieria"))
               or (catLower == "peletería" and profLower:find("peleteria"))
               or (catLower == "sastrería" and profLower:find("sastreria")) then
                table.insert(filtered, r)
            end
        end
        results = filtered
    end

    -- Actualizar resaltado de los botones de categoría
    for _, btn in ipairs(categoryButtons) do
        if btn.categoryId == selectedCategory then
            btn.bg:SetColorTexture(0.5, 0.1, 0.1, 0.9)
            btn.fs:SetTextColor(1, 1, 1, 1)
        else
            btn.bg:SetColorTexture(0.18, 0.18, 0.18, 0.75)
            btn.fs:SetTextColor(0.8, 0.8, 0.8, 1)
        end
    end

    for _, r in ipairs(crafterRows) do r:Hide() end

    local rowHeight = 22
    local currentY = 0

    for i, res in ipairs(results) do
        local row = crafterRows[i]
        if not row then
            row = CreateFrame("Frame", nil, craftersScrollChild)
            row:SetSize(740, 20)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            row.bg = bg

            local rCrafter = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rCrafter:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.crafter = rCrafter

            local rProf = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rProf:SetPoint("LEFT", row, "LEFT", 210, 0)
            row.prof = rProf

            local rOrigin = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            rOrigin:SetPoint("RIGHT", row, "RIGHT", -16, 0)
            row.origin = rOrigin

            crafterRows[i] = row
        end

        row:SetPoint("TOPLEFT", craftersScrollChild, "TOPLEFT", 0, currentY)
        currentY = currentY - rowHeight

        if i % 2 == 0 then
            row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
        else
            row.bg:SetColorTexture(0.18, 0.18, 0.18, 0.35)
        end

        if res.isSelf then
            row.crafter:SetText(string.format("|cFF00FF00%s (Tu)|r", res.crafter))
            row.origin:SetText("|cFF00FF00Observado localmente|r")
        else
            row.crafter:SetText(string.format("|cFFFFD100%s|r", res.crafter))
            row.origin:SetText("|cFF808080Declarado por el usuario|r")
        end

        row.prof:SetText(string.format("%s (%d/%d)", res.profession, res.level, res.maxLevel))
        row:Show()
    end

    craftersScrollChild:SetHeight(math.max(1, #results * rowHeight))
end

function WorkshopsTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, L["TAB_WORKSHOPS"] .. " - Artesanos de la Hermandad", -12)

    -- Panel de profesiones propias
    local profBox = CreateFrame("Frame", nil, frame)
    profBox:SetSize(760, 32)
    profBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
    local pBg = profBox:CreateTexture(nil, "BACKGROUND")
    pBg:SetAllPoints(profBox)
    pBg:SetColorTexture(0.12, 0.12, 0.12, 0.5)

    myProfsLabel = profBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    myProfsLabel:SetPoint("LEFT", profBox, "LEFT", 12, 0)
    myProfsLabel:SetText("Tus profesiones: Escaneando...")

    -- Buscador por texto libre
    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -78)
    searchLabel:SetText("Buscar:")

    searchBox = CreateFrame("EditBox", "ODD_CrafterSearchBox", frame, "InputBoxTemplate")
    searchBox:SetSize(220, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function()
        WorkshopsTab:Refresh()
    end)

    -- ========================================================
    -- BARRA DE FILTRO POR BOTONES DE PROFESION
    -- ========================================================
    categoryButtons = {}
    local btnStartX = 16
    local btnY = -108
    local btnW = 88
    local btnH = 22

    for idx, item in ipairs(PROFESSIONS_LIST) do
        local b = CreateFrame("Button", "ODD_ProfBtn_" .. idx, frame)
        b:SetSize(btnW, btnH)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", btnStartX + ((idx - 1) * (btnW + 6)), btnY)
        b:SetFrameLevel(frame:GetFrameLevel() + 2)
        b.categoryId = item.id

        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(b)
        b.bg = bg

        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER", b, "CENTER", 0, 0)
        fs:SetText(item.label)
        b.fs = fs

        b:SetScript("OnClick", function(self)
            selectedCategory = self.categoryId
            WorkshopsTab:Refresh()
        end)

        table.insert(categoryButtons, b)
    end

    -- Encabezados del Catálogo
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetSize(760, 18)
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -138)

    local colCrafter = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colCrafter:SetPoint("LEFT", headerFrame, "LEFT", 8, 0)
    colCrafter:SetText("Artesano")

    local colProf = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colProf:SetPoint("LEFT", headerFrame, "LEFT", 210, 0)
    colProf:SetText("Profesion / Nivel")

    local colOrigin = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colOrigin:SetPoint("RIGHT", headerFrame, "RIGHT", -30, 0)
    colOrigin:SetText("Procedencia")

    -- Tabla de Artesanos con Scroll
    local scrollFrame = CreateFrame("ScrollFrame", "ODD_CraftersScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(760, 275)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)

    craftersScrollChild = CreateFrame("Frame", nil, scrollFrame)
    craftersScrollChild:SetSize(740, 1)
    scrollFrame:SetScrollChild(craftersScrollChild)

    frame:SetScript("OnShow", function()
        if ODD.Professions and ODD.Professions.Scanner then
            ODD.Professions.Scanner:ScanLocalProfessions()
        end
        WorkshopsTab:Refresh()
    end)

    WorkshopsTab:Refresh()
    return frame
end
