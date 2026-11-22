local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Medals = {}
ODD.Achievements = ODD.Achievements or {}
ODD.Achievements.Medals = Medals

-- Definición extensa de medallas y títulos sobre gnomos
local MEDAL_DEFS = {
    -- 1. Bajas Totales
    { id = "gnome_1", name = "Primer Desalojo", desc = "Abate a tu primer gnomo en mundo abierto.", icon = "Interface\\Icons\\Spell_Nature_Polymorph", req = 1 },
    { id = "gnome_5", name = "Control de Plagas", desc = "Abate a 5 gnomos en mundo abierto.", icon = "Interface\\Icons\\Ability_Creature_Poison_01", req = 5 },
    { id = "gnome_10", name = "Cazagnomos", desc = "Abate a 10 gnomos en mundo abierto.", icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike", req = 10 },
    { id = "gnome_25", name = "Fumigador Oficial", desc = "Abate a 25 gnomos en mundo abierto.", icon = "Interface\\Icons\\INV_Drink_05", req = 25 },
    { id = "gnome_50", name = "Azote de Gnomeregan", desc = "Abate a 50 gnomos en mundo abierto.", icon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker", req = 50 },
    { id = "gnome_75", name = "Rompeengranajes", desc = "Abate a 75 gnomos en mundo abierto.", icon = "Interface\\Icons\\INV_Misc_Gear_01", req = 75 },
    { id = "gnome_100", name = "Terror de la Alianza", desc = "Abate a 100 gnomos en mundo abierto.", icon = "Interface\\Icons\\INV_BannerPVP_02", req = 100 },
    { id = "gnome_250", name = "Exterminador Jefe", desc = "Abate a 250 gnomos en mundo abierto.", icon = "Interface\\Icons\\Ability_Warrior_SavageBlow", req = 250 },
    { id = "gnome_500", name = "Leyenda de Orgrimmar Desokupa", desc = "Abate a 500 gnomos en mundo abierto.", icon = "Interface\\Icons\\INV_Helmet_08", req = 500 },

    -- 2. Especialistas por Clase (Cadena de clase: 1, 5, 10 de cada una)
    { id = "class_mage_1", name = "Cortahechizos", desc = "Abate a un gnomo Mago.", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", reqClass = "MAGE", reqClassCount = 1 },
    { id = "class_mage_5", name = "Disipador Nato", desc = "Abate a 5 gnomos Magos.", icon = "Interface\\Icons\\Spell_Arcane_Blast", reqClass = "MAGE", reqClassCount = 5 },
    { id = "class_mage_10", name = "Extintor Arcano", desc = "Abate a 10 gnomos Magos.", icon = "Interface\\Icons\\Spell_Fire_Burnout", reqClass = "MAGE", reqClassCount = 10 },

    { id = "class_warlock_1", name = "Pisa-diablillos", desc = "Abate a un gnomo Brujo.", icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", reqClass = "WARLOCK", reqClassCount = 1 },
    { id = "class_warlock_5", name = "Purga Demoníaca", desc = "Abate a 5 gnomos Brujos.", icon = "Interface\\Icons\\Spell_Shadow_RainOfFire", reqClass = "WARLOCK", reqClassCount = 5 },
    { id = "class_warlock_10", name = "Cazademonios Diminutos", desc = "Abate a 10 gnomos Brujos.", icon = "Interface\\Icons\\Spell_Shadow_SoulLeech", reqClass = "WARLOCK", reqClassCount = 10 },

    { id = "class_rogue_1", name = "Descubierto de las Sombras", desc = "Abate a un gnomo Pícaro.", icon = "Interface\\Icons\\Ability_Stealth", reqClass = "ROGUE", reqClassCount = 1 },
    { id = "class_rogue_5", name = "Sentidos Aguzados", desc = "Abate a 5 gnomos Pícaros.", icon = "Interface\\Icons\\Ability_EyeOfTheOwl", reqClass = "ROGUE", reqClassCount = 5 },
    { id = "class_rogue_10", name = "Ni Te Escondas", desc = "Abate a 10 gnomos Pícaros.", icon = "Interface\\Icons\\Ability_CheapShot", reqClass = "ROGUE", reqClassCount = 10 },

    { id = "class_warrior_1", name = "Mordisco al Tobillo Evitado", desc = "Abate a un gnomo Guerrero.", icon = "Interface\\Icons\\Ability_Racial_Avatar", reqClass = "WARRIOR", reqClassCount = 1 },
    { id = "class_warrior_5", name = "Escudo Roto", desc = "Abate a 5 gnomos Guerreros.", icon = "Interface\\Icons\\Ability_Warrior_ShieldBreak", reqClass = "WARRIOR", reqClassCount = 5 },
    { id = "class_warrior_10", name = "Peso Pluma Fuera de Combate", desc = "Abate a 10 gnomos Guerreros.", icon = "Interface\\Icons\\Ability_Warrior_Revenge", reqClass = "WARRIOR", reqClassCount = 10 },

    { id = "class_all", name = "Desalojo Interdisciplinar", desc = "Abate al menos a un gnomo de cada clase (Mago, Brujo, Pícaro y Guerrero).", icon = "Interface\\Icons\\INV_Misc_Book_09", reqAllClasses = true },

    -- 3. Logros por Gnomos 'Gris' / Sin Experiencia (Sin Piedad)
    { id = "gnome_gray_1", name = "Sin Piedad", desc = "Abate a un gnomo de nivel gris (que no otorgue experiencia).", icon = "Interface\\Icons\\Ability_Poisons", reqGray = 1 },
    { id = "gnome_gray_10", name = "Bulería en Dun Morogh", desc = "Abate a 10 gnomos de nivel gris.", icon = "Interface\\Icons\\INV_Misc_Head_Gnome_01", reqGray = 10 },
    { id = "gnome_gray_25", name = "Abuso de Poder Desokupa", desc = "Abate a 25 gnomos de nivel gris.", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", reqGray = 25 },

    -- 4. Hazañas de Nivel Alto
    { id = "gnome_high_level", name = "Peligro en Miniatura", desc = "Abate a un gnomo de nivel 50 o superior.", icon = "Interface\\Icons\\Ability_Creature_Cursed_04", reqHighLevel = 50 },
    { id = "gnome_skull", name = "David contra Goliat al Revés", desc = "Abate a un gnomo de nivel calavera (??).", icon = "Interface\\Icons\\Spell_Shadow_DeathScream", reqSkull = true },

    -- 5. Caza Territorial
    { id = "gnome_zones_3", name = "Desokupador Itinerante", desc = "Abate gnomos en al menos 3 zonas diferentes.", icon = "Interface\\Icons\\INV_Misc_Map02", reqZones = 3 },
    { id = "gnome_zones_5", name = "Limpieza Territorial", desc = "Abate gnomos en al menos 5 zonas diferentes.", icon = "Interface\\Icons\\INV_Misc_Map08", reqZones = 5 },
    { id = "gnome_zones_10", name = "Desokupa Global", desc = "Abate gnomos en al menos 10 zonas diferentes de Azeroth.", icon = "Interface\\Icons\\INV_Misc_Spyglass_02", reqZones = 10 },
    { id = "gnome_horde_turf", name = "¡A mi casa no entras!", desc = "Abate a un gnomo dentro de Durotar o Los Baldíos.", icon = "Interface\\Icons\\INV_BannerPVP_01", reqHordeTurf = true },
    { id = "gnome_stv", name = "Safari en Tuercespina", desc = "Abate a 5 gnomos en Vega de Tuercespina.", icon = "Interface\\Icons\\Ability_Hunter_Pet_Cat", reqZoneName = "Tuercespina", reqZoneCount = 5 },
    { id = "gnome_hillsbrad", name = "Trabalomas No se Negocia", desc = "Abate a 5 gnomos en Laderas de Trabalomas.", icon = "Interface\\Icons\\Spell_Shadow_DeathPact", reqZoneName = "Trabalomas", reqZoneCount = 5 },
    { id = "gnome_home", name = "Visita a Domicilio", desc = "Abate a un gnomo en Dun Morogh o en las puertas de Gnomeregan.", icon = "Interface\\Icons\\Spell_Frost_FrostWard", reqHome = true },
    { id = "gnome_ports", name = "Control Portuario", desc = "Abate a un gnomo en Bahía del Botín o Trinquete.", icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental", reqPorts = true },

    -- 6. Situaciones Especiales y Racha
    { id = "gnome_eating", name = "Pisotón Desprevenido", desc = "Abate a un gnomo mientras esté comiendo o bebiendo.", icon = "Interface\\Icons\\INV_Misc_Fork&Knife", reqEating = 1 },
    { id = "gnome_mounted", name = "Pisa-flores", desc = "Abate a un gnomo que se desplace en Mecazancudo.", icon = "Interface\\Icons\\Ability_Mount_MechaStrider", reqMounted = 1 },
    { id = "gnome_quick_double", name = "Doble Desahucio", desc = "Abate a 2 gnomos con menos de 60 segundos de diferencia.", icon = "Interface\\Icons\\Ability_Rogue_Sprint", reqQuickDiff = 60 },
    { id = "gnome_quick_triple", name = "Desokupación Exprés", desc = "Abate a 3 gnomos en menos de 5 minutos.", icon = "Interface\\Icons\\Spell_Nature_BloodLust", reqTripleDiff = 300 },
    { id = "gnome_session_5", name = "Jornada Laboral Completa", desc = "Abate a 5 gnomos durante una misma sesión de juego.", icon = "Interface\\Icons\\INV_Misc_Coin_01", reqSessionKills = 5 },

    -- 7. Cooperación de Hermandad
    { id = "gnome_guild_group", name = "Cuadrilla de Desahucio", desc = "Abate a un gnomo estando en grupo con al menos un compañero de la hermandad.", icon = "Interface\\Icons\\Spell_Holy_PrayerOfSpirit", reqGuildGroup = 1 },
    { id = "gnome_guild_group_10", name = "Comité de Desahucio Masivo", desc = "Abate a 10 gnomos estando en grupo con compañeros de hermandad.", icon = "Interface\\Icons\\INV_BannerPVP_03", reqGuildGroup = 10 },

    -- 8. Partidas PvP
    { id = "bg_10", name = "Veterano de Batalla", desc = "Participa en 10 Campos de Batalla observados.", icon = "Interface\\Icons\\Achievement_BG_winWSG", reqBG = 10 },
}

-- Función auxiliar para calcular si un objetivo era nivel 'gris' (sin experiencia/honor)
local function IsGrayLevel(playerLevel, victimLevel)
    if not playerLevel or not victimLevel or victimLevel == "??" then return false end
    local vNum = tonumber(victimLevel)
    if not vNum then return false end

    -- Fórmula matemática estándar de WoW para nivel gris (Trivial)
    local grayThreshold = 0
    if playerLevel <= 5 then
        grayThreshold = 0
    elseif playerLevel <= 39 then
        grayThreshold = playerLevel - math.floor(playerLevel / 10) - 5
    elseif playerLevel <= 59 then
        grayThreshold = playerLevel - math.floor(playerLevel / 5) - 1
    else
        grayThreshold = playerLevel - 9
    end

    return vNum <= grayThreshold
end

function Medals:GetPlayerMedals()
    local charDB = ODD.Database:GetChar()
    local gnomes = charDB and charDB.observations and charDB.observations.gnomes
    local records = (gnomes and gnomes.records) or {}
    local gnomeKills = (gnomes and gnomes.kills) or 0
    local bgMatches = (charDB and charDB.observations and charDB.observations.pvp and charDB.observations.pvp.matches and #charDB.observations.pvp.matches) or 0
    local myLevel = UnitLevel("player") or 60

    -- Conteos detallados
    local classCounts = { ["MAGE"] = 0, ["WARLOCK"] = 0, ["ROGUE"] = 0, ["WARRIOR"] = 0 }
    local killedZones = {}
    local hasSkull = false
    local maxVictimLevel = 0
    local grayKills = 0
    local hasHordeTurf = false
    local hasHome = false
    local hasPorts = false
    local stvKills = 0
    local hillsbradKills = 0
    local eatingKills = 0
    local mountedKills = 0
    local guildGroupKills = 0
    local sessionKills = ODD.Gnomes and ODD.Gnomes.Tracker and ODD.Gnomes.Tracker.sessionKills or 0

    -- Racha temporal: detectar dobles y triples en records ordenados
    local hasDoubleQuick = false
    local hasTripleQuick = false

    for i, r in ipairs(records) do
        if r.victimClass then
            local cUpper = r.victimClass:upper()
            if classCounts[cUpper] then
                classCounts[cUpper] = classCounts[cUpper] + 1
            end
        end
        if r.zone then
            killedZones[r.zone] = true
            local zLower = r.zone:lower()
            if zLower:find("durotar") or zLower:find("baldíos") or zLower:find("baldios") or zLower:find("barrens") then
                hasHordeTurf = true
            end
            if zLower:find("dun morogh") or zLower:find("gnomeregan") then
                hasHome = true
            end
            if zLower:find("botín") or zLower:find("botin") or zLower:find("booty bay") or zLower:find("trinquete") or zLower:find("ratchet") then
                hasPorts = true
            end
            if zLower:find("tuercespina") or zLower:find("stranglethorn") then
                stvKills = stvKills + 1
            end
            if zLower:find("trabalomas") or zLower:find("hillsbrad") then
                hillsbradKills = hillsbradKills + 1
            end
        end
        if r.wasEating then
            eatingKills = eatingKills + 1
        end
        if r.wasMounted then
            mountedKills = mountedKills + 1
        end
        if r.inGuildGroup then
            guildGroupKills = guildGroupKills + 1
        end

        -- Comprobar rachas de tiempo con registros anteriores
        if i >= 2 and r.timestamp and records[i-1].timestamp then
            local diff1 = math.abs(r.timestamp - records[i-1].timestamp)
            if diff1 <= 60 then
                hasDoubleQuick = true
            end
        end
        if i >= 3 and r.timestamp and records[i-2].timestamp then
            local diff2 = math.abs(r.timestamp - records[i-2].timestamp)
            if diff2 <= 300 then
                hasTripleQuick = true
            end
        end

        if r.victimLevel == "??" then
            hasSkull = true
        else
            local lvlNum = tonumber(r.victimLevel)
            if lvlNum and lvlNum > maxVictimLevel then
                maxVictimLevel = lvlNum
            end
            if IsGrayLevel(myLevel, r.victimLevel) then
                grayKills = grayKills + 1
            end
        end
    end

    local zoneCount = 0
    for _ in pairs(killedZones) do zoneCount = zoneCount + 1 end

    local results = {}
    for _, def in ipairs(MEDAL_DEFS) do
        local completed = false
        local progress = 0
        local maxReq = 1

        if def.req then
            progress = gnomeKills
            maxReq = def.req
            completed = (gnomeKills >= def.req)
        elseif def.reqClass then
            local cUpper = def.reqClass:upper()
            progress = classCounts[cUpper] or 0
            maxReq = def.reqClassCount or 1
            completed = (progress >= maxReq)
        elseif def.reqAllClasses then
            local countClasses = 0
            if classCounts["MAGE"] > 0 then countClasses = countClasses + 1 end
            if classCounts["WARLOCK"] > 0 then countClasses = countClasses + 1 end
            if classCounts["ROGUE"] > 0 then countClasses = countClasses + 1 end
            if classCounts["WARRIOR"] > 0 then countClasses = countClasses + 1 end
            progress = countClasses
            maxReq = 4
            completed = (countClasses >= 4)
        elseif def.reqGray then
            progress = grayKills
            maxReq = def.reqGray
            completed = (grayKills >= def.reqGray)
        elseif def.reqHighLevel then
            progress = (maxVictimLevel >= def.reqHighLevel or hasSkull) and 1 or 0
            maxReq = 1
            completed = (progress >= 1)
        elseif def.reqSkull then
            progress = hasSkull and 1 or 0
            maxReq = 1
            completed = (progress >= 1)
        elseif def.reqZones then
            progress = zoneCount
            maxReq = def.reqZones
            completed = (zoneCount >= def.reqZones)
        elseif def.reqHordeTurf then
            progress = hasHordeTurf and 1 or 0
            maxReq = 1
            completed = (progress >= 1)
        elseif def.reqZoneName then
            local count = (def.reqZoneName == "Tuercespina") and stvKills or hillsbradKills
            progress = count
            maxReq = def.reqZoneCount or 1
            completed = (progress >= maxReq)
        elseif def.reqEating then
            progress = eatingKills
            maxReq = def.reqEating
            completed = (progress >= maxReq)
        elseif def.reqMounted then
            progress = mountedKills
            maxReq = def.reqMounted
            completed = (progress >= maxReq)
        elseif def.reqGuildGroup then
            progress = guildGroupKills
            maxReq = def.reqGuildGroup
            completed = (progress >= maxReq)
        elseif def.reqHome then
            progress = hasHome and 1 or 0
            maxReq = 1
            completed = (progress >= 1)
        elseif def.reqPorts then
            progress = hasPorts and 1 or 0
            maxReq = 1
            completed = (progress >= 1)
        elseif def.reqQuickDiff then
            progress = hasDoubleQuick and 1 or 0
            maxReq = 1
            completed = (progress >= 1)
        elseif def.reqTripleDiff then
            progress = hasTripleQuick and 1 or 0
            maxReq = 1
            completed = (progress >= 1)
        elseif def.reqSessionKills then
            progress = sessionKills
            maxReq = def.reqSessionKills
            completed = (sessionKills >= def.reqSessionKills)
        elseif def.reqBG then
            progress = bgMatches
            maxReq = def.reqBG
            completed = (bgMatches >= def.reqBG)
        end

        table.insert(results, {
            id = def.id,
            name = def.name,
            desc = def.desc,
            icon = def.icon,
            completed = completed,
            progress = math.min(progress, maxReq),
            maxReq = maxReq,
            origin = "derived",
        })
    end

    return results
end

-- Comprueba nuevos logros obtenidos tras una baja y dispara el Toast con sonido
function Medals:CheckNewAchievements()
    local charDB = ODD.Database:GetChar()
    if not charDB then return end

    charDB.unlockedMedals = charDB.unlockedMedals or {}
    local currentMedals = self:GetPlayerMedals()

    for _, m in ipairs(currentMedals) do
        if m.completed and not charDB.unlockedMedals[m.id] then
            -- Nuevo logro desbloqueado
            charDB.unlockedMedals[m.id] = time()
            _G["ODDCharacterDB"] = charDB

            -- Disparar Toast visual en pantalla con sonido
            if ODD.UI and ODD.UI.Toast then
                ODD.UI.Toast:Show(m.name, m.desc, m.icon)
            end
            ODD:Log("|cFFFFD100¡Logro desbloqueado!|r %s - %s", m.name, m.desc)
        end
    end
end
