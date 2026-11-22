local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

ODD.Database = ODD.Database or {}
local Migrations = {}
ODD.Database.Migrations = Migrations

-- Conjunto de migraciones secuenciales por version
local steps = {
    -- [2] = function(db, charDB) ... end
}

function Migrations:Apply(db, charDB)
    local v = db.schemaVersion or 1
    local target = ODD.Database.Schema.CURRENT_VERSION

    if v < target then
        ODD:Log("Migrando base de datos de versión %d a %d...", v, target)
        for stepVersion = v + 1, target do
            if steps[stepVersion] then
                steps[stepVersion](db, charDB)
            end
        end
        db.schemaVersion = target
        if charDB then
            charDB.schemaVersion = target
        end
    end
end
