local addonName, addonTable = ...

-- Si el cliente está en inglés, sobrescribir claves manteniendo fallback
if GetLocale and GetLocale() == "enUS" then
    local L = addonTable.L or {}
    addonTable.L = L

    L["ADDON_TITLE"] = "Orgrimmar Desokupa Dashboard"
    L["CMD_HELP_TITLE"] = "Orgrimmar Desokupa Dashboard (ODD) commands:"
    L["CMD_HELP_SHOW"] = "  /odd show - Toggle main dashboard."
    L["CMD_HELP_STATUS"] = "  /odd status - Print environment and capabilities status."
    L["CMD_HELP_VERSION"] = "  /odd version - Print installed version and client build."
    L["CMD_UNKNOWN"] = "Unknown command. Type /odd help for commands."

    L["TAB_HQ"] = "General"
    L["TAB_GNOMOMETER"] = "Gnomometer"
    L["TAB_MEDALS"] = "Achievements"
    L["TAB_PVP"] = "PvP"
    L["TAB_SOUNDBOARD"] = "Soundboard"
    L["TAB_HISTORY"] = "Evictions"
    L["TAB_ROSTER"] = "Members"
    L["TAB_SETTINGS"] = "Settings"

    L["STATUS_NO_DATA"] = "No data available"
    L["STATUS_LOCAL_OBSERVED"] = "Locally observed"
    L["STATUS_DECLARED_BY"] = "Declared by %s (unverified)"
    L["STATUS_UNAVAILABLE"] = "Capability unavailable in this client"
    L["STATUS_PHASE_PENDING"] = "Module scheduled for later phase (%s)"
end
