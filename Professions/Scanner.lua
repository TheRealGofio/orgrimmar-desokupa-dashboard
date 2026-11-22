local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Scanner = {}
ODD.Professions = ODD.Professions or {}
ODD.Professions.Scanner = Scanner

-- Escanea las profesiones aprendidas por el personaje local
function Scanner:ScanLocalProfessions()
    local charDB = ODD.Database:GetChar()
    if not charDB then return {} end

    charDB.observations.professions = charDB.observations.professions or { scannedAt = 0, skills = {} }
    local skills = {}

    -- En WoW nativo, GetProfessions devuelve índices: prof1, prof2, archaeology, fishing, cooking, firstAid
    if type(GetProfessions) == "function" then
        local profIndices = { GetProfessions() }
        for _, idx in ipairs(profIndices) do
            if idx and type(GetProfessionInfo) == "function" then
                local name, icon, skillLevel, maxSkillLevel, numSpells, spellOffset, skillLine, rankModifier = GetProfessionInfo(idx)
                if name then
                    table.insert(skills, {
                        name = name,
                        level = skillLevel or 0,
                        maxLevel = maxSkillLevel or 0,
                        skillLine = skillLine,
                        icon = icon,
                        origin = "local_observed",
                    })
                end
            end
        end
    end

    charDB.observations.professions.skills = skills
    charDB.observations.professions.scannedAt = time()
    _G["ODDCharacterDB"] = charDB

    ODD:Debug("Profesiones escaneadas localmente: %d encontradas.", #skills)
    return skills
end

function Scanner:GetLocalProfessions()
    local charDB = ODD.Database:GetChar()
    if charDB and charDB.observations and charDB.observations.professions and charDB.observations.professions.skills then
        if #charDB.observations.professions.skills > 0 then
            return charDB.observations.professions.skills
        end
    end
    return self:ScanLocalProfessions()
end

-- Busca artesanos en la hermandad (datos propios y declarados)
function Scanner:SearchCrafters(query)
    query = (query or ""):lower()
    local results = {}

    -- 1. Buscar en las profesiones propias
    local myProfs = self:GetLocalProfessions()
    local myName = UnitName("player") or "Tu"
    local myFullName, myRealm = UnitFullName("player")
    local myCombinedName = (myFullName and myRealm and myRealm ~= "") and (myFullName .. "-" .. myRealm) or (myFullName or myName)

    for _, prof in ipairs(myProfs) do
        if query == "" or prof.name:lower():find(query) then
            table.insert(results, {
                crafter = myName,
                profession = prof.name,
                level = prof.level,
                maxLevel = prof.maxLevel,
                isSelf = true,
                origin = "local_observed",
            })
        end
    end

    -- 2. Buscar en perfiles remotos conocidos en la base global
    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.profiles then
        for name, profile in pairs(globalDB.profiles) do
            -- Normalizar y comparar para no duplicar al jugador local si viene con o sin reino
            local cleanRemoteName = Ambiguate(name, "none")
            local cleanMyName = Ambiguate(myName, "none")
            local isLocalPlayer = (name == myName) or (name == myCombinedName) 
                                  or (cleanRemoteName:lower() == cleanMyName:lower())
                                  or (name:lower():find("^" .. cleanMyName:lower()))

            if not isLocalPlayer and profile.professions then
                for _, prof in ipairs(profile.professions) do
                    if query == "" or (prof.name and prof.name:lower():find(query)) then
                        table.insert(results, {
                            crafter = cleanRemoteName,
                            profession = prof.name,
                            level = prof.level,
                            maxLevel = prof.maxLevel,
                            isSelf = false,
                            origin = string.format("Declarado por %s (no verificado)", cleanRemoteName),
                        })
                    end
                end
            end
        end
    end

    return results
end
