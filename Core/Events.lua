local addonName, addonTable = ...
local ODD = addonTable.ODD

local Events = {}
ODD.Events = Events

local frame = CreateFrame("Frame", "ODD_EventFrame")
local handlers = {}

function Events:Register(eventName, callback)
    if not handlers[eventName] then
        handlers[eventName] = {}
        frame:RegisterEvent(eventName)
    end
    table.insert(handlers[eventName], callback)
end

function Events:Unregister(eventName, callback)
    local list = handlers[eventName]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == callback then
            table.remove(list, i)
            break
        end
    end
    if #list == 0 then
        handlers[eventName] = nil
        frame:UnregisterEvent(eventName)
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    local list = handlers[event]
    if list then
        for _, cb in ipairs(list) do
            local success, err = pcall(cb, event, ...)
            if not success then
                ODD:Log("|cFFFF0000Error en evento %s:|r %s", tostring(event), tostring(err))
            end
        end
    end
end)

-- Eventos de ciclo de vida del addon
Events:Register("ADDON_LOADED", function(event, loadedAddon)
    if loadedAddon and (loadedAddon:lower() == addonName:lower() or loadedAddon:lower():find("orgrimmar")) then
        local okCaps, errCaps = pcall(function() ODD.Capabilities:EvaluateEnvironment() end)
        if not okCaps then
            ODD:Log("Error en Capabilities: %s", tostring(errCaps))
        end

        local okDB, errDB = pcall(function() ODD.Database:Initialize() end)
        if not okDB then
            ODD:Log("Error en Database: %s", tostring(errDB))
        end

        ODD:Log("Cargado (v%s). Escribe /odd para abrir.", ODD.version)
    end
end)

Events:Register("PLAYER_LOGIN", function()
    -- Garantizar inicializacion de la base de datos si ADDON_LOADED se ejecuto antes o difirio el nombre
    if not ODD.Database.global then
        ODD.Capabilities:EvaluateEnvironment()
        ODD.Database:Initialize()
    end

    local okGuild, errGuild = pcall(function() ODD.Guild:OnPlayerLogin() end)
    if not okGuild then
        ODD:Log("Error en Guild OnPlayerLogin: %s", tostring(errGuild))
    end

    -- Inicializar Gnomómetro (Fase 3)
    if ODD.Gnomes and ODD.Gnomes.Tracker then
        local okGnome, errGnome = pcall(function() ODD.Gnomes.Tracker:Initialize() end)
        if not okGnome then
            ODD:Log("Error en Gnomes Tracker Init: %s", tostring(errGnome))
        end
    end

    -- Inicializar PvP Tracker (Fase 4)
    if ODD.PvP and ODD.PvP.Tracker then
        local okPvP, errPvP = pcall(function() ODD.PvP.Tracker:Initialize() end)
        if not okPvP then
            ODD:Log("Error en PvP Tracker Init: %s", tostring(errPvP))
        end
    end

    local okUI, errUI = pcall(function() ODD.UI:Initialize() end)
    if not okUI then
        ODD:Log("Error en UI Initialize: %s", tostring(errUI))
    end
end)

Events:Register("PLAYER_LOGOUT", function()
    -- Guardar datos actuales del personaje en el perfil de la cuenta compartida
    if ODD.Guild and ODD.Guild.Profiles and ODD.Guild.Profiles.SaveToGlobalProfiles then
        pcall(function() ODD.Guild.Profiles:SaveToGlobalProfiles() end)
    end

    -- Asegurar persistencia forzada en las variables globales registradas en el TOC
    if ODD.Database and ODD.Database.global then
        _G["ODDDB"] = ODD.Database.global
    end
    if ODD.Database and ODD.Database.char then
        _G["ODDCharacterDB"] = ODD.Database.char
    end
end)
