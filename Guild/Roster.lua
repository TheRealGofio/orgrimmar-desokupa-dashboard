local addonName, addonTable = ...
local ODD = addonTable.ODD

local Roster = {}
ODD.Guild.Roster = Roster

function Roster:Refresh()
    if not ODD.API.Forever:IsInGuild() then
        return {}
    end

    local members = ODD.API.Guild:GetMembers()
    local globalDB = ODD.Database:GetGlobal()
    if globalDB then
        globalDB.rosterCache.updatedAt = time()
        globalDB.rosterCache.members = members
    end

    ODD:Debug("Roster refrescado con %d miembros.", #members)
    return members
end

function Roster:GetCachedMembers()
    local globalDB = ODD.Database:GetGlobal()
    if globalDB and globalDB.rosterCache and globalDB.rosterCache.members then
        return globalDB.rosterCache.members
    end
    return {}
end

function ODD.Guild:OnPlayerLogin()
    local okProf, errProf = pcall(function() ODD.Guild.Profiles:UpdateLocalProfile() end)
    if not okProf then
        ODD:Log("Error en UpdateLocalProfile: %s", tostring(errProf))
    end

    if ODD.API.Forever:IsInGuild() then
        ODD.Events:Register("GUILD_ROSTER_UPDATE", function()
            Roster:Refresh()
        end)
        
        pcall(function() ODD.API.Guild:RequestRoster() end)
        
        -- Iniciar red y anunciar presencia con jitter
        if ODD.Network and ODD.Network.Sync then
            local okNet, errNet = pcall(function()
                ODD.Network.Sync:Initialize()
                ODD.Network.Sync:BroadcastHello()
            end)
            if not okNet then
                ODD:Log("Error en Network Sync Init: %s", tostring(errNet))
            end
        end
    end
end
