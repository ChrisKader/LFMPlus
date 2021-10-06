local addonName = ... ---@type string @The name of the addon.
local ns = select(2, ...) ---@type ns @The addon namespace.
local LFMPlus = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale(addonName, false)
local db

local defaults = {
    global = {
        --Control Panel Defaults
        enabled = true,
        showLeaderScore = true,
        showClassColors = true,
        showRealmName = true,
        shortenActivityName = true,
        alwaysShowFriends = true,
        lfgListingDoubleClick = true,
        signupOnEnter = false,
        autoFocusSignUp = false,
        alwaysShowRoles = false,
        hideAppViewerOverlay = false,
        enableLFGDropdown = true,
        excludePlayerList = true,
        flagPlayer = false,
        filterPlayer = false,
        flagPlayerList = {},
        excludeRealmList = true,
        flagRealm = false,
        filterRealm = false,
        flagRealmList = {},
        activeRoleFilter = false,
        classFilter = false,
        --UI Defaults
        ratingFilter = false,
        ratingFilterMin = 0,
        ratingFilterMax = 0,
        dungeonFilter = false,
    }
}

ns.CONSTANTS = {
    ratingMin = 0,
    ratingMax = 3500,
    atlas = {
        DAMAGER = "groupfinder-icon-role-large-dps",
        TANK = "groupfinder-icon-role-large-tank",
        HEALER = "groupfinder-icon-role-large-healer",
        NA = "communities-icon-redx"
    },
}

ns.Init = false;

ns.realmFilterPresets = {
    ["US - Oceanic"] = {
        description = "List of Oceanic Realms for the US Region",
        realms = {
            ["Aman'Thul"] = true,
            ["Caelestrasz"] = true,
            ["Dath'Remar"] = true,
            ["Khaz'goroth"] = true,
            ["Nagrand"] = true,
            ["Saurfang"] = true,
            ["Barthilas"] = true,
            ["Dreadmaul"] = true,
            ["Frostmourne"] = true,
            ["Gundrak"] = true,
            ["Jubei'Thos"] = true,
            ["Thaurissan"] = true,
        }
    },
}

ns.DebugLog = function(text, type)
    local messagePrefix = "|cFF00FF00LFM+ Debug:|r "
    if ns.DEBUG_ENABLED then
        local message = text and tostring(text) or ""
        if type then
            if type == "EVENT" then
                message = "|cFFFFF12C" .. message .. "|r"
            elseif type == "WARN" then
                message = "|cFF00FF00" .. message .. "|r"
            else
                message = message
            end
        else
            message = message
        end
        print(messagePrefix .. message);
    end
end

ns.HooksRan = false

ns.ScoreList = {100,200,300,400,500,600,700,800,900,1000,1100,1200,1300,1400,1500,1600,1700,1800,1900,2000,2100,2200,2300,2400,2500,2600,2700,2800,2900,3000}

--local LFMPlusFrame = LFMPlusFrame

local function formatMPlusRating(score)
    if not score or type(score) ~= "number" then
        score = 0
    end

    -- If the score is 1000 or larger, divide by 1000 to get a decimal, get the first 3 characters to prevent rounding and then add a K. Ex: 2563 = 2.5k
    -- If the score is less than 1000, we simply store it in the shortScore variable.

    local shortScore = score >= 1000 and string.format("%3.2f", score/1000):sub(1,3) .. "k" or score
    local formattedScore = C_ChallengeMode.GetDungeonScoreRarityColor(score):WrapTextInColorCode(shortScore)
    return formattedScore
end

local options = {
    type = "group",
    name = L["LFMPlus"],
    desc = L["LFMPlus"],
    get = function(info) return db[info.arg] end,
    args = {
        enabled = {
            type = "toggle",
            name = L["Enable LFMPlus"],
            desc = L["Enable or disable LFMPlus"],
            order = 1,
            arg = "enabled",
            set = function(info, v)
                db[info.arg] = v
                if v then LFMPlus:Enable() else LFMPlus:Disable() end
            end,
            disabled = false,
        },
        lfgListing = {
            type = "group",
            name = L["LFG Listings"],
            desc = L["Settings that modify how listings in LFG are shown."],
            descStyle = "inline",
            order = 10,
            get = function(info) return db[info.arg] end,
            set = function(info, v)
                db[info.arg] = v
                LFMPlus:FilterChanged()
            end,
            disabled = function() return not db.enabled end,
            args = {
                showLeaderScore = {
                    type = "toggle",
                    width = "full",
                    name = L["Show Leader Score"],
                    descStyle = "inline",
                    desc = L["Toggle appending the group leaders score to the start of group listings in LFG."],
                    arg = "showLeaderScore",
                    order = 10,
                },
                showLeaderScoreDesc = {
                    type = "description",
                    width = "full",
                    name = "         " .. formatMPlusRating(2200) .. " " .. NORMAL_FONT_COLOR:WrapTextInColorCode("19 PF LUST"),
                    fontSize = "medium",
                    order = 11,
                },
                showClassColors = {
                    type = "toggle",
                    width = "full",
                    name = L["Show Class Colors"],
                    desc = L["Toggle the visbility of bars under the role icons of groups listed in LFG."],
                    descStyle = "inline",
                    arg = "showClassColors",
                    order = 20,
                },
                showRealmName = {
                    type = "toggle",
                    width = "full",
                    name = L["Show Realm Name"],
                    desc = L["Toggle the visbility of the leaders realm.\nShorten Dungeon Names will be enabled as well."],
                    descStyle = "inline",
                    arg = "showRealmName",
                    set = function(info, v)
                        db[info.arg] = v
                        if v and not db.shortenActivityName then
                            db.shortenActivityName = true
                        end
                        LFMPlus:FilterChanged()
                    end,
                    order = 30,
                },
                shortenActivityName = {
                    type = "toggle",
                    width = "full",
                    name = L["Shorten Dungeon Names"],
                    desc = L["Toggle the length of dungeon names in LFG listings."],
                    descStyle = "inline",
                    arg = "shortenActivityName",
                    order = 40,
                },
                alwaysShowFriends = {
                    type = "toggle",
                    width = "full",
                    name = L["Friends or Guildies"],
                    desc = L["If enabled, LFM+ will always show groups or applicants if they include Friends or Guildies"],
                    descStyle = "inline",
                    arg = "alwaysShowFriends",
                    order = 50,
                },
            },
        },
        uiEnhancements = {
            type = "group",
            name = L["UI Enhancements"],
            desc = L["Settings that make enhancements to the default UI to improve functionality"],
            descStyle = "inline",
            order = 20,
            get = function(info) return db[info.arg] end,
            set = function(info, v)
                db[info.arg] = v
                LFMPlus:FilterChanged()
            end,
            disabled = function() return not db.enabled end,
            args = {
                lfgListingDoubleClick = {
                    type = "toggle",
                    width = "full",
                    name = L["Enable Double-Click Sign Up"],
                    desc = L["Toggle the ability to double-click on LFG listings to bring up the sign-up dialog."],
                    descStyle = "inline",
                    arg = "lfgListingDoubleClick",
                    order = 10,
                },
                autoFocusSignUp = {
                    type = "toggle",
                    width = "full",
                    name = L["Auto Focus Sign Up Box"],
                    desc = L["Toggle the abiity to have description field of the Sign Up box auto focused when you sign up for a listing."],
                    descStyle = "inline",
                    arg = "autoFocusSignUp",
                    order = 20,
                },
                signupOnEnter = {
                    type = "toggle",
                    width = "full",
                    name = L["Sign Up On Enter"],
                    desc = L["Toggle the abiity to press the Sign Up button after pressing enter while typing in the description field when applying for listings."],
                    descStyle = "inline",
                    arg = "signupOnEnter",
                    order = 30,
                },
                alwaysShowRoles = {
                    type = "toggle",
                    width = "full",
                    name = L["Always Show Listing Roles"],
                    desc = L["Toggle the ability to show what slots have filled for an LFG listing, even if you have applied for it."],
                    descStyle = "inline",
                    arg = "alwaysShowRoles",
                    order = 40,
                },
                hideAppViewerOverlay = {
                    type = "toggle",
                    width = "full",
                    name = L["Hide Application Viewer Overlay"],
                    desc = L["Toggle the ability to hide the overlay shown in the application viewer, even if you are not the group leader."],
                    descStyle = "inline",
                    arg = "hideAppViewerOverlay",
                    order = 50,
                },
                flagRealmGroup = {
                    type = "group",
                    name = L["Realm Flag/Filter Options"],
                    desc = L["Options for indicating or filtering out specific realms"],
                    args = {
                        excludeRealmList = {
                            type = "toggle",
                            width = "full",
                            descStyle = "inline",
                            name = L["Inclusive/Exclusive Realm List"],
                            desc = L["InclusiveExclusiveRealm"],
                            arg = "excludeRealmList",
                            order = 1,
                        },
                        flagRealm = {
                            type = "toggle",
                            width = "full",
                            descStyle = "inline",
                            name = L["Flag Realms"],
                            desc = L["Toggle the ability to indicate if the realm of an LFG listing or applicant is listed below."],
                            arg = "flagRealm",
                            set = function(info, v)
                                db[info.arg] = v
                                if v then
                                    db.filterRealm = not v
                                end
                            end,
                            order = 10,
                        },
                        filterRealm = {
                            type = "toggle",
                            width = "full",
                            descStyle = "inline",
                            name = L["Filter Realms"],
                            desc = L["Toggle the ability to filter out LFG listings or applicants if they belong to a realm listed below."],
                            arg = "filterRealm",
                            set = function(info, v)
                                db[info.arg] = v
                                if v then
                                    db.flagRealm = not v
                                end
                                LFMPlus:FilterChanged()
                            end,
                            order = 20,
                        },
                        flagRealmList = {
                            type = "multiselect",
                            width = "full",
                            descStyle = "inline",
                            name = L["Realms"],
                            desc = L["Realms selected below will be selected for filtering/flagging"],
                            values = function()
                                local rtnVal = {}
                                for k,_ in pairs(db.flagRealmList) do
                                    rtnVal[k] = k
                                end
                                return rtnVal
                            end,
                            get = function(info,key)
                                return db[info.arg][key]
                            end,
                            set = function(info, value)
                                db[info.arg][value] = not db[info.arg][value]
                                local newTbl = {}
                                for k,v in pairs(db[info.arg]) do
                                    if (k ~= value) or v then
                                        newTbl[k] = v
                                    end
                                end
                                db[info.arg] = newTbl
                                LFMPlus:FilterChanged()
                            end,
                            arg = "flagRealmList",
                            order = 30,
                        },
                        setDefaultList = {
                            type = "select",
                            width = "full",
                            descStyle = "inline",
                            name = L["Populate from Default List"],
                            desc = L["Override the current realm list with one that is shipped with the addon."],
                            arg = "flagRealmList",
                            confirm = true,
                            confirmText = L["The current realm list will be completely REPLACED by the list chosen."],
                            values = function()
                                local rtnVal = {}
                                for k,_ in pairs(ns.realmFilterPresets) do
                                    rtnVal[k] = k
                                end
                                return rtnVal
                            end,
                            set = function(info, value)
                                if ns.realmFilterPresets[value] then
                                    db[info.arg] = ns.realmFilterPresets[value].realms
                                end
                                LFMPlus:FilterChanged()
                            end,
                            order = 40,
                        },
                    }
                },
                flagPlayerGroup = {
                    type = "group",
                    name = L["Player Flag/Filter Options"],
                    desc = L["Options for indicating or filtering out specific players"],
                    args = {
                        excludePlayerList = {
                            type = "toggle",
                            width = "full",
                            descStyle = "inline",
                            name = L["Inclusive/Exclusive Player List"],
                            desc = L["InclusiveExclusivePlayer"],
                            arg = "excludePlayerList",
                            order = 1,
                        },
                        flagPlayer = {
                            type = "toggle",
                            width = "full",
                            descStyle = "inline",
                            name = L["Flag players"],
                            desc = L["Toggle the ability to indicate if the player of an LFG listing or applicant is listed below."],
                            arg = "flagPlayer",
                            set = function(info, v)
                                db[info.arg] = v
                                if v then
                                    db.filterPlayer = not v
                                end
                                LFMPlus:FilterChanged()
                            end,
                            order = 10,
                        },
                        filterPlayer = {
                            type = "toggle",
                            width = "full",
                            descStyle = "inline",
                            name = L["Filter players"],
                            desc = L["Toggle the ability to filter out LFG listings or applicants if they belong to a player listed below."],
                            arg = "filterPlayer",
                            set = function(info, v)
                                db[info.arg] = v
                                if v then
                                    db.flagPlayer = not v
                                end
                                LFMPlus:FilterChanged()
                            end,
                            order = 20,
                        },
                        flagPlayerList = {
                            type = "multiselect",
                            width = "full",
                            descStyle = "inline",
                            name = L["Players"],
                            desc = L["Players selected below will be selected for filtering/flagging"],
                            values = function()
                                local rtnVal = {}
                                for k,_ in pairs(db.flagPlayerList) do
                                    rtnVal[k] = k
                                end
                                return rtnVal
                            end,
                            get = function(info,key)
                                return db[info.arg][key]
                            end,
                            set = function(info, value)
                                db[info.arg][value] = not db[info.arg][value]
                                local newTbl = {}
                                for k,v in pairs(db[info.arg]) do
                                    if (k ~= value) or v then
                                        newTbl[k] = v
                                    end
                                end
                                db[info.arg] = newTbl
                                LFMPlus:FilterChanged()
                            end,
                            arg = "flagPlayerList",
                            order = 30,
                        },
                    }
                }
            },
        },
    }
}

LFMPlusFrame:RegisterEvent("ADDON_LOADED");

    -- UTILITY FUNCTIONS --
local showTooltip = function(self)
    if(self.tooltipText ~= nil) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip_SetTitle(GameTooltip, self.tooltipText);
        GameTooltip:Show();
    end
end

local hideTooltip = function()
    if GameTooltip:IsShown() then
        GameTooltip:Hide();
    end
end

local function addFilteredId(self, id)
    if (not self.filteredIDs) then
        self.filteredIDs = {}
    end
    tinsert(self.filteredIDs, id)
end

local function filterTable(t, ids)
    LFMPlusFrame.filteredIDs = {}
    for _, id in ipairs(ids) do
        for j = #t, 1, -1 do
            if (t[j] == id) then
                tremove(t, j)
                tinsert(LFMPlusFrame.filteredIDs, id)
                break
            end
        end
    end
end

local function getIndex(values, val)
    local index = {}
    for k, v in pairs(values) do
        index[v] = k
    end
    return index[val]
end

function LFMPlus:checkRealm(realm)
    local rtnVal = db.flagRealmList[realm] or false
    if realm then
        if db.excludeRealmList then
            return rtnVal
        else
            return not rtnVal
        end
    end
end

function LFMPlus:checkPlayer(player)
    local rtnVal = db.flagPlayerList[player] or false
    if player then
        if db.excludePlayerList then
            return rtnVal
        else
            return not rtnVal
        end
    end
end

ns.DEBUG_ENABLED = false;

ns.EVENTS = {
    ["LFG_LIST_AVAILABILITY_UPDATE"] = false,
    ["LFG_LIST_ACTIVE_ENTRY_UPDATE"] = false,
    ["LFG_LIST_ENTRY_CREATION_FAILED"] = false,
    ["LFG_LIST_SEARCH_RESULTS_RECEIVED"] = false,
    ["LFG_LIST_SEARCH_RESULT_UPDATED"] = false,
    ["LFG_LIST_SEARCH_FAILED"] = false,
    ["LFG_LIST_APPLICANT_LIST_UPDATED"] = false,
    ["LFG_LIST_APPLICANT_UPDATED"] = false,
    ["LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS"] = false,
    ["LFG_LIST_ENTRY_EXPIRED_TIMEOUT"] = false,
    ["LFG_LIST_APPLICATION_STATUS_UPDATED"] = false,
    ["LFG_GROUP_DELISTED_LEADERSHIP_CHANGE"] = false,
    ["PLAYER_SPECIALIZATION_CHANGED"] = true,
}

LFMPlus.visibility = "HIDE"

ns.ACTIVITY_INFO = {
    [691] = { shortName = "PF", mapId = 379 },
    [695] = { shortName = "DOS", mapId = 377 },
    [699] = { shortName = "HOA", mapId = 378 },
    [703] = { shortName = "MOTS", mapId = 375 },
    [705] = { shortName = "SD", mapId = 380 },
    [709] = { shortName = "SOA", mapId = 381 },
    [713] = { shortName = "NW", mapId = 376 },
    [717] = { shortName = "TOP", mapId = 382 },
}

LFMPlusFrame.frames = {
    search = {},
    app = {},
    all = {}
}

LFMPlusFrame.filteredIDs = {}
LFMPlusFrame.totalResults = 0

local function EventHandler(event, ...)
    if event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        if LFGListFrame.SearchPanel:IsShown() then
            local resultID = ...
            local _, appStatus, pendingStatus, appDuration = C_LFGList.GetApplicationInfo(resultID);
            local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
            if ( appStatus == "none" and searchResultInfo.isDelisted ) then
                for k,v in pairs(LFGListFrame.SearchPanel.results) do
                    if v == resultID then
                        tremove(LFGListFrame.SearchPanel.results, k)
                        LFMPlus:RefreshResults()
                    end
                end
            end
        end
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unitId = ...
        if unitId == "player" then
            LFMPlusFrame.activeRoleFrame:UpdateRoleIcon()
        end
    end
end

-- Register Events
for k,v in pairs(ns.EVENTS) do
    if v then
        LFMPlus:RegisterEvent(k,EventHandler);
    end
end

function LFMPlus:GetDungeonInfo(activityId)
    if LFMPlusFrame.dungeonList[activityId] then
        return true
    else
        return false
    end
end

function LFMPlus:GetDungeonList()
    local activityIDs = C_LFGList.GetAvailableActivities(2, nil, 1)
    local mapChallengeModeIDs = C_ChallengeMode.GetMapTable()
    local mapChallengeModeInfo = {}
    local dropdownList = {}
    for _,mapChallengeModeID in pairs(mapChallengeModeIDs) do
        local name, id, timeLimit, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
        table.insert(mapChallengeModeInfo,{
                name = name,
                activityID = nil,
                shortName = nil,
                challMapID = id,
                timeLimit = timeLimit,
                texture = texture,
                backgroundTexture = backgroundTexture
        })
    end
    for _,activityID in pairs(activityIDs) do
        local fullName, _, _, _, _, _, _, _, _, _, _, _, isMythicPlus, _, _ = C_LFGList.GetActivityInfo(activityID)
        if isMythicPlus then
            for _,challMap in pairs(mapChallengeModeInfo) do
                if fullName:find(challMap.name) then
                    local dungeon = challMap
                    dungeon.activityID = activityID
                    dungeon.shortName = ns.ACTIVITY_INFO[activityID].shortName or fullName
                    dungeon.checked = false
                    LFMPlusFrame.dungeonList[activityID] = dungeon
                    dropdownList[activityID] = challMap.name
                    LFMPlusFrame.dungeonListLoaded = true
                end
            end
        end
    end

    LFMPlusFrame.dungeonDropdownFrame:SetList(dropdownList);
end

function LFMPlus:GetClassList()
    local dropdownList = {}

    for i=1,GetNumClasses() do
        local name, file, id = GetClassInfo(i)
        local coloredName = RAID_CLASS_COLORS[file]:WrapTextInColorCode(name)

        LFMPlusFrame.classList[file] = {
            coloredName = coloredName,
            id = id,
            name = name,
            checked = false,
        }

        dropdownList[file] = coloredName
    end
    db.classFilter = false
    LFMPlusFrame.classDropdownFrame:SetList(dropdownList)
    LFMPlusFrame.classListLoaded = true
end

function LFMPlusFrame_ScoreMin:SetDisplayValue(value)
    self.noclick = true;
    self:SetValue(value);
    self.Value:SetText(formatMPlusRating(value));
    db.ratingFilterMin = value
    db.ratingFilter = value > 0
    LFMPlus:RefreshResults()
    self.noclick = false;
end

function LFMPlusFrame_ScoreMin:SetEnable(value)
    if value then
        self:Enable()
        self:SetAlpha(1)
    else
        self:Disable()
        self:SetAlpha(.5)
    end
end

LFMPlusFrame_ScoreMin:SetScript("OnValueChanged",function(s, value)
    LFMPlusFrame_ScoreMin:SetDisplayValue(value)
end)

LFMPlusFrame_ScoreMin:SetBackdrop(LFMPlusFrame_ScoreMin:GetBackdrop())

LFMPlusFrame.resultsFrame = LFMPlusFrame_results
LFMPlusFrame.scoreMinFrame = LFMPlusFrame_ScoreMin

LFMPlusFrame.frames.search["resultsFrame"] = true
LFMPlusFrame.frames.search["scoreMinFrame"] = true
LFMPlusFrame.frames.app["scoreMinFrame"] = true
local SortSearchResults = function(results)
    if LFGListFrame.CategorySelection.selectedCategory ~= 2 then
        return
    end
    local roleRemainingKeyLookup = {
        ["TANK"] = "TANK_REMAINING",
        ["HEALER"] = "HEALER_REMAINING",
        ["DAMAGER"] = "DAMAGER_REMAINING"
    }

    local RemainingSlotsForLocalPlayerRole = function(lfgSearchResultID)
        local roles = C_LFGList.GetSearchResultMemberCounts(lfgSearchResultID)
        local playerRole = GetSpecializationRole(GetSpecialization())
        return roles[roleRemainingKeyLookup[playerRole]] > 0
    end

    local HasRemainingSlotsForLocalPlayerRole = function(lfgSearchResultID)
        local roles = C_LFGList.GetSearchResultMemberCounts(lfgSearchResultID)
        local playerRole = GetSpecializationRole(GetSpecialization())
        return roles[roleRemainingKeyLookup[playerRole]] > 0
    end

    local FilterSearchResults = function(searchResultID)
        local searchResultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
        if searchResultInfo then
            -- Never filter listings with friends or guildies.
            local filterFriends = db.alwaysShowFriends and ((searchResultInfo.numBNetFriends or 0) + (searchResultInfo.numCharFriends or 0) + (searchResultInfo.numGuildMates or 0)) > 0 or false
            if LFMPlus.visibility == "search" and (not filterFriends) then
                local leaderName = searchResultInfo.leaderName or ""
                local realmName = leaderName:find("-") ~= nil and string.sub(leaderName, leaderName:find("-") + 1, string.len(leaderName)) or GetRealmName()
                local filterRole = db.activeRoleFilter and not RemainingSlotsForLocalPlayerRole(searchResultID) or false
                local filterRating = db.ratingFilter and not (searchResultInfo.leaderOverallDungeonScore and searchResultInfo.leaderOverallDungeonScore >= db.ratingFilterMin or false) or false
                local filterRealm = db.filterRealm and LFMPlus:checkRealm(realmName) or false
                local filterPlayer = db.filterPlayer and LFMPlus:checkPlayer(leaderName) or false
                local filterDungeon = (db.dungeonFilter and LFMPlusFrame.dungeonDropdownFrame:GetUserData("selectedCount") > 0) and LFMPlusFrame.dungeonList[searchResultInfo.activityID] == nil or false
                local filterActivity = (db.dungeonFilter and LFMPlusFrame.dungeonList[searchResultInfo.activityID] and LFMPlusFrame.dungeonDropdownFrame:GetUserData("selectedCount") > 0) and (not LFMPlusFrame.dungeonList[searchResultInfo.activityID].checked) or false
                if(filterRole or filterRating or filterRealm or filterDungeon or filterPlayer or filterActivity)  then
                    addFilteredId(LFGListFrame.SearchPanel, searchResultID)
                end
            else
                if LFGListFrame.SearchPanel.filteredIDs then
                    for _, id in ipairs(LFGListFrame.SearchPanel.filteredIDs) do
                        for j = #results, 1, -1 do
                            if (results[j] == id) then
                                tremove(results, j)
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    local SortSearchResultsCB = function(searchResultID1, searchResultID2)
        --If one has more friends, do that one first

        local searchResultInfo1 = C_LFGList.GetSearchResultInfo(searchResultID1)
        local searchResultInfo2 = C_LFGList.GetSearchResultInfo(searchResultID2)

        local hasRemainingRole1 = HasRemainingSlotsForLocalPlayerRole(searchResultID1)
        local hasRemainingRole2 = HasRemainingSlotsForLocalPlayerRole(searchResultID2)

        if (searchResultInfo1.numBNetFriends ~= searchResultInfo2.numBNetFriends) then
            return searchResultInfo1.numBNetFriends > searchResultInfo2.numBNetFriends
        end

        if (searchResultInfo1.numCharFriends ~= searchResultInfo2.numCharFriends) then
            return searchResultInfo1.numCharFriends > searchResultInfo2.numCharFriends
        end

        if (searchResultInfo1.numGuildMates ~= searchResultInfo2.numGuildMates) then
            return searchResultInfo1.numGuildMates > searchResultInfo2.numGuildMates
        end

        if (hasRemainingRole1 ~= hasRemainingRole2) then
            return hasRemainingRole1
        end

        if db.showLeaderScore then
            return (searchResultInfo1.leaderOverallDungeonScore or 0) > (searchResultInfo2.leaderOverallDungeonScore or 0)
        end
            --If we aren't sorting by anything else, just go by ID
        return searchResultID1 < searchResultID2
    end

    if (#results > 0) then
        for _, id in ipairs(results) do
            FilterSearchResults(id)
        end

        if (LFGListFrame.SearchPanel.filteredIDs) then
            filterTable(LFGListFrame.SearchPanel.results, LFGListFrame.SearchPanel.filteredIDs)
            LFGListFrame.SearchPanel.filteredIDs = nil
        end
    end

    table.sort(results, SortSearchResultsCB)

    if #results > 0 then
        LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel)
    end

    local shown = LFGListFrame.activePanel.results and #LFGListFrame.activePanel.results or 0
    local total = LFGListFrame.activePanel.totalResults and LFGListFrame.activePanel.totalResults or 0
    LFMPlusFrame_resultsText:SetText(L["Showing "] ..  shown .. L[" of "] .. total)
end

local SortApplicants = function(applicants)

    if not LFGListFrame.CategorySelection.selectedCategory == 2 then
        return
    end

    local function FilterApplicants(applicantID)
        local applicantInfo = C_LFGList.GetApplicantInfo(applicantID)

        if (applicantInfo == nil) then
            return
        end

        if (db.ratingFilter or db.classFilter) then

            local friendFound = false
            local neededClassFound = false
            local requiredScoreFound = false

            for i=1, applicantInfo.numMembers do
                local name, className, _, _, _, _, _, _, _, _, relationship, dungeonScore  = C_LFGList.GetApplicantMemberInfo(applicantID, i)
                relationship = relationship or false
                friendFound = friendFound or relationship
                neededClassFound = neededClassFound or LFMPlusFrame.classList[className].checked
                requiredScoreFound = requiredScoreFound or (dungeonScore > db.ratingFilterMin)
            end

            if ( (db.ratingFilter and (requiredScoreFound == false)) or (db.classFilter and (neededClassFound == false)) ) then
                addFilteredId(LFGListFrame.ApplicationViewer, applicantID)
            end
        end
    end

    local function SortApplicantsCB(applicantID1, applicantID2)
        local applicantInfo1 = C_LFGList.GetApplicantInfo(applicantID1)
        local applicantInfo2 = C_LFGList.GetApplicantInfo(applicantID2)

        if (applicantInfo1 == nil) then
            return false
        end

        if (applicantInfo2 == nil) then
            return true
        end

        local _, _, _, _, _, _, _, _, _, _, _, dungeonScore1 = C_LFGList.GetApplicantMemberInfo(applicantInfo1.applicantID, 1)
        local _, _, _, _, _, _, _, _, _, _, _, dungeonScore2 = C_LFGList.GetApplicantMemberInfo(applicantInfo2.applicantID, 1)

        return dungeonScore1 > dungeonScore2
    end

    if (#applicants > 0) then
        for _, v in ipairs(applicants) do
            FilterApplicants(v)
        end

        LFMPlusFrame.totalResults = #applicants

        if (LFGListFrame.ApplicationViewer.filteredIDs) then
            filterTable(applicants, LFGListFrame.ApplicationViewer.filteredIDs)
            LFGListFrame.ApplicationViewer.filteredIDs = nil
        end
    end

    table.sort(applicants, SortApplicantsCB)

    LFMPlusFrame.RefreshDeclineButton()

    if (#applicants > 0) then
        LFMPlusFrame.totalResults = #applicants
        LFGListApplicationViewer_UpdateResults(LFGListFrame.ApplicationViewer)
    end
end

local UpdateApplicantMember = function(member, appID, memberIdx, status, pendingStatus, ...)
    local activeEntryInfo = C_LFGList.GetActiveEntryInfo();
    local grayedOut = not pendingStatus and (status == "failed" or status == "cancelled" or status == "declined" or status == "declined_full" or status == "declined_delisted" or status == "invitedeclined" or status == "timedout" or status == "inviteaccepted" or status == "invitedeclined");
    if ( not activeEntryInfo ) then
        return;
    end
    if (not LFGListFrame.CategorySelection.selectedCategory == 2) then
        return
    end

    local textName = member.Name:GetText()
    local _, className, _, _, _, _, _, _, _, _, relationship, dungeonScore  = C_LFGList.GetApplicantMemberInfo(appID, memberIdx)

    local bestDungeonScoreForEntry = C_LFGList.GetApplicantDungeonScoreForListing(appID, memberIdx, activeEntryInfo.activityID);
    local scoreText = formatMPlusRating(dungeonScore)

    local bestRunString = bestDungeonScoreForEntry and ("|" .. (bestDungeonScoreForEntry.finishedSuccess and "cFF00FF00" or "cFFFF0000" ).. bestDungeonScoreForEntry.bestRunLevel .. "|r") or ""
    member.DungeonScore:SetText(" " .. scoreText .. " - " .. bestRunString)
    -- LFGListApplicationViewerScrollFrameButton1.Member1.DungeonScore

    local nameLength = 100
    if (relationship) then
        nameLength = nameLength - 22
    end

    if (member.Name:GetWidth() > nameLength) then
        member.Name:SetWidth(nameLength)
    end
end
LFMPlusFrame.nextAppDecline = 0

LFMPlusFrame.GetDeclineList = function()
    local returnText = ""
    if LFMPlusFrame.nextAppDecline and LFMPlusFrame.nextAppDecline > 0 then
        for i=1,#LFMPlusFrame.filteredIDs do
            local a = C_LFGList.GetApplicantInfo(LFMPlusFrame.filteredIDs[i])
            if a and a.applicantID and i <= 15 then
                local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore = C_LFGList.GetApplicantMemberInfo(a.applicantID, 1)
                local serverName = (name and name:find("-") ~= nil) and string.sub(name, name:find("-") + 1, string.len(name)) or ""
                local nameClean = RAID_CLASS_COLORS[class]:WrapTextInColorCode((name and name:find("-") ~= nil) and string.sub(name, 0, name:find("-") - 1) or name)
                local formatScore = formatMPlusRating(dungeonScore)
                local roles = (a.numMembers > 1 and CreateAtlasMarkup("newplayerchat-chaticon-guide") or "") .. (tank and CreateAtlasMarkup("roleicon-tiny-tank") or "") .. (healer and CreateAtlasMarkup("roleicon-tiny-healer") or "") .. (damage and CreateAtlasMarkup("roleicon-tiny-dps") or "")
                returnText = returnText .. (i == 1 and "|cFFFF0000>|r " or "") .. nameClean .. " " .. serverName .. " " .. formatScore .. " " .. roles

                if a.numMembers > 1 then
                    returnText = returnText .. "+(" .. tostring(a.numMembers - 1) .. ")" .. (i == 1 and " |cFFFF0000<|r " or "") .. "\n"
                    for j=2,a.numMembers do
                        local n, cn, _, _, _, _, t, h, d, _, _, ds = C_LFGList.GetApplicantMemberInfo(a.applicantID, j)
                        local sn = (n and n:find("-") ~= nil) and string.sub(n, n:find("-") + 1, string.len(n)) or ""
                        local nc = RAID_CLASS_COLORS[cn]:WrapTextInColorCode((n and n:find("-") ~= nil) and string.sub(n, 0, n:find("-") - 1) or n)
                        local fs = formatMPlusRating(ds)
                        local r = (t and CreateAtlasMarkup("roleicon-tiny-tank") or "") .. (h and CreateAtlasMarkup("roleicon-tiny-healer") or "") .. (d and CreateAtlasMarkup("roleicon-tiny-dps") or "")
                        returnText = returnText .. "      " .. nc .. " " .. " " .. sn .. " " .. fs .. " " .. r .. "\n"
                    end
                else
                    returnText = returnText .. (i == 1 and " |cFFFF0000<|r " or "") .. "\n"
                end
            end
        end
        if LFMPlusFrame.filteredIDs and #LFMPlusFrame.filteredIDs - 15 > 0 then
            returnText = returnText .. "\n" .. "+" .. tostring(#LFMPlusFrame.filteredIDs - 15) .. " more applicants."
        end
    end
    if returnText:len() == 0 then
        returnText = "No Applicants Filtered"
    end
    return returnText
end

LFMPlusFrame.RefreshDeclineButton = function()
    local resultString = "0"
    if (db.ratingFilter or db.classFilter) and (LFMPlusFrame.filteredIDs and #LFMPlusFrame.filteredIDs > 0) then
        local id = LFMPlusFrame.filteredIDs[1]
        local scriptText = "/script tremove(LFMPlusFrame.filteredIDs,1);"
        local a=C_LFGList.GetApplicantInfo(id);

        if a then
            LFMPlusFrame.nextAppDecline = a.applicantID
            if (a.applicationStatus~='applied' and a.applicationStatus~='invited') then 
                scriptText = scriptText .. "C_LFGList.RemoveApplicant("..tostring(LFMPlusFrame.nextAppDecline)..")"
            else
                scriptText = scriptText .. "C_LFGList.DeclineApplicant("..tostring(LFMPlusFrame.nextAppDecline)..")"
            end;
            LFMPlusFrame.declineButton:SetAttribute("macrotext1", scriptText .. "; LFGListApplicationViewer_UpdateResults(LFGListFrame.ApplicationViewer);")

            LFMPlusFrame.declineButton:Enable()
        else
            LFMPlusFrame.nextAppDecline = nil
            LFMPlusFrame.filteredIDs = {}
            LFMPlusFrame.declineButton:SetAttribute("macrotext1", "/script LFGListFrame.ApplicationViewer.RefreshButton:Click()")
        end
        local remaining = #LFMPlusFrame.filteredIDs
        resultString = "|cFF00FF00" .. tostring(remaining).."/"..tostring(LFMPlusFrame.totalResults) .. "|r"
    else
        LFMPlusFrame.nextAppDecline = nil
        LFMPlusFrame.filteredIDs = {}
        LFGListFrame.ApplicationViewer.filteredIDs = nil
        LFMPlusFrame.declineButton:SetAttribute("macrotext1", "/script LFGListFrame.ApplicationViewer.RefreshButton:Click()")
    end
    if GameTooltip:IsShown() and (GameTooltip:GetOwner():GetName() == "LFMPlusFrame_declineButton") then
       GameTooltip:SetText(LFMPlusFrame.GetDeclineList(), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, true);
       GameTooltip:Show()
    end
    LFMPlusFrame.declineButton:SetText(resultString)
end
function LFMPlus:AddToFilter(name,realm)
    if not db.flagPlayerList[name.."-"..realm] then
        db.flagPlayerList[name.."-"..realm] = true
    end
end

local SearchEntryUpdate = function(entry)

    if (LFGListFrame.CategorySelection.selectedCategory ~= 2) or not db.enabled then
        return
    end

    local resultID = entry.resultID
    local resultInfo = C_LFGList.GetSearchResultInfo(resultID)
    for i = 1, 5 do
        local texture = "tex" .. i
        if (entry.DataDisplay.Enumerate[texture]) then
            entry.DataDisplay.Enumerate[texture]:Hide()
        end
    end

    if db.showClassColors then
        local numMembers = resultInfo.numMembers
        local orderIndexes = {}

        for i = 1, numMembers do
            local role, class = C_LFGList.GetSearchResultMemberInfo(resultID, i)
            local orderIndex = getIndex(LFG_LIST_GROUP_DATA_ROLE_ORDER, role)
            table.insert(orderIndexes, {orderIndex, class})
        end

        table.sort(orderIndexes,function(a, b)return a[1] < b[1]end)
        local xOffset = -76

        for i = 1, numMembers do
            local class = orderIndexes[i][2]
            local classColor = RAID_CLASS_COLORS[class]
            local r, g, b, _ = classColor:GetRGBA()
            local texture = "tex" .. i

            if (not entry.DataDisplay.Enumerate[texture]) then
                entry.DataDisplay.Enumerate[texture] = entry.DataDisplay.Enumerate:CreateTexture(nil, "ARTWORK")
                entry.DataDisplay.Enumerate[texture]:SetSize(10, 3)
                entry.DataDisplay.Enumerate[texture]:SetPoint("RIGHT",entry.DataDisplay.Enumerate,"RIGHT",xOffset,-10)
            end

            entry.DataDisplay.Enumerate[texture]:Show()
            entry.DataDisplay.Enumerate[texture]:SetColorTexture(r, g, b, 1)

            xOffset = xOffset + 15
        end
        for i = 2, 5 do
            entry.DataDisplay.Enumerate["Icon" .. i]:SetPoint("CENTER",entry.DataDisplay.Enumerate["Icon" .. i - 1],"CENTER",-15,0)
        end
    end
    if db.alwaysShowRoles then
        entry.DataDisplay:ClearAllPoints()
        entry.DataDisplay:SetPoint("BOTTOMRIGHT", entry.CancelButton, "BOTTOMLEFT", 5, -5)
        entry.ExpirationTime:ClearAllPoints()
        entry.ExpirationTime:SetPoint("BOTTOMRIGHT", entry.CancelButton, "TOPLEFT", 0, -8)
        entry.PendingLabel:ClearAllPoints()
        entry.PendingLabel:SetPoint("RIGHT", entry.ExpirationTime, "LEFT", -5, 0)

        if not entry.DataDisplay:IsShown() then
            entry.DataDisplay:Show()
        end
    end
    if db.showLeaderScore and not resultInfo.isDelisted and LFMPlusFrame.dungeonList[resultInfo.activityID] then
        local formattedLeaderScore = formatMPlusRating(resultInfo.leaderOverallDungeonScore or 0)
        entry.Name:SetText(formattedLeaderScore .. " " .. entry.Name:GetText())
        entry.ActivityName:SetWordWrap(false)
    end

    if db.shortenActivityName and ns.ACTIVITY_INFO[resultInfo.activityID] then
        entry.ActivityName:SetText(ns.ACTIVITY_INFO[resultInfo.activityID].shortName .. " (M+)")
        entry.ActivityName:SetWordWrap(false)
    end

    if db.showRealmName and LFMPlusFrame.dungeonList[resultInfo.activityID] then
        local leaderName = resultInfo.leaderName
        if (leaderName) then
            local realmName = leaderName:find("-") ~= nil and string.sub(leaderName, leaderName:find("-") + 1, string.len(leaderName))
            if realmName then
                if (db.flagRealm and LFMPlus:checkRealm(realmName)) or (db.flagPlayer and LFMPlus:checkPlayer(leaderName)) then
                    realmName = RED_FONT_COLOR:WrapTextInColorCode(realmName)
                else
                    realmName = NORMAL_FONT_COLOR:WrapTextInColorCode(realmName)
                end
            else
                realmName = BATTLENET_FONT_COLOR:WrapTextInColorCode(GetRealmName())
            end
            if realmName then
                entry.ActivityName:SetText(entry.ActivityName:GetText() .. " " .. realmName)
                entry.ActivityName:SetWordWrap(false)

            end
        end
    end
end

function LFMPlus:FilterChanged()
    if ns.Init and LFGListFrame and LFGListFrame.activePanel and LFGListFrame.activePanel.RefreshButton and LFGListFrame.activePanel.RefreshButton:IsShown() then
        LFGListFrame.activePanel.RefreshButton:Click()
    end
end

function LFMPlus:GetNameRealm(unit, tempRealm)
    local name, realm = nil, tempRealm
    if unit then
        if UnitExists(unit) then
            name = GetUnitName(unit, true)
            if not tempRealm then
                realm = name:find("-") ~= nil and string.sub(name, name:find("-") + 1, string.len(name)) or GetRealmName()
            end
        else
            name = unit:find("-") ~= nil and string.sub(unit, 1, unit:find("-") - 1) or unit
            if not tempRealm then
                realm = unit:find("-") ~= nil and string.sub(unit, unit:find("-") + 1, string.len(unit)) or GetRealmName()
            end
        end
    end
    return name, realm
end

do
    -- Inspired by the RaiderIO addon.
    local LibDropDownExtension = LibStub and LibStub:GetLibrary("LibDropDownExtension-1.0", true)
    local dropdown = {
        enabled = false
    }

    function dropdown:IsEnabled ()
        return self.enabled
    end

    function dropdown:SetEnabled(state)
        self.enabled = state
    end
    function dropdown:OnEnable()
    end
    function dropdown:Enable()
        if self:IsEnabled() then
            return false
        end
        self:SetEnabled(true)
        self:OnEnable()
        return true
    end

    local function GetNameRealmForDropDown(bdropdown)
        local unit = bdropdown.unit
        local menuList = bdropdown.menuList
        local clubMemberInfo = bdropdown.clubMemberInfo
        local tempName, tempRealm = bdropdown.name, bdropdown.server
        local name, realm, level

        -- unit
        if not name and UnitExists(unit) then
            if UnitIsPlayer(unit) then
                name, realm = LFMPlus:GetNameRealm(unit)
                level = UnitLevel(unit)
            end
            -- if it's not a player it's pointless to check further
            return name, realm, level
        end

        -- lfd
        if not name and menuList then
            for i = 1, #menuList do
                local whisperButton = menuList[i]
                if whisperButton and (whisperButton.text == WHISPER_LEADER or whisperButton.text == WHISPER) then
                    name, realm = LFMPlus:GetNameRealm(whisperButton.arg1)
                    break
                end
            end
        end

        -- dropdown by name and realm
        if not name and tempName then
            name, realm = LFMPlus:GetNameRealm(tempName, tempRealm)
            if clubMemberInfo and clubMemberInfo.level and (clubMemberInfo.clubType == Enum.ClubType.Guild or clubMemberInfo.clubType == Enum.ClubType.Character) then
                level = clubMemberInfo.level
            end
        end

        -- if we don't got both we return nothing
        if not name or not realm then
            return
        end
        return name, realm, level
    end
    local validTypes = {
        ARENAENEMY = true,
        BN_FRIEND = false,
        CHAT_ROSTER = true,
        COMMUNITIES_GUILD_MEMBER = false,
        COMMUNITIES_WOW_MEMBER = false,
        FOCUS = true,
        FRIEND = true,
        GUILD = true,
        GUILD_OFFLINE = true,
        PARTY = true,
        PLAYER = true,
        RAID = true,
        RAID_PLAYER = true,
        SELF = true,
        TARGET = true,
        WORLD_STATE_SCORE = true
    }

    local function IsValidDropDown(bdropdown)
        return (bdropdown == LFGListFrameDropDown and db.enableLFGDropdown) or (type(bdropdown.which) == "string" and validTypes[bdropdown.which])
    end

    local selectedName, selectedRealm, selectedLevel
    local unitOptions

    local function OnToggle(bdropdown, event, opt)
        if event == "OnShow" then
            if not IsValidDropDown(bdropdown) then
                return
            end
            selectedName, selectedRealm, _ = GetNameRealmForDropDown(bdropdown)
            if not opt[1] then
                for i = 1, #unitOptions do
                    opt[i] = unitOptions[i]
                end
                return true
            end
        elseif event == "OnHide" then
            if opt[1] then
                for i = #opt, 1, -1 do
                    opt[i] = nil
                end
                return true
            end
        end
    end
    dropdown:Enable()
    unitOptions = {
        {
            text = L["LFMPlus"] .. ": " .. L["Filter"],
            func = function()
                LFMPlus:AddToFilter(selectedName,selectedRealm)
            end
        },
    }
    LibDropDownExtension:RegisterEvent("OnShow OnHide", OnToggle, 1, dropdown)
end

function LFMPlus:RefreshResults()
    if LFGListFrame.activePanel:IsShown() and LFGListFrame.activePanel.RefreshButton then
        if LFGListFrame.CategorySelection.selectedCategory == 2 and LFGListFrame.SearchPanel:IsShown() then
            LFGListSearchPanel_UpdateResultList(LFGListFrame.activePanel);
        end
        LFGListFrame.activePanel.RefreshButton:Click()
    end
end

local function InitializeUI()
    -- Create the frame for toggling the active role filter.
    LFMPlusFrame:SetFrameLevel(0)
    do
        local f = CreateFrame("Frame", nil, LFMPlusFrame)

        function f:UpdateRoleIcon()
            if CanInspect("player", false) then
                NotifyInspect("player")
                LFMPlus:RegisterEvent("INSPECT_READY", function(_, guid)
                    if UnitGUID("player") == guid then
                        LFMPlus:UnregisterEvent("INSPECT_READY")
                        local role = GetSpecializationRoleByID(GetInspectSpecialization("player"))
                        local roleAtlas = ns.CONSTANTS.atlas[role] or ns.CONSTANTS.atlas.NA
                        self.roleIcon:SetText(CreateAtlasMarkup(roleAtlas, 25, 25))
                    end
                end)
            end
        end

        function f:ToggleGlow()
            if db.activeRoleFilter then
                LFMPlusFrame.activeRoleFrame.roleIconGlow:Show()
            else
                LFMPlusFrame.activeRoleFrame.roleIconGlow:Hide()
            end
        end

        f:SetFrameLevel(1)
        f:SetSize(25,25)
        f:SetPoint("LEFT",LFMPlusFrame,"LEFT",10,0)
        f.roleIcon = f:CreateFontString(nil,"ARTWORK", "GameFontNormal")
        f.roleIcon:SetText(L["Role"])
        f.roleIcon:SetSize(30,30)
        f.roleIcon:SetPoint("CENTER",f,"CENTER")

        f.roleIconGlow = f:CreateFontString(nil,"BORDER", "GameFontNormal")
        f.roleIconGlow:SetText(CreateAtlasMarkup("groupfinder-eye-highlight", 40, 40))
        f.roleIconGlow:SetSize(45,45)
        f.roleIconGlow:SetPoint("CENTER",f.roleIcon,"CENTER")

        f.tooltipText = L["ActiveRoleTooltip"]
        f:SetScript("OnEnter", showTooltip)
        f:SetScript("OnLeave", hideTooltip)
        f:SetScript("OnMouseDown",function(self, button)
            if button == "LeftButton" then
                db.activeRoleFilter = not db.activeRoleFilter
                f.ToggleGlow()
                LFMPlus:RefreshResults()
            end
        end)

        LFMPlusFrame.activeRoleFrame = f
        LFMPlusFrame.frames.search["activeRoleFrame"] = true

        f:UpdateRoleIcon()
        f:ToggleGlow()
        f:Hide()
    end

    --Create the dropdown menu used for dungeon filtering.
    do
        local f = AceGUI:Create("Dropdown")
        f.frame:SetFrameStrata("HIGH")
        f:SetMultiselect(true)
        f:SetWidth(50)
        f:SetPulloutWidth(160)

        function f:Show()
            self.frame:Show()
        end

        function f:Hide()
            self.frame:Hide()
        end

        function f:ToggleVisibility(toggle)
            if toggle ~= nil then
                self.frame:SetShown(toggle)
            else
                if self:IsVisible() then
                    self.frame:Hide()
                else
                    self.frame:Show()
                end
            end
        end

        function f:SetText()
            local text = ""
            local count = self:GetUserData("selectedCount")
            if count > 0 then
                text = "|cFF00FF00" .. count .. "|r"
            else
                text = count
            end
            self.text:SetText(text)
        end

        local function btnClick(s,button)
            if button == "RightButton" then
                f:ClearFocus()
                for k,v in pairs(LFMPlusFrame.dungeonList) do
                    if v.checked then
                        v.checked = false
                        f:SetItemValue(k,false)
                        local selectedCount = f:GetUserData("selectedCount") - 1
                        f:SetUserData("selectedCount",selectedCount)
                    end
                end
                f:SetText()
                LFMPlus:RefreshResults()
            end
        end


        f.button_cover:RegisterForClicks("LeftButtonDown","RightButtonDown");

        f.button_cover:HookScript("OnClick",btnClick)

        f:SetUserData("selectedCount",0)
        f:SetCallback("OnValueChanged",function(self,_,activityId,checked)
            LFMPlusFrame.dungeonList[activityId].checked = checked
            local selectedCount = self:GetUserData("selectedCount") + (checked and 1 or (self:GetUserData("selectedCount") == 0 and 0 or -1))
            self:SetUserData("selectedCount",selectedCount)
            self:SetText()
            db.dungeonFilter = self:GetUserData("selectedCount") > 0

            LFMPlus:RefreshResults()
        end)
        f:SetText()
        f:SetPoint("LEFT",LFMPlusFrame.activeRoleFrame,"RIGHT",20,0)
        f:Hide()

        LFMPlusFrame.dungeonDropdownFrame = f
        LFMPlusFrame.frames.search["dungeonDropdownFrame"] = true
    end

    --Create the dropdown menu used for class filtering.
    do
        local f = AceGUI:Create("Dropdown")

        f.frame:SetFrameStrata("HIGH")
        f:SetMultiselect(true)
        f:SetWidth(50)
        f:SetPulloutWidth(160)

        function f:Show()
            self.frame:Show()
        end

        function f:Hide()
            self.frame:Hide()
        end

        function f:ToggleVisibility(toggle)
            if toggle ~= nil then
                self.frame:SetShown(toggle)
            else
                if self:IsVisible() then
                    self.frame:Hide()
                else
                    self.frame:Show()
                end
            end
        end

        function f:SetText()
            local text = ""
            local count = self:GetUserData("selectedCount")
            if count > 0 then
                text = "|cFF00FF00" .. count .. "|r"
            else
                text = count
            end
            self.text:SetText(text)
        end

        local function btnClick(s,button)
            if button == "RightButton" then
                f:ClearFocus()
                for k,v in pairs(LFMPlusFrame.classList) do
                    if v.checked then
                        v.checked = false
                        f:SetItemValue(k,false)
                        local selectedCount = f:GetUserData("selectedCount") - 1
                        f:SetUserData("selectedCount",selectedCount)
                    end
                end
                f:SetText()
                LFMPlus:RefreshResults()
            end
        end

        f.button_cover:RegisterForClicks("LeftButtonDown","RightButtonDown");

        f.button_cover:HookScript("OnClick",btnClick)

        f:SetUserData("selectedCount",0)
        f:SetCallback("OnValueChanged",function(self,_,classId,checked)
            LFMPlusFrame.classList[classId].checked = checked

            local selectedCount = self:GetUserData("selectedCount") + (checked and 1 or (self:GetUserData("selectedCount") == 0 and 0 or -1))
            self:SetUserData("selectedCount",selectedCount)
            self:SetText()

            db.classFilter = selectedCount > 0

            LFMPlus:RefreshResults()
        end)

        f:SetText()
        f:SetPoint("LEFT",LFMPlusFrame.activeRoleFrame,"RIGHT",20,0)
        f:Hide()

        LFMPlusFrame.classDropdownFrame = f
        LFMPlusFrame.frames.app["classDropdownFrame"] = true
    end

    --Create Application Decline Button
    do
        local f = CreateFrame("Button", "LFMPlusFrame_declineButton", LFMPlusFrame, "SecureActionButtonTemplate")
        f:SetFrameLevel(1)
        f:SetFrameStrata("HIGH")
        f:SetPoint("RIGHT", LFGListFrame.SearchPanel.RerfreshButton, "LEFT", 0, 0)
        f:SetAttribute("type1", "macro")
        f:SetAttribute("macrotext1", "/script 1 == 1")
        f:SetWidth(LFGListFrame.ApplicationViewer.RefreshButton:GetWidth() + 25)
        f:SetHeight(LFGListFrame.ApplicationViewer.RefreshButton:GetWidth() + 10)
        f:SetText("0/0")
        f:SetNormalFontObject("GameFontNormalSmall")
        f:SetNormalTexture("Interface/Buttons/UI-SquareButton-Up")
        f:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight")
        f:SetPushedTexture("Interface/Buttons/UI-SquareButton-Down")
        f:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT");
            GameTooltip:SetText(LFMPlusFrame.GetDeclineList(), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, true);
            GameTooltip:Show();
        end)
        f:SetScript("OnLeave", GameTooltip_Hide)

        LFMPlusFrame.declineButton = f
        LFMPlusFrame.frames.app["declineButton"] = true
    end
end

function LFMPlus:OnInitialize()
    db = LibStub("AceDB-3.0"):New(ns.friendlyName .. "DB", defaults, true).global
    LFMPlusFrame.dungeonListLoaded = false
    LFMPlusFrame.classListLoaded = false

    -- Register options table and slash command
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(addonName, options, true)
    self:RegisterChatCommand("lfm", function()
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    end)

    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonName)
    InitializeUI()

    LFMPlusFrame_results:ClearAllPoints()
    LFMPlusFrame_results:SetWidth(100)
    LFMPlusFrame_results:SetHeight(20)
    LFMPlusFrame_results:SetPoint("BOTTOM",LFGListFrame.SearchPanel.SearchBox,"TOP",0,5)

    LFMPlusFrame_resultsText = LFMPlusFrame_results:CreateFontString("LFMPlusFrame_resultsText", "ARTWORK", "GameFontNormal")
    LFMPlusFrame_resultsText:ClearAllPoints()
    LFMPlusFrame_resultsText:SetWidth(100)
    LFMPlusFrame_resultsText:SetHeight(20)
    LFMPlusFrame_resultsText:SetPoint("TOP",LFMPlusFrame_results,"TOP")
    LFMPlusFrame_resultsText:SetText(L["Showing "] ..  0 .. L[" of "] .. 0)

    LFMPlusFrame_ScoreMin.Value = LFMPlusFrame_ScoreMin.Text
    LFMPlusFrame_ScoreMin.Value:ClearAllPoints()
    LFMPlusFrame_ScoreMin.Value:SetPoint("TOP", LFMPlusFrame_ScoreMin, "BOTTOM", 0, 3)

    LFMPlusFrame_ScoreMin:SetMinMaxValues(ns.CONSTANTS.ratingMin, ns.CONSTANTS.ratingMax);
    LFMPlusFrame_ScoreMin:SetDisplayValue(db.ratingFilterMin)
    LFMPlusFrame_ScoreMin.Low:SetText(formatMPlusRating(ns.CONSTANTS.ratingMin))
    LFMPlusFrame_ScoreMin.High:SetText(formatMPlusRating(ns.CONSTANTS.ratingMax))

    LFMPlusFrame:Hide()

    if db.enabled then
        LFMPlus:Enable()
    end

    for k,v in pairs(LFMPlusFrame.frames.search) do
        LFMPlusFrame.frames.all[k] = v
    end

    for k,v in pairs(LFMPlusFrame.frames.app) do
        LFMPlusFrame.frames.all[k] = v
    end
end

function LFMPlus:ToggleFrames(frame,action)
    if db.enabled and action == "show" then

        self.visibility = frame

        if not LFMPlusFrame.dungeonListLoaded then
            LFMPlusFrame.dungeonList = {}
            self:GetDungeonList()
        end

        if not LFMPlusFrame.classListLoaded then
            LFMPlusFrame.classList = {}
            self:GetClassList()
        end

        LFMPlusFrame:Show()
        LFMPlusFrame.activeRoleFrame:UpdateRoleIcon()

        for k,_ in pairs(LFMPlusFrame.frames[frame]) do
            LFMPlusFrame[k]:Show();
        end

        self:FilterChanged()
    end

    if action == "hide" then
        LFMPlusFrame:Hide()
        for k,_ in pairs(LFMPlusFrame.frames.all) do
            LFMPlusFrame[k]:Hide();
        end
    end
end

function LFMPlus:Enable()
    if not ns.HooksRan then
        hooksecurefunc("LFGListUtil_SortSearchResults", SortSearchResults)
        hooksecurefunc("LFGListSearchEntry_Update", SearchEntryUpdate)
        hooksecurefunc("LFGListUtil_SortApplicants", SortApplicants)
        hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", UpdateApplicantMember)

        LFGListFrame.ApplicationViewer.RemoveEntryButton:HookScript("OnClick", function(s)
            LFMPlusFrame.declineButton:Hide()
        end)

        LFGListFrame.CategorySelection.FindGroupButton:HookScript("OnClick", function(s)
            LFMPlusFrame.declineButton:Hide()
        end)

        LFGListFrame.EntryCreation.ListGroupButton:HookScript("OnClick", function(s)
            LFMPlusFrame.declineButton:ClearAllPoints()
            LFMPlusFrame.declineButton:SetWidth(LFGListFrame.ApplicationViewer.RefreshButton:GetWidth() + 25)
            LFMPlusFrame.declineButton:SetHeight(LFGListFrame.ApplicationViewer.RefreshButton:GetWidth() + 10)
            LFMPlusFrame.declineButton:SetPoint("RIGHT",LFGListFrame.ApplicationViewer.RefreshButton, "LEFT", 0, 0)
            LFMPlusFrame.declineButton:Show()
        end)

        LFGListFrame.SearchPanel:HookScript("OnShow",function(s)
            local selectedCategory = LFGListFrame.CategorySelection.selectedCategory
            if selectedCategory == 2 then
                LFMPlus:ToggleFrames("search","show")
            end
        end)

        LFGListFrame.ApplicationViewer:HookScript("OnShow",function(s)
            local selectedCategory = LFGListFrame.CategorySelection.selectedCategory
            if selectedCategory == 2 then
                LFMPlus:ToggleFrames("app","show")
            end
        end)

        LFGListFrame.SearchPanel:HookScript("OnHide",function(s)
            LFMPlus:ToggleFrames("search","hide")
        end)

        LFGListFrame.ApplicationViewer:HookScript("OnHide",function(s)
            LFMPlus:ToggleFrames("app","hide")
        end)

        for i=1,#LFGListSearchPanelScrollFrame.buttons do
            LFGListSearchPanelScrollFrame.buttons[i]:HookScript("OnDoubleClick", function()
                if db.lfgListingDoubleClick then
                    LFGListFrame.SearchPanel.SignUpButton:Click()
                end
            end)
        end
        LFGListApplicationDialogDescription.EditBox:HookScript("OnShow",function()
            if db.autoFocusSignUp then
                LFGListApplicationDialogDescription.EditBox:SetFocus()
            end
        end)

        LFGListApplicationDialogDescription.EditBox:HookScript("OnEnterPressed",function()
            if db.signupOnEnter then
                LFGListApplicationDialog.SignUpButton:Click()
            end
        end)

        LFGListFrame.ApplicationViewer.UnempoweredCover:HookScript("OnShow",function()
            if db.hideAppViewerOverlay then
                LFGListFrame.ApplicationViewer.UnempoweredCover:Hide()
            end
        end)
        ns.HooksRan = true
    end
    ns.Init = true
    LFMPlus:RefreshResults()
end

function LFMPlus:Disable()

end