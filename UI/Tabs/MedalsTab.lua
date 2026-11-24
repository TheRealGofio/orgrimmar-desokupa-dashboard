local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]
local L = addonTable.L

local MedalsTab = {}
ODD.UI.MedalsTab = MedalsTab

local medalsScrollChild = nil
local medalRows = {}
local statsSummaryLabel = nil

function MedalsTab:Refresh()
    if not medalsScrollChild or not ODD.Achievements or not ODD.Achievements.Medals then return end

    local medals = ODD.Achievements.Medals:GetPlayerMedals()
    local completedCount = 0
    local earnedPoints = 0
    local totalPoints = 0
    for _, m in ipairs(medals) do
        local pts = m.points or 10
        totalPoints = totalPoints + pts
        if m.completed then
            completedCount = completedCount + 1
            earnedPoints = earnedPoints + pts
        end
    end

    if statsSummaryLabel then
        statsSummaryLabel:SetText(string.format("Progreso: |cFFFFD100%d / %d|r logros (%.1f%%)   •   Puntos de Logro: |cFF00FFCC%d / %d pts|r",
            completedCount, #medals, #medals > 0 and (completedCount / #medals * 100) or 0, earnedPoints, totalPoints))
    end

    for _, r in ipairs(medalRows) do r:Hide() end

    local rowHeight = 38
    local currentY = 0

    for i, m in ipairs(medals) do
        local row = medalRows[i]
        if not row then
            row = CreateFrame("Frame", nil, medalsScrollChild)
            row:SetSize(760, 34)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            row.bg = bg

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(28, 28)
            icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.icon = icon

            local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            title:SetPoint("TOPLEFT", row, "TOPLEFT", 40, -2)
            row.title = title

            local desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            desc:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 40, 2)
            row.desc = desc

            local prog = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            prog:SetPoint("RIGHT", row, "RIGHT", -16, 0)
            row.prog = prog

            -- Soporte para Shift + Clic (Compartir en chat)
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.3, 0.3, 0.1, 0.5)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.medalData then
                    local m = self.medalData
                    GameTooltip:AddLine(m.name, 1, 0.82, 0)
                    GameTooltip:AddLine(m.desc, 1, 1, 1, true)
                    GameTooltip:AddLine(string.format("Puntos de Logro: %d pts", m.points or 10), 0, 1, 0.8)
                    GameTooltip:AddLine(m.completed and "|cFF00FF00Logro Completado|r" or "|cFFFF8000En progreso|r")
                    GameTooltip:AddLine("Shift + Clic: Compartir en chat", 0.6, 0.6, 0.6)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(self)
                if self.medalData then
                    if self.medalData.completed then
                        self.bg:SetColorTexture(0.1, 0.28, 0.1, 0.45)
                    else
                        self.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
                    end
                end
                GameTooltip:Hide()
            end)
            row:SetScript("OnMouseUp", function(self, button)
                if IsShiftKeyDown() and self.medalData then
                    local m = self.medalData
                    local myPoints = tonumber(m.points) or 10
                    local achId = tostring(m.id or m.key or "ACH")
                    local t = time()
                    -- Formato de texto ordinario limpio para el servidor de WoW:
                    -- Se envía sin pipes ni |Hitem para que el servidor jamás lo bloquee.
                    -- Los jugadores con ODD lo verán transformado en un enlace interactivo clickeable que abre el Modal.
                    local shareText = string.format("{ODD:%s:%d:%d} [%s]", achId, myPoints, t, m.name or "Logro")

                    local inGuild = IsInGuild and IsInGuild()
                    local editBox = ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend()

                    if editBox then
                        ChatEdit_ActivateChat(editBox)
                        if inGuild then
                            editBox:SetAttribute("chatType", "GUILD")
                            editBox.chatType = "GUILD"
                            if ChatEdit_UpdateHeader then
                                ChatEdit_UpdateHeader(editBox)
                            end
                        end
                        editBox:Insert(shareText)
                    elseif type(ChatFrame_OpenChat) == "function" then
                        if inGuild then
                            ChatFrame_OpenChat("/g " .. shareText)
                        else
                            ChatFrame_OpenChat(shareText)
                        end
                    end
                end
            end)

            medalRows[i] = row
        end

        row.medalData = m
        row:SetPoint("TOPLEFT", medalsScrollChild, "TOPLEFT", 0, currentY)
        currentY = currentY - rowHeight

        row.icon:SetTexture(m.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.desc:SetText(m.desc)

        if m.completed then
            row.bg:SetColorTexture(0.1, 0.28, 0.1, 0.45)
            row.title:SetText(string.format("|cFFFFD100%s|r  |cFF00FF00[Completado]|r  |cFF00FFCC(%d pts)|r", m.name, m.points or 10))
            row.prog:SetText(string.format("|cFF00FF00%d / %d|r", m.progress, m.maxReq))
            row.icon:SetDesaturated(false)
        else
            row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
            row.title:SetText(string.format("|cFF888888%s|r  |cFF557788(%d pts)|r", m.name, m.points or 10))
            row.prog:SetText(string.format("|cFF888888%d / %d|r", m.progress, m.maxReq))
            row.icon:SetDesaturated(true)
        end

        row:Show()
    end

    medalsScrollChild:SetHeight(math.max(1, #medals * rowHeight))
end

function MedalsTab:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    ODD.UI.Components:CreateSectionHeader(frame, "Logros y Medallas de Exterminio", -12)

    local summaryBox = CreateFrame("Frame", nil, frame)
    summaryBox:SetSize(780, 26)
    summaryBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)

    statsSummaryLabel = summaryBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statsSummaryLabel:SetPoint("LEFT", summaryBox, "LEFT", 0, 0)
    statsSummaryLabel:SetText("Cargando logros...")

    local scrollFrame = CreateFrame("ScrollFrame", "ODD_MedalsTabScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(780, 385)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -66)

    medalsScrollChild = CreateFrame("Frame", nil, scrollFrame)
    medalsScrollChild:SetSize(760, 1)
    scrollFrame:SetScrollChild(medalsScrollChild)

    frame:SetScript("OnShow", function()
        MedalsTab:Refresh()
    end)
    MedalsTab:Refresh()

    return frame
end
