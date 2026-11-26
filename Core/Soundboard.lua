local addonName, addonTable = ...
local ODD = addonTable.ODD or _G["ODD"]

local Soundboard = {}
ODD.Soundboard = Soundboard

Soundboard.SOUND_PATH = "Interface\\AddOns\\OrgrimmarDesokupaDashboard\\Media\\Soundboard\\"
Soundboard.COOLDOWN = 1.5 -- Segundos de margen entre sonidos para evitar saturación
Soundboard.lastPlayed = 0

-- Catálogo de sonidos disponibles
Soundboard.Sounds = {
    { id = "bro_que_buena_informacion", name = "Bro Buena Info",         file = "Bro que buena informacion.mp3", desc = "Bro que buena información" },
    { id = "bruh",                      name = "Bruh",                   file = "Bruh.mp3",                      desc = "Sonido clásico de decepción" },
    { id = "butano",                    name = "El Butano",              file = "butano.mp3",                    desc = "¡El butano!" },
    { id = "death_fortnite",            name = "Muerte Fortnite",        file = "Death Fortnite.mp3",            desc = "Efecto de eliminación" },
    { id = "discord",                   name = "Discord Ping",           file = "Discord.mp3",                   desc = "Notificación de Discord" },
    { id = "el_diablo",                 name = "El Diablo",              file = "El diablo.mp3",                 desc = "¡El diablo!" },
    { id = "explosion",                 name = "Explosión",              file = "Explosion.mp3",                 desc = "Gran estallido bélico" },
    { id = "faaah",                     name = "Faaah",                  file = "Faaah.mp3",                     desc = "Sonido Faaah" },
    { id = "ff_fanfare",                name = "FF Fanfarria",           file = "FF Fanfare.mp3",                desc = "Victoria Final Fantasy" },
    { id = "gemido_anime",              name = "Gemido Anime",           file = "Gemido anime.mp3",              desc = "Gemido anime" },
    { id = "la_cebolla",                name = "La Cebolla",             file = "La cebolla.mp3",                desc = "La cebolla" },
    { id = "maldito_bluetooth",         name = "Maldito Bluetooth",      file = "Maldito bluetooth.mp3",         desc = "El maldito bluetooth" },
    { id = "me_estan_matando",          name = "Me Están Matando",       file = "Me estan matando.mp3",          desc = "Grito de auxilio" },
    { id = "meow",                      name = "Miau",                   file = "Meow.mp3",                      desc = "Maullido de gato" },
    { id = "mercadona",                 name = "Mercadona",              file = "Mercadona.mp3",                 desc = "Jingle Mercadona" },
    { id = "muerte_mario",              name = "Muerte Mario",           file = "Muerte Mario.mp3",              desc = "Game over Mario Bros" },
    { id = "oh_my_god",                 name = "Oh My God",              file = "Oh my god.mp3",                 desc = "Oh my god!" },
    { id = "que_guapo",                 name = "Qué Guapo",              file = "Que guapo.mp3",                 desc = "Pero qué guapo" },
    { id = "que_te_vote_txapote",       name = "Txapote",                file = "Que te vote txapote.mp3",       desc = "Que te vote txapote" },
    { id = "quevedo_al_sol",            name = "Quédate",                file = "Quevedo al sol.mp3",            desc = "Quédate (Quevedo)" },
    { id = "rizz",                      name = "Rizz",                   file = "Rizz.mp3",                      desc = "Sonido Rizz" },
    { id = "roblox_death",              name = "Roblox Oof",             file = "Roblox death.mp3",              desc = "Muerte de Roblox (Oof)" },
    { id = "sad_violin",                name = "Violín Triste",          file = "Sad violin.mp3",                desc = "Canción triste de violín" },
    { id = "shocked",                   name = "Impactado",              file = "Shocked.mp3",                   desc = "Efecto dramático" },
    { id = "wow",                       name = "Wow Meme",               file = "WoW.mp3",                       desc = "Wow anime" },
}

Soundboard.DefaultTriggers = {
    levelUp  = "ff_fanfare",
    bossKill = "faaah",
    death    = "gemido_anime",
    loot     = "wow",
    gnomeKill = "roblox_death",
}

Soundboard.soundMap = {}
for _, s in ipairs(Soundboard.Sounds) do
    Soundboard.soundMap[s.id] = s
end

-- Comprueba si el usuario tiene el Soundboard silenciado
function Soundboard:IsMuted()
    if not ODD.Database then return false end
    return ODD.Database:GetSetting("muteSoundboard") or ODD.Database:GetSetting("muteSounds")
end

-- Obtiene el canal de audio configurado (Master, Dialog, SFX)
function Soundboard:GetChannel()
    if not ODD.Database then return "Master" end
    return ODD.Database:GetSetting("soundboardChannel") or "Master"
end

-- Obtiene el sonido por defecto para un trigger
function Soundboard:GetDefaultSound(triggerType)
    return self.DefaultTriggers[triggerType] or "bruh"
end

function Soundboard:GetSoundDisplayName(soundId, triggerType)
    if not soundId or soundId == "" then
        local defId = self:GetDefaultSound(triggerType)
        local defName = self.soundMap[defId] and self.soundMap[defId].name or defId
        return string.format("Por defecto (%s)", defName)
    end
    local sound = self.soundMap[soundId]
    return sound and sound.name or soundId
end

-- Reproduce un sonido de Soundboard localmente
function Soundboard:PlaySound(soundId, senderName)
    if self:IsMuted() then return false end

    local sound = self.soundMap[soundId]
    if not sound then
        if senderName then
            ODD:Log("|cFFFF8000[Soundboard]|r |cFFFFFFFF%s|r ha lanzado un sonido no reconocido (%s).", senderName, tostring(soundId))
        end
        return false
    end

    local now = GetTime()
    if (now - self.lastPlayed) < self.COOLDOWN then
        return false
    end
    self.lastPlayed = now

    local channel = self:GetChannel()
    local fullPath = self.SOUND_PATH .. sound.file

    local played = false
    if type(PlaySoundFile) == "function" then
        local ok, handle = pcall(PlaySoundFile, fullPath, channel)
        if ok and handle ~= false and handle ~= nil then
            played = true
        elseif channel ~= "Master" then
            pcall(PlaySoundFile, fullPath, "Master")
            played = true
        end
    end

    local displayName = senderName or (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "Tú"
    if not (ODD.Database and ODD.Database:GetSetting("muteSoundboardChat")) then
        ODD:Log("|cFFFF8000[Soundboard]|r |cFFFFFFFF%s|r ha reproducido: |cFFFFD100%s|r", displayName, sound.name)
    end

    return played
end

-- Dispara un sonido: lo reproduce localmente y lo emite por red a hermandad/grupo
function Soundboard:TriggerSound(soundId, targetScope)
    local sound = self.soundMap[soundId]
    if not sound then
        ODD:Log("|cFFFF8000[Soundboard]|r Sonido no encontrado: %s", tostring(soundId))
        return
    end

    local ok = self:PlaySound(soundId, nil)
    if ok then
        self:Broadcast(soundId, targetScope)
    end
end

-- Emisión a través del protocolo de red de ODD
-- Nota: Solo se emite si se está en Grupo (PARTY) o Banda (RAID). La hermandad queda excluida para no spamear.
function Soundboard:Broadcast(soundId, targetScope)
    if not ODD.Network or not ODD.Network.Protocol or not ODD.Network.Queue then return end

    local channel = nil
    if IsInRaid and IsInRaid() then
        channel = "RAID"
    elseif IsInGroup and IsInGroup() then
        channel = "PARTY"
    end

    -- Si no está en grupo o raid, no se emite a nadie (solo sonará en local para el jugador)
    if not channel then
        return
    end

    local msgId = ODD.Network.Protocol:GenerateMsgId()
    local line = ODD.Network.Protocol:FormatLine("SB", msgId, "*", "RAW", soundId)
    ODD.Network.Queue:Enqueue(line, channel)
end

-- Gestión de Favoritos
function Soundboard:IsFavorite(soundId)
    local globalDB = ODD.Database:GetGlobal()
    if not globalDB then return false end
    globalDB.soundboardFavs = globalDB.soundboardFavs or {}
    return globalDB.soundboardFavs[soundId] == true
end

function Soundboard:ToggleFavorite(soundId)
    local globalDB = ODD.Database:GetGlobal()
    if not globalDB then return false end
    globalDB.soundboardFavs = globalDB.soundboardFavs or {}
    globalDB.soundboardFavs[soundId] = not globalDB.soundboardFavs[soundId]
    if not globalDB.soundboardFavs[soundId] then
        globalDB.soundboardFavs[soundId] = nil
    end
    _G["ODDDB"] = globalDB
    return globalDB.soundboardFavs[soundId] == true
end

-- ==========================================================
-- Generador de Macro al hacer Shift + Clic
-- ==========================================================
function Soundboard:CreateSoundMacro(soundId)
    local sound = self.soundMap[soundId]
    if not sound then return end

    -- Si el marco de chat tiene foco, pegar el comando directamente en el texto
    if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
        local chatBox = ChatEdit_GetActiveWindow()
        chatBox:Insert(string.format("/odd sb %s", sound.id))
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        ODD:Log("|cFFFF2020No se pueden crear macros durante el combate.|r")
        return
    end

    local macroName = "ODD_" .. (sound.name:gsub("%s+", ""):sub(1, 12))
    local macroBody = string.format("#showtooltip\n/odd sb %s", sound.id)

    -- Comprobar si ya existe una macro con este nombre
    local existingIndex = GetMacroIndexByName(macroName)
    if existingIndex and existingIndex > 0 then
        EditMacro(existingIndex, macroName, "INV_Misc_Horn_01", macroBody)
        ODD:Log("Macro actualizada: |cFFFFD100%s|r (|cFF00FF00/odd sb %s|r)", macroName, sound.id)
        if PickupMacro then PickupMacro(existingIndex) end
        return
    end

    -- Comprobar espacio disponible para macros
    local globalSlots, charSlots = GetNumMacros()
    local isChar = false

    if globalSlots < 120 then
        isChar = false
    elseif charSlots < 18 then
        isChar = true
    else
        ODD:Log("|cFFFF2020No tienes huecos libres de macros (Generales o de Personaje).|r")
        print(string.format("|cFFFF8000[ODD Macro]:|r Puedes usar manualmente el comando: |cFFFFD100/odd sb %s|r", sound.id))
        return
    end

    local createdIndex = CreateMacro(macroName, "INV_Misc_Horn_01", macroBody, isChar)
    if createdIndex and createdIndex > 0 then
        ODD:Log("¡Macro creada con éxito!: |cFFFFD100%s|r (Colocada en tu cursor para ponerla en tus barras).", macroName)
        if PickupMacro then
            PickupMacro(createdIndex)
        end
    else
        ODD:Log("Comando para tu macro: |cFFFFD100/odd sb %s|r", sound.id)
    end
end

-- ==========================================================
-- Triggers automáticos por eventos del juego (Muerte, Boss, Loot, Ding, Desahucio)
-- ==========================================================
local triggerFrame = CreateFrame("Frame")
function Soundboard:RegisterAutoTriggers()
    triggerFrame:RegisterEvent("PLAYER_LEVEL_UP")
    triggerFrame:RegisterEvent("PLAYER_DEAD")
    triggerFrame:RegisterEvent("BOSS_KILL")
    triggerFrame:RegisterEvent("ENCOUNTER_END")
    triggerFrame:RegisterEvent("START_LOOT_ROLL")
    triggerFrame:RegisterEvent("CHAT_MSG_LOOT")
    triggerFrame:RegisterEvent("CHAT_MSG_SYSTEM")

    local lastDeadTime = 0
    local lastBossTime = 0
    local lastLootTime = 0
    local processedRolls = {}

    local function TriggerLootSound(name, quality, link)
        if Soundboard:IsMuted() then return end
        local db = ODD.Database
        if not db:GetSetting("sbTriggerLoot") then return end

        local minRarity = db:GetSetting("sbTriggerLootGreens") and 2 or 3
        if quality and quality >= minRarity then
            local now = GetTime()
            if (now - lastLootTime) > 4 then
                lastLootTime = now
                local soundId = db:GetSetting("sbTriggerLootSound")
                if not soundId or soundId == "" then
                    soundId = Soundboard:GetDefaultSound("loot")
                end
                Soundboard:TriggerSound(soundId)
            end
        end
    end

    local function HandleRollID(rollID)
        if not rollID or processedRolls[rollID] then return end
        local db = ODD.Database
        if not db:GetSetting("sbTriggerLoot") then return end

        local texture, name, count, quality = nil, nil, nil, nil
        if GetLootRollItemInfo then
            texture, name, count, quality = GetLootRollItemInfo(rollID)
        end
        local link = GetLootRollItemLink and GetLootRollItemLink(rollID)

        if not quality or quality == 0 then
            if link then
                local _, _, q = GetItemInfo(link)
                if q then quality = q end
            end
        end

        if quality and quality > 0 then
            processedRolls[rollID] = true
            TriggerLootSound(name, quality, link)
        else
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, function()
                    if processedRolls[rollID] then return end
                    local _, rName, _, rQuality = nil, nil, nil, nil
                    if GetLootRollItemInfo then
                        _, rName, _, rQuality = GetLootRollItemInfo(rollID)
                    end
                    local rLink = GetLootRollItemLink and GetLootRollItemLink(rollID)
                    if not rQuality or rQuality == 0 then
                        if rLink then
                            local _, _, q = GetItemInfo(rLink)
                            if q then rQuality = q end
                        end
                    end
                    if rQuality and rQuality > 0 then
                        processedRolls[rollID] = true
                        TriggerLootSound(rName, rQuality, rLink)
                    end
                end)
            end
        end
    end

    if hooksecurefunc and GroupLootFrame_OnShow then
        hooksecurefunc("GroupLootFrame_OnShow", function(frame)
            if frame and frame.rollID then
                HandleRollID(frame.rollID)
            end
        end)
    end

    local function CheckAndFireLootFromText(itemLink, rawMsg)
        if not itemLink then return end
        local itemName, _, itemRarity = GetItemInfo(itemLink)

        if not itemRarity then
            local hexColor = (itemLink and itemLink:match("|c(%x%x%x%x%x%x%x%x)"))
                          or (rawMsg and rawMsg:match("|c(%x%x%x%x%x%x%x%x)"))
            if hexColor then
                hexColor = hexColor:lower()
                if hexColor == "ffa335ee" then itemRarity = 4
                elseif hexColor == "ff0070dd" then itemRarity = 3
                elseif hexColor == "ff1eff00" then itemRarity = 2
                elseif hexColor == "ffff8000" then itemRarity = 5
                elseif hexColor == "ffe6cc80" then itemRarity = 7
                end
            end
        end

        if itemRarity then
            TriggerLootSound(itemName, itemRarity, itemLink)
        end
    end

    triggerFrame:SetScript("OnEvent", function(self, event, ...)
        if Soundboard:IsMuted() then return end
        local db = ODD.Database

        if event == "PLAYER_LEVEL_UP" then
            if db:GetSetting("sbTriggerLevelUp") then
                local sId = db:GetSetting("sbTriggerLevelUpSound")
                if not sId or sId == "" then sId = Soundboard:GetDefaultSound("levelUp") end
                Soundboard:TriggerSound(sId)
            end

        elseif event == "PLAYER_DEAD" then
            local now = GetTime()
            if db:GetSetting("sbTriggerDeath") and (now - lastDeadTime > 10) then
                lastDeadTime = now
                local sId = db:GetSetting("sbTriggerDeathSound")
                if not sId or sId == "" then sId = Soundboard:GetDefaultSound("death") end
                Soundboard:TriggerSound(sId)
            end

        elseif event == "BOSS_KILL" or event == "ENCOUNTER_END" then
            local now = GetTime()
            if db:GetSetting("sbTriggerBossKill") and (now - lastBossTime > 15) then
                local success = true
                if event == "ENCOUNTER_END" then
                    local _, _, _, _, successFlag = ...
                    success = (successFlag == 1)
                end
                if success then
                    lastBossTime = now
                    local sId = db:GetSetting("sbTriggerBossKillSound")
                    if not sId or sId == "" then sId = Soundboard:GetDefaultSound("bossKill") end
                    Soundboard:TriggerSound(sId)
                end
            end

        elseif event == "START_LOOT_ROLL" then
            local rollID = ...
            if rollID then HandleRollID(rollID) end

        elseif event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_SYSTEM" then
            if db:GetSetting("sbTriggerLoot") then
                local message = ...
                if message and type(message) == "string" and message:find("|Hitem:") then
                    local itemLink = message:match("(|c%x+|Hitem:[^|]+|h%[[^%]]+%]h|r)")
                                  or message:match("(|c%x+|Hitem:[^|]+|h.-|h|r)")
                                  or message:match("(|Hitem:[^|]+|h%[[^%]]+%]h)")
                                  or message:match("(|Hitem:[^|]+|h.-|h)")
                    if itemLink then
                        CheckAndFireLootFromText(itemLink, message)
                    end
                end
            end
        end
    end)
end

-- Inicialización
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    Soundboard:RegisterAutoTriggers()
end)
