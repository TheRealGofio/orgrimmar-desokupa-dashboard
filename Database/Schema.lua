local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

ODD.Database = ODD.Database or {}
local Schema = {}
ODD.Database.Schema = Schema

Schema.CURRENT_VERSION = 1

Schema.DefaultGlobalDB = {
    schemaVersion = 1,
    settings = {
        debugMode = false,
        sharePresence = true,
        shareProfile = true,
        shareStats = true,
        muteGuildAnnouncements = false, -- Si está marcado, silencia por completo el envío de anuncios al chat de hermandad
        muteSounds = false,             -- Silenciar todos los efectos de sonido de ODD
        muteErrors = true,              -- Silenciar mensajes y avisos de error del addon en el chat (activado por defecto)
        muteSoundboardChat = false,     -- Silenciar los mensajes de aviso en el chat cuando se reproducen sonidos del soundboard
        enableGnomeRadar = true,        -- Alerta sonora/visual al detectar un gnomo enemigo cercano
        showHUD = false,                -- Mostrar el HUD compacto flotante en pantalla (estilo GRS)
        hudPos = nil,                   -- Posición guardada del HUD
        theme = "classic",              -- Tema visual del marco: classic, molten, fel, frost, troll, druid, paladin
        uiScale = 1.0,                  -- Escala personalizada del Dashboard (0.7 a 1.2)
    },
    profiles = {},     -- perfiles conocidos de hermandad indexados por GUID/nombre
    rosterCache = {
        updatedAt = 0,
        members = {},
    },
    syncMeta = {
        lastSyncTimestamp = 0,
    }
}

Schema.DefaultCharacterDB = {
    schemaVersion = 1,
    identity = {
        guid = nil,
        name = nil,
        realm = nil,
        class = nil,
        race = nil,
        mainCharacter = nil,
        customRole = nil,
    },
    observations = {
        gnomes = {
            kills = 0,
            records = {},
        },
        pvp = {
            matches = {},
            nemesis = {}, -- [enemyGUID] = { name, class, race, deathsTo = number, killsOn = number, lastEncounter = timestamp, zone = string, status = "WANTED"|"AVENGED" }
        }
    }
}
