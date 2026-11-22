local addonName, addonTable = ...
local ODD = addonTable.ODD

local GuildAPI = {}
ODD.API.Guild = GuildAPI

-- Lectura segura de los miembros de hermandad
function GuildAPI:RequestRoster()
    if not ODD.API.Forever:IsInGuild() then
        return false
    end

    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        C_GuildInfo.GuildRoster()
        return true
    elseif _G["GuildRoster"] and type(_G["GuildRoster"]) == "function" then
        _G["GuildRoster"]()
        return true
    end
    return false
end

-- Extrae miembros disponibles respetando campos ausentes o no disponibles
function GuildAPI:GetMembers()
    local members = {}
    if not ODD.API.Forever:IsInGuild() then
        return members
    end

    local numTotal = GetNumGuildMembers()
    for i = 1, numTotal do
        local name, rankName, rankIndex, level, classDisplayName, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
        
        if name then
            table.insert(members, {
                guid = guid,
                name = name,
                rankName = rankName,
                rankIndex = rankIndex,
                level = level,
                className = classFileName,
                zone = zone,
                online = (online == true or online == 1),
                origin = "local_observed",
            })
        end
    end

    return members
end
