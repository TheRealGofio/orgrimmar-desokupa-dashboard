local addonName, addonTable = ...
local ODD = addonTable.ODD

local Capabilities = {}
ODD.Capabilities = Capabilities

-- Tabla de capacidades evaluadas con procedencia y evidencia
local registry = {}

-- Inicializa y evalúa el entorno de WoW Forever
function Capabilities:EvaluateEnvironment()
    local version, build, date, tocversion = GetBuildInfo()
    registry["client.version"] = version
    registry["client.build"] = build
    registry["client.tocversion"] = tocversion
    registry["client.isForeverInterface"] = (tocversion == ODD.targetInterface)
    
    -- Detección de proyecto Camelot si la constante existe
    if _G["WOW_PROJECT_CAMELOT"] and _G["WOW_PROJECT_ID"] then
        registry["client.isCamelot"] = (_G["WOW_PROJECT_ID"] == _G["WOW_PROJECT_CAMELOT"])
    else
        registry["client.isCamelot"] = "unknown"
    end

    -- APIs C_Club (Roster moderno)
    registry["api.C_Club"] = (_G["C_Club"] ~= nil and type(_G["C_Club"].GetSubscribedClubs) == "function")

    -- APIs C_ChatInfo (Red de hermandad)
    registry["api.C_ChatInfo"] = (_G["C_ChatInfo"] ~= nil and type(_G["C_ChatInfo"].RegisterAddonMessagePrefix) == "function")

    -- APIs Combate
    registry["api.CombatLogGetCurrentEventInfo"] = (type(_G["CombatLogGetCurrentEventInfo"]) == "function")
    registry["api.COMBAT_LOG_EVENT_UNFILTERED"] = (type(_G["CombatLogGetCurrentEventInfo"]) == "function") -- Marcado para cautela

    -- APIs Profesiones
    registry["api.C_TradeSkillUI"] = (_G["C_TradeSkillUI"] ~= nil and type(_G["C_TradeSkillUI"].GetChildSkillLines) == "function")

    ODD:Debug("Capacidades evaluadas: Interface=%s, Build=%s, ForeverToc=%s", 
        tostring(tocversion), tostring(build), tostring(registry["client.isForeverInterface"]))
end

function Capabilities:Get(key)
    return registry[key]
end

function Capabilities:GetAll()
    return registry
end

function Capabilities:IsCompatible()
    return registry["client.isForeverInterface"] == true
end
