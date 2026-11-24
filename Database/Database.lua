local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Database = ODD.Database or {}
ODD.Database = Database

local function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
        end
    else
        copy = orig
    end
    return copy
end

local function MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = DeepCopy(v)
        elseif type(target[k]) == "table" and type(v) == "table" then
            MergeDefaults(target[k], v)
        end
    end
end

function Database:Initialize()
    local Schema = (ODD.Database and ODD.Database.Schema) or (addonTable.ODD and addonTable.ODD.Database and addonTable.ODD.Database.Schema)
    local Migrations = (ODD.Database and ODD.Database.Migrations) or (addonTable.ODD and addonTable.ODD.Database and addonTable.ODD.Database.Migrations)

    if not Schema then
        ODD:Log("Error critico: Schema no disponible en Database:Initialize")
        return
    end

    -- En WoW, las SavedVariables son inyectadas en _G por el motor justo antes de ADDON_LOADED.
    -- Si _G["ODDDB"] ya existe (cargado de WTF), respetamos su contenido y solo completamos valores por defecto ausentes.
    if _G["ODDDB"] == nil or type(_G["ODDDB"]) ~= "table" then
        _G["ODDDB"] = DeepCopy(Schema.DefaultGlobalDB)
    else
        MergeDefaults(_G["ODDDB"], Schema.DefaultGlobalDB)
    end

    if _G["ODDCharacterDB"] == nil or type(_G["ODDCharacterDB"]) ~= "table" then
        _G["ODDCharacterDB"] = DeepCopy(Schema.DefaultCharacterDB)
    else
        MergeDefaults(_G["ODDCharacterDB"], Schema.DefaultCharacterDB)
    end

    Migrations:Apply(_G["ODDDB"], _G["ODDCharacterDB"])

    self.global = _G["ODDDB"]
    self.char = _G["ODDCharacterDB"]

    ODD:Debug("Base de datos inicializada correctamente.")
end

function Database:GetGlobal()
    return self.global
end

function Database:GetChar()
    return self.char
end

-- Resetea por completo los datos locales y restaura el esquema limpio por defecto
function Database:ResetAllData()
    local Schema = ODD.Database.Schema
    if not Schema then return end

    _G["ODDDB"] = DeepCopy(Schema.DefaultGlobalDB)
    _G["ODDCharacterDB"] = DeepCopy(Schema.DefaultCharacterDB)
    self.global = _G["ODDDB"]
    self.char = _G["ODDCharacterDB"]

    ODD:Log("|cFFFF0000[ODD] Todos los datos locales han sido restablecidos a cero.|r")
end

function Database:GetSetting(key)
    if self.global and self.global.settings then
        return self.global.settings[key]
    end
    return nil
end

function Database:SetSetting(key, val)
    if not self.global then
        self.global = _G["ODDDB"]
    end
    if self.global and self.global.settings then
        self.global.settings[key] = val
        _G["ODDDB"] = self.global
        ODD:Log("Ajuste guardado: %s = %s", tostring(key), tostring(val))
    end
end
