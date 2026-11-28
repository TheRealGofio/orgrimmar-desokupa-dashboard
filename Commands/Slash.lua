local addonName, addonTable = ...
local ODD = addonTable.ODD
local L = addonTable.L

SLASH_ODD1 = "/odd"
SlashCmdList["ODD"] = function(msg)
    local success, err = pcall(function()
        local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
        cmd = (cmd or ""):lower()

        if cmd == "" or cmd == "show" or cmd == "toggle" then
            ODD.UI:Toggle()
        elseif cmd == "hud" then
            if ODD.UI and ODD.UI.HUD then
                ODD.UI.HUD:Toggle()
            end
        elseif cmd == "sync" then
            if ODD.Network and ODD.Network.Sync then
                ODD.Network.Sync:TriggerManualSync()
            end
        elseif cmd == "reset" or cmd == "wipe" or cmd == "clear" then
            ODD.Database:ResetAllData()
            if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.RefreshAll then
                ODD.UI.Dashboard:RefreshAll()
            end
            ReloadUI()
        elseif cmd == "debug" or cmd == "testing" then
            local current = ODD.Database:GetSetting("showTestingTools")
            ODD.Database:SetSetting("showTestingTools", not current)
            ODD:Log("Modo de herramientas de prueba: %s", not current and "|cFF00FF00ACTIVADO|r" or "|cFFFF0000DESACTIVADO|r")
            if ODD.UI.GnomometerTab and ODD.UI.GnomometerTab.Refresh then ODD.UI.GnomometerTab:Refresh() end
            if ODD.UI.PvPTab and ODD.UI.PvPTab.Refresh then ODD.UI.PvPTab:Refresh() end
            if ODD.UI.HistoryTab and ODD.UI.HistoryTab.Refresh then ODD.UI.HistoryTab:Refresh() end
            if ODD.UI.HQTab and ODD.UI.HQTab.RefreshMedals then ODD.UI.HQTab:RefreshMedals() end
        elseif cmd == "radar" or cmd == "testradar" then
            ODD:Log("Disparando prueba de alerta de radar...")
            if ODD.Gnomes and ODD.Gnomes.Radar and ODD.Gnomes.Radar.TriggerAlert then
                local testName = (arg and arg ~= "") and arg or "Argemus"
                ODD.Gnomes.Radar:TriggerAlert("Player-Test-01", testName, "PRIEST", 37, "target")
            end
        elseif cmd == "contract" or cmd == "contrato" then
            if ODD.Guild and ODD.Guild.Contracts then
                local p = ODD.Guild.Contracts:GetProgress()
                ODD:Log("=== CONTRATOS SEMANALES DE HERMANDAD (%s) ===", p.timeRemaining or "--")
                print(string.format("  1. |cFF00FFCC%s|r: %s -> |cFFFFD100%d/%d (%d%%)|r", p.zone.title, p.zone.zone, p.zone.current, p.zone.target, p.zone.percent))
                print(string.format("  2. |cFFFF8000%s|r: Gnomo %s -> |cFFFFD100%d/%d (%d%%)|r", p.class.title, p.class.className, p.class.current, p.class.target, p.class.percent))
            end
        elseif cmd == "testmsg" or cmd == "testchat" or cmd == "sim" then
            if arg == "kill" then
                ODD:Log("Simulando mensaje de baja silencioso...")
                if ODD.Network and ODD.Network.Sync and ODD.Network.Sync.DisplayKillInChat then
                    local pName = (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "TuPersonaje"
                    local _, pClass = UnitClass("player")
                    ODD.Network.Sync:DisplayKillInChat(pName, pClass or "SHAMAN", "Manitas", "MAGE", 42, "Laderas de Trabalomas", 19, false)
                end
            elseif arg == "achieve" or arg == "logro" then
                ODD:Log("Simulando mensaje de logro con enlace interactivo...")
                if ODD.Network and ODD.Network.Sync and ODD.Network.Sync.DisplayAchievementInChat then
                    local pName = (ODD.API and ODD.API.Forever and ODD.API.Forever:GetFullName("player")) or UnitName("player") or "TuPersonaje"
                    local _, pClass = UnitClass("player")
                    ODD.Network.Sync.DisplayAchievementInChat(nil, pName, pClass or "SHAMAN", "gnome_25", "Fumigador Oficial", 15, time(), false)
                end
            elseif arg == "update" or arg == "version" then
                ODD:Log("Simulando detección P2P de versión desactualizada...")
                local warnMsg = string.format("|cFFFF8000[ODD]|r |cFFFF2020¡Nueva versión disponible!|r Tienes una versión desactualizada (|cFFFFD100v%s|r). Ya puedes descargar la nueva versión (|cFF00FF00v0.4.0-alpha|r) desde GitHub o WowUp.",
                    tostring(ODD.version))
                DEFAULT_CHAT_FRAME:AddMessage(warnMsg)
            else
                ODD:Log("Comandos de simulación: /odd testmsg kill  |  /odd testmsg achieve  |  /odd testmsg update")
            end
        elseif cmd == "sound" or cmd == "sonido" then
            if arg == "kill" then
                ODD:Log("Reproduciendo sonido de Kill...")
                if ODD.Audio and ODD.Audio.PlayKillSound then ODD.Audio:PlayKillSound() end
            elseif arg == "achieve" or arg == "logro" then
                ODD:Log("Reproduciendo sonido de Logro...")
                if ODD.Audio and ODD.Audio.PlayAchievementSound then ODD.Audio:PlayAchievementSound() end
            elseif arg == "radar" or arg == "gnomo" or arg == "male" then
                ODD:Log("Reproduciendo sonido de Gnomo Macho (Radar)...")
                if ODD.Audio and ODD.Audio.PlayRadarAlertSound then ODD.Audio:PlayRadarAlertSound(2) end
            elseif arg == "female" or arg == "gnoma" then
                ODD:Log("Reproduciendo sonido de Gnoma Hembra (Radar)...")
                if ODD.Audio and ODD.Audio.PlayRadarAlertSound then ODD.Audio:PlayRadarAlertSound(3) end
            else
                ODD:Log("Comandos de sonido: /odd sound kill | /odd sound achieve | /odd sound male | /odd sound female")
                if ODD.Audio and ODD.Audio.PlayRadarAlertSound then ODD.Audio:PlayRadarAlertSound() end
            end
        elseif cmd == "sb" or cmd == "soundboard" then
            if arg and arg ~= "" then
                if arg == "mute" then
                    local isMuted = ODD.Database:GetSetting("muteSoundboard") or false
                    ODD.Database:SetSetting("muteSoundboard", not isMuted)
                    ODD:Log("Soundboard: %s", not isMuted and "|cFFFF2020SILENCIADO|r" or "|cFF00FF00ACTIVADO|r")
                elseif arg == "mini" or arg == "modal" or arg == "popout" or arg == "float" then
                    if ODD.UI and ODD.UI.SoundboardModal then
                        ODD.UI.SoundboardModal:Toggle()
                    end
                elseif arg:find("^play ") then
                    local sId = arg:sub(6):match("^%s*(.-)%s*$")
                    if ODD.Soundboard then ODD.Soundboard:TriggerSound(sId) end
                else
                    if ODD.Soundboard then ODD.Soundboard:TriggerSound(arg) end
                end
            else
                if ODD.UI and ODD.UI.SoundboardModal then
                    ODD.UI.SoundboardModal:Toggle()
                end
            end
        elseif cmd == "status" then
            ODD:Log("=== Estado de ODD (%s) ===", ODD.version)
            local caps = ODD.Capabilities:GetAll()
            for k, v in pairs(caps) do
                print(string.format("  - %s: |cFF00FF00%s|r", k, tostring(v)))
            end
        elseif cmd == "mock" or cmd == "demo" then
            ODD:Log("Cargando datos ficticios (MOCK) para capturas de pantalla de CurseForge...")
            local charDB = ODD.Database:GetChar()
            local globalDB = ODD.Database:GetGlobal()
            if not charDB or not globalDB then return end

            -- 1. Bajas personales simuladas
            charDB.observations = charDB.observations or {}
            charDB.observations.gnomes = charDB.observations.gnomes or {}
            local gnomes = charDB.observations.gnomes
            gnomes.kills = 48
            gnomes.stats = {
                eating = 6,
                mounted = 5,
                guildGroup = 14,
                skullOr60 = 2,
                classes = { ["MAGE"] = 18, ["WARLOCK"] = 12, ["ROGUE"] = 11, ["WARRIOR"] = 7 },
                zones = {
                    ["Vega de Tuercespina"] = 21,
                    ["Laderas de Trabalomas"] = 14,
                    ["Tierras Altas de Arathi"] = 7,
                    ["Los Baldíos"] = 4,
                    ["Tanaris"] = 2,
                }
            }

            -- 2. Historial detallado simulado (últimas 8 bajas con variedad)
            gnomes.records = {
                { victimName = "Sparkvolt", victimClass = "MAGE", victimLevel = 44, zone = "Vega de Tuercespina", wasEating = false, wasMounted = true, inGuildGroup = true, timestamp = time() - 120, origin = "local_observed" },
                { victimName = "Tinkertoy", victimClass = "ROGUE", victimLevel = 42, zone = "Vega de Tuercespina", wasEating = true, wasMounted = false, inGuildGroup = true, timestamp = time() - 340, origin = "local_observed" },
                { victimName = "Blinky", victimClass = "WARLOCK", victimLevel = 40, zone = "Laderas de Trabalomas", wasEating = false, wasMounted = false, inGuildGroup = false, timestamp = time() - 1200, origin = "local_observed" },
                { victimName = "Cogspinner", victimClass = "WARRIOR", victimLevel = 38, zone = "Laderas de Trabalomas", wasEating = false, wasMounted = false, inGuildGroup = true, timestamp = time() - 2500, origin = "local_observed" },
                { victimName = "Fizzlebang", victimClass = "MAGE", victimLevel = 45, zone = "Vega de Tuercespina", wasEating = false, wasMounted = false, inGuildGroup = false, timestamp = time() - 5400, origin = "local_observed" },
                { victimName = "Gearloose", victimClass = "WARLOCK", victimLevel = 36, zone = "Tierras Altas de Arathi", wasEating = true, wasMounted = false, inGuildGroup = false, timestamp = time() - 10800, origin = "local_observed" },
                { victimName = "Shortcircuit", victimClass = "ROGUE", victimLevel = 60, zone = "Vega de Tuercespina", wasEating = false, wasMounted = true, inGuildGroup = true, timestamp = time() - 18000, origin = "local_observed" },
                { victimName = "Micrognomo", victimClass = "MAGE", victimLevel = 19, zone = "Los Baldíos", wasEating = false, wasMounted = false, inGuildGroup = false, timestamp = time() - 43200, origin = "local_observed" },
            }

            -- 3. Desbloqueo de medallas para tener buenos puntos en el Cuartel General
            charDB.unlockedMedals = charDB.unlockedMedals or {}
            local mockUnlocked = {
                "gnome_1", "gnome_5", "gnome_10", "gnome_25",
                "class_mage_1", "class_mage_5", "class_mage_10",
                "class_warlock_1", "class_warlock_5", "class_warlock_10",
                "class_rogue_1", "class_rogue_5", "class_rogue_10",
                "class_warrior_1", "class_warrior_5", "class_all",
                "zone_stv_1", "zone_stv_5", "zone_stv_10",
                "zone_hillsbrad_1", "zone_hillsbrad_5", "zone_hillsbrad_10",
                "zone_barrens_1", "zone_arathi_1", "zone_arathi_5",
                "gnome_skull", "gnome_eating", "gnome_eating_5",
                "gnome_mounted", "gnome_mounted_5",
                "gnome_guild_group", "gnome_guild_group_10",
                "gnome_quick_double", "gnome_session_5"
            }
            for _, mId in ipairs(mockUnlocked) do
                charDB.unlockedMedals[mId] = time() - 86400
            end

            -- 4. Ranking de Hermandad simulado (Perfiles de otros compañeros de la Horda)
            globalDB.profiles = globalDB.profiles or {}
            globalDB.profiles["Grommash-Stormaxe"] = { className = "WARRIOR", gnomeKills = 74, achievementPoints = 485, lastSeen = time() - 300 }
            globalDB.profiles["Baine-Stormaxe"] = { className = "SHAMAN", gnomeKills = 52, achievementPoints = 390, lastSeen = time() - 900 }
            globalDB.profiles["Rokhan-Stormaxe"] = { className = "HUNTER", gnomeKills = 41, achievementPoints = 310, lastSeen = time() - 1800 }
            globalDB.profiles["Sylvanas-Stormaxe"] = { className = "ROGUE", gnomeKills = 33, achievementPoints = 275, lastSeen = time() - 3600 }
            globalDB.profiles["Zuljin-Stormaxe"] = { className = "PRIEST", gnomeKills = 19, achievementPoints = 160, lastSeen = time() - 7200 }
            globalDB.profiles["Varok-Stormaxe"] = { className = "WARRIOR", gnomeKills = 14, achievementPoints = 120, lastSeen = time() - 14400 }

            -- 5. Búfer de desahucios remotos en HistoryTab
            if ODD.UI and ODD.UI.HistoryTab and ODD.UI.HistoryTab.OnRemoteKillReceived then
                ODD.UI.HistoryTab:OnRemoteKillReceived({ k = "Grommash", kc = "WARRIOR", v = "Bizzlever", vc = "MAGE", vl = 46, z = "Vega de Tuercespina", tk = 74 }, "Grommash")
                ODD.UI.HistoryTab:OnRemoteKillReceived({ k = "Baine", kc = "SHAMAN", v = "Nimblespark", vc = "WARLOCK", vl = 39, z = "Laderas de Trabalomas", tk = 52 }, "Baine")
                ODD.UI.HistoryTab:OnRemoteKillReceived({ k = "Rokhan", kc = "HUNTER", v = "Clockwork", vc = "ROGUE", vl = 43, z = "Tierras Altas de Arathi", tk = 41 }, "Rokhan")
            end

            _G["ODDCharacterDB"] = charDB
            _G["ODDGlobalDB"] = globalDB

            -- Refrescar toda la interfaz activa
            if ODD.UI and ODD.UI.Dashboard and ODD.UI.Dashboard.RefreshAll then
                ODD.UI.Dashboard:RefreshAll()
            end
            if ODD.UI and ODD.UI.HUD and ODD.UI.HUD.Refresh then
                ODD.UI.HUD:Refresh()
            end

            ODD:Log("|cFF00FF00¡Datos simulados cargados con éxito!|r Abre el panel con /odd para tomar las capturas.")
        elseif cmd == "version" then
            local ver, build, _, toc = GetBuildInfo()
            ODD:Log("ODD Version: %s | Cliente: %s (Build %s, Interface %s)", ODD.version, ver, build, tostring(toc))
        else
            ODD:Log(L["CMD_HELP_TITLE"])
            print(L["CMD_HELP_SHOW"])
            print(L["CMD_HELP_STATUS"])
            print(L["CMD_HELP_VERSION"])
        end
    end)

    if not success then
        print("|cFFFF0000[ODD Error en comando]:|r " .. tostring(err))
    end
end
