local addonName, addonTable = ...

-- Espacio de nombres global y privado
local ODD = {}
addonTable.ODD = ODD
_G["ODD"] = ODD

ODD.addonName = addonName
ODD.version = "0.3.8-alpha"
ODD.targetInterface = 16001

-- Submódulos
ODD.Core = {}
ODD.Database = {}
ODD.Capabilities = {}
ODD.API = {}
ODD.Guild = {}
ODD.UI = {}

-- Función de log controlado
function ODD:Log(msg, ...)
    if select("#", ...) > 0 then
        msg = string.format(msg, ...)
    end
    print("|cFFFF8000[ODD]|r " .. tostring(msg))
end

function ODD:Debug(msg, ...)
    if ODD.Database and type(ODD.Database.GetSetting) == "function" and ODD.Database:GetSetting("debugMode") then
        if select("#", ...) > 0 then
            msg = string.format(msg, ...)
        end
        print("|cFF808080[ODD Debug]|r " .. tostring(msg))
    end
end
