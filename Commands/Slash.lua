local addonName, addonTable = ...
local ODD = addonTable.ODD
local L = addonTable.L

SLASH_ODD1 = "/odd"
SlashCmdList["ODD"] = function(msg)
    local success, err = pcall(function()
        local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
        cmd = (cmd or ""):lower()

        if cmd == "" or cmd == "show" or cmd == "toggle" then
            ODD.UI:Toggle()
        elseif cmd == "hud" then
            if ODD.UI and ODD.UI.HUD then
                ODD.UI.HUD:Toggle()
            end
        elseif cmd == "sync" then
            if ODD.Network and ODD.Network.Sync then
                ODD.Network.Sync:TriggerManualSync()
            end
        elseif cmd == "reset" or cmd == "wipe" or cmd == "clear" then
            ODD.Database:ResetAllData()
            if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.RefreshAll then
                ODD.UI.Dashboard:RefreshAll()
            end
            ReloadUI()
        elseif cmd == "debug" or cmd == "testing" then
            local current = ODD.Database:GetSetting("showTestingTools")
            ODD.Database:SetSetting("showTestingTools", not current)
            ODD:Log("Modo de herramientas de prueba: %s", not current and "|cFF00FF00ACTIVADO|r" or "|cFFFF0000DESACTIVADO|r")
            if ODD.UI.GnomometerTab and ODD.UI.GnomometerTab.Refresh then ODD.UI.GnomometerTab:Refresh() end
            if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then ODD.UI.PvPTab:Refresh() end
            if ODD.UI.WorkshopsTab and ODD.UI.WorkshopsTab.Refresh then ODD.UI.WorkshopsTab:Refresh() end
            if ODD.UI.HQTab and ODD.UI.HQTab.RefreshMedals then ODD.UI.HQTab:RefreshMedals() end
        elseif cmd == "status" then
            ODD:Log("=== Estado de ODD (%s) ===", ODD.version)
            local caps = ODD.Capabilities:GetAll()
            for k, v in pairs(caps) do
                print(string.format("  - %s: |cFF00FF00%s|r", k, tostring(v)))
            end
        elseif cmd == "version" then
            local ver, build, _, toc = GetBuildInfo()
            ODD:Log("ODD Version: %s | Cliente: %s (Build %s, Interface %s)", ODD.version, ver, build, tostring(toc))
        else
            ODD:Log(L["CMD_HELP_TITLE"])
            print(L["CMD_HELP_SHOW"])
            print(L["CMD_HELP_STATUS"])
            print(L["CMD_HELP_VERSION"])
        end
    end)

    if not success then
        print("|cFFFF0000[ODD Error en comando]:|r " .. tostring(err))
    end
end
