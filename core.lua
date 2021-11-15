---@type string
local addonName, ---@type ns
  ns = ...

local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local LFMPlus = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

---@class LFMPlusFrame:Frame
---@field Layout function Layout child in the frame.
local LFMPlusFrame = CreateFrame("Frame", "LFMPlusFrame", GroupFinderFrame, "ManagedHorizontalLayoutFrameTemplate")

LFMPlusFrame:RegisterEvent("ADDON_LOADED")

local L = LibStub("AceLocale-3.0"):GetLocale(addonName, false)

---@class defaults
local defaults = {
  global = {
    -- Control Panel Defaults
    enabled = true,
    showLeaderScore = true,
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
    -- UI Defaults
    ratingFilter = false,
    ratingFilterMin = 0,
    ratingFilterMax = 0,
    dungeonFilter = false,
    realmList = {},
    classRoleDisplay = "def",
    showPartyLeader = false,
    dungeonAbbr = {
      [691] = "PF",
      [695] = "DOS",
      [699] = "HOA",
      [703] = "MOTS",
      [705] = "SD",
      [709] = "SOA",
      [713] = "NW",
      [717] = "TOP"
    }
  }
}

---@type defaults.global
local db

ns.Init = false

LFMPlus.mPlusListed = false
LFMPlus.mPlusSearch = false
LFMPlus.isLeader = false
LFMPlus.eligibleApplicantList = {}
LFMPlus.newEligibleApplicant = false

function LFMPlus:formatMPlusRating(score)
  if not score or type(score) ~= "number" then
    score = 0
  end

  -- If the score is 1000 or larger, divide by 1000 to get a decimal, get the first 3 characters to prevent rounding and then add a K. Ex: 2563 = 2.5k
  -- If the score is less than 1000, we simply store it in the shortScore variable.

  local shortScore = score >= 1000 and string.format("%3.2f", score / 1000):sub(1, 3) .. "k" or score
  shortScore = string.format(ns.constants.lengths.score, shortScore)
  local formattedScore = C_ChallengeMode.GetDungeonScoreRarityColor(score):WrapTextInColorCode(shortScore)
  return formattedScore
end

function LFMPlus:RemoveApplicantId(id)
  LFMPlusFrame.declineButtonInfo[id] = nil
  LFMPlus.eligibleApplicantList[id] = nil
  LFMPlusFrame.exemptIDs[id] = nil
  LFMPlus:removeFilteredId(id)
end

function LFMPlus:removeFilteredId(id)
  local idLoc = LFMPlusFrame:FindFilteredId(id)

  if idLoc then
    tremove(LFMPlusFrame.filteredIDs, idLoc)
    if idLoc <= ns.constants.declineQueueMax then
      LFMPlusFrame:ShiftDeclineSelection(false)
    end
  end
end

function LFMPlus:removeExemptId(id)
  LFMPlusFrame.exemptIDs[id] = nil
end

function LFMPlus:excludeFilteredId(id)
  LFMPlus:removeFilteredId(id)
  LFMPlusFrame.exemptIDs[id] = true
end

function LFMPlus:addFilteredId(s, id)
  if (not s.filteredIDs) then
    s.filteredIDs = {}
  end

  tinsert(s.filteredIDs, id)
end

function LFMPlus:filterTable(results, idsToFilter)
  LFMPlusFrame.filteredIDs = {}
  for _, id in ipairs(idsToFilter) do
    for j = #results, 1, -1 do
      if (results[j] == id) then
        tremove(results, j)
        tinsert(LFMPlusFrame.filteredIDs, id)
        table.sort(
          LFMPlusFrame.filteredIDs,
          function(a, b)
            return a < b
          end
        )
        if LFMPlus.mPlusListed then
          LFMPlusFrame:UpdateDeclineButtonInfo()
        end
      end
    end
  end
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

function LFMPlus:DeclineButtonTooltip()
  GameTooltip:ClearLines()
  GameTooltip:SetOwner(LFMPlusFrame.declineButton, "ANCHOR_BOTTOMLEFT")
  GameTooltip_SetTitle(GameTooltip, "LFM+ Decline Queue")
  GameTooltip:AddLine(CreateTextureMarkup(918860, 1, 1, 200, 5, 0, 1, 0, 1), 1, 1, 1, false)
  for i = 1, ns.constants.declineQueueMax do
    if LFMPlusFrame.filteredIDs[i] and LFMPlusFrame.declineButtonInfo[LFMPlusFrame.filteredIDs[i]] then
      for _, memberString in pairs(LFMPlusFrame.declineButtonInfo[LFMPlusFrame.filteredIDs[i]]) do
        GameTooltip:AddLine(memberString, nil, nil, nil, false)
      end
      GameTooltip:AddLine(CreateTextureMarkup(918860, 1, 1, 200, 5, 0, 1, 0, 1), 1, 1, 1, false)
    end
  end
  GameTooltip_AddInstructionLine(GameTooltip, "Click: Decline (Left), Allow (S-Left), Next (Right), Previous (S-Right)")
  GameTooltip:Show()
end

function LFMPlus:AddToFilter(name, realm)
  if not db.flagPlayerList[name .. "-" .. realm] then
    db.flagPlayerList[name .. "-" .. realm] = true
  end
end

function LFMPlus:FilterChanged()
  if ns.Init and LFGListFrame.activePanel.RefreshButton and LFGListFrame.activePanel.RefreshButton:IsShown() and LFGListFrame.activePanel.searching == false then
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

function LFMPlus:RefreshResults()
  if ns.Init then
    if LFGListFrame.activePanel.searching == false then
      LFGListFrame.activePanel.RefreshButton:Click()
    end
  end
end

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
      ["Thaurissan"] = true
    }
  }
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
    print(messagePrefix .. message)
  end
end

ns.InitHooksRan = false
ns.SecondHookRan = false
-- local LFMPlusFrame = LFMPlusFrame

local showTooltip = function(self)
  if (self.tooltipText ~= nil) then
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, self.tooltipText)
    GameTooltip:Show()
  end
end

local hideTooltip = function()
  if GameTooltip:IsShown() then
    GameTooltip:Hide()
  end
end

local function getIndex(values, val)
  local index = {}
  for k, v in pairs(values) do
    index[v] = k
  end
  return index[val]
end

ns.DEBUG_ENABLED = false

local L_LFGListUtil_SortSearchResults = function(results)
  if (not LFMPlus.mPlusSearch) and not (#results > 0) then
    return
  end

  local roleRemainingKeyLookup = {
    ["TANK"] = "TANK_REMAINING",
    ["HEALER"] = "HEALER_REMAINING",
    ["DAMAGER"] = "DAMAGER_REMAINING"
  }
  local resultStats = {}
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
    local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID, nil, searchResultInfo.isWarMode)
    resultStats[searchResultID] = searchResultInfo
    -- requiredPvPRating number
    -- requiredDungeonScore number
    -- playstyle number
    if searchResultInfo then
      -- Never filter listings with friends or guildies.
      local filterFriends = db.alwaysShowFriends and ((searchResultInfo.numBNetFriends or 0) + (searchResultInfo.numCharFriends or 0) + (searchResultInfo.numGuildMates or 0)) > 0 or false
      if (not filterFriends) then
        local leaderName, realmName = LFMPlus:GetNameRealm(searchResultInfo.leaderName)
        -- local realmName = leaderName:find("-") ~= nil and string.sub(leaderName, leaderName:find("-") + 1, string.len(leaderName)) or GetRealmName()
        local filterRole = db.activeRoleFilter and not RemainingSlotsForLocalPlayerRole(searchResultID) or false
        local filterRating = db.ratingFilter and not (searchResultInfo.leaderOverallDungeonScore and searchResultInfo.leaderOverallDungeonScore >= db.ratingFilterMin or false) or false
        local filterRealm = db.filterRealm and LFMPlus:checkRealm(realmName) or false
        local filterPlayer = db.filterPlayer and LFMPlus:checkPlayer(leaderName) or false
        local filterDungeon = (db.dungeonFilter and LFMPlusFrame.dungeonList[searchResultInfo.activityID]) and (not LFMPlusFrame.dungeonList[searchResultInfo.activityID].checked) or false
        -- Filter out the activity if it is not a mythic plus listing.
        local filterActivity = db.dungeonFilter and not activityInfo.isMythicPlusActivity or false
        local missingActivityId = ((not (filterRole or filterRating or filterRealm or filterDungeon or filterPlayer or filterActivity)) and (db.activeRoleFilter or db.ratingFilter)) and (not LFMPlusFrame.dungeonList[searchResultInfo.activityID]) or false
        if (filterRole or filterRating or filterRealm or filterDungeon or filterPlayer or filterActivity or missingActivityId) then
          --LFMPlus:addFilteredId(LFGListFrame.SearchPanel, searchResultID)
          return true
        end
      else
        return false
      end
    end
  end

  local SortSearchResultsCB = function(searchResultID1, searchResultID2)
    -- If one has more friends, do that one first
    if searchResultID1 == nil or resultStats[searchResultID1] == nil then
      return false
    end

    if searchResultID2 == nil or resultStats[searchResultID2] == nil then
      return true
    end
    local searchResultInfo1 = resultStats[searchResultID1]
    local searchResultInfo2 = resultStats[searchResultID2]

    local _, appStatus1, pendingStatus1, appDuration1 = C_LFGList.GetApplicationInfo(searchResultID1)
    local _, appStatus2, pendingStatus2, appDuration2 = C_LFGList.GetApplicationInfo(searchResultID2)

    local isApplication1 = (appStatus1 ~= "none" or pendingStatus1)
    local isApplication2 = (appStatus2 ~= "none" or pendingStatus2)

    local hasRemainingRole1 = HasRemainingSlotsForLocalPlayerRole(searchResultID1)
    local hasRemainingRole2 = HasRemainingSlotsForLocalPlayerRole(searchResultID2)

    if isApplication1 or isApplication2 then
      if isApplication1 and isApplication2 then
        if type(isApplication1) == "number" and type(isApplication2) == "number" then
          return isApplication1 < isApplication2
        else
          return appDuration1 < appDuration2
        end
      elseif isApplication2 then
        return false
      elseif isApplication1 then
        return true
      end
    end

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
    -- If we aren't sorting by anything else, just go by ID
    return searchResultID1 < searchResultID2
  end

  for j = #results, 1, -1 do
    local filterResult = FilterSearchResults(results[j])
    if filterResult then
      tremove(results, j)
    end
  end
  table.sort(results, SortSearchResultsCB)
end

local function L_LFGListUtil_SetSearchEntryTooltip(tooltip, resultID, autoAcceptOption)
  local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
  local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID, nil, searchResultInfo.isWarMode)

  local memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID)
  local nameStyle = searchResultInfo.name

  if (searchResultInfo.playstyle > 1) then
    local playstyleString = _G["GROUP_FINDER_PVE_PLAYSTYLE" .. searchResultInfo.playstyle]
    nameStyle = nameStyle .. " (" .. GREEN_FONT_COLOR:WrapTextInColorCode(playstyleString) .. ")"
  end

  tooltip:SetText(nameStyle, 1, 1, 1, true)

  tooltip:AddLine(activityInfo.fullName)
  if (searchResultInfo.comment and searchResultInfo.comment == "" and searchResultInfo.questID) then
    searchResultInfo.comment = LFGListUtil_GetQuestDescription(searchResultInfo.questID)
  end

  if (searchResultInfo.comment ~= "") then
    tooltip:AddLine(string.format(LFG_LIST_COMMENT_FORMAT, searchResultInfo.comment), LFG_LIST_COMMENT_FONT_COLOR.r, LFG_LIST_COMMENT_FONT_COLOR.g, LFG_LIST_COMMENT_FONT_COLOR.b, true)
  end

  tooltip:AddLine(" ")
  if (searchResultInfo.requiredDungeonScore > 0) then
    tooltip:AddLine(GROUP_FINDER_MYTHIC_RATING_REQ_TOOLTIP:format(searchResultInfo.requiredDungeonScore))
  end
  if (searchResultInfo.requiredPvpRating > 0) then
    tooltip:AddLine(GROUP_FINDER_PVP_RATING_REQ_TOOLTIP:format(searchResultInfo.requiredPvpRating))
  end
  if (searchResultInfo.requiredItemLevel > 0) then
    if (activityInfo.isPvpActivity) then
      tooltip:AddLine(LFG_LIST_TOOLTIP_ILVL_PVP:format(searchResultInfo.requiredItemLevel))
    else
      tooltip:AddLine(LFG_LIST_TOOLTIP_ILVL:format(searchResultInfo.requiredItemLevel))
    end
  end
  if (activityInfo.useHonorLevel and searchResultInfo.requiredHonorLevel > 0) then
    tooltip:AddLine(LFG_LIST_TOOLTIP_HONOR_LEVEL:format(searchResultInfo.requiredHonorLevel))
  end
  if (searchResultInfo.voiceChat ~= "") then
    tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_VOICE_CHAT, searchResultInfo.voiceChat), nil, nil, nil, true)
  end
  if (searchResultInfo.requiredItemLevel > 0 or (activityInfo.useHonorLevel and searchResultInfo.requiredHonorLevel > 0) or searchResultInfo.voiceChat ~= "" or searchResultInfo.requiredDungeonScore > 0 or searchResultInfo.requiredPvpRating > 0) then
    tooltip:AddLine(" ")
  end

  if (searchResultInfo.leaderName) then
    tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_LEADER, searchResultInfo.leaderName))
  end

  if (activityInfo.isRatedPvpActivity and searchResultInfo.leaderPvpRatingInfo) then
    GameTooltip_AddNormalLine(tooltip, PVP_RATING_GROUP_FINDER:format(searchResultInfo.leaderPvpRatingInfo.activityName, searchResultInfo.leaderPvpRatingInfo.rating, PVPUtil.GetTierName(searchResultInfo.leaderPvpRatingInfo.tier)))
  elseif (activityInfo.isMythicPlusActivity and searchResultInfo.leaderOverallDungeonScore) then
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(searchResultInfo.leaderOverallDungeonScore)
    if (not color) then
      color = HIGHLIGHT_FONT_COLOR
    end
    GameTooltip_AddNormalLine(tooltip, DUNGEON_SCORE_LEADER:format(color:WrapTextInColorCode(searchResultInfo.leaderOverallDungeonScore)))
  end

  if (activityInfo.isMythicPlusActivity and searchResultInfo.leaderDungeonScoreInfo) then
    local leaderDungeonScoreInfo = searchResultInfo.leaderDungeonScoreInfo
    local color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(leaderDungeonScoreInfo.mapScore)
    if (not color) then
      color = HIGHLIGHT_FONT_COLOR
    end
    if (leaderDungeonScoreInfo.mapScore == 0) then
      GameTooltip_AddNormalLine(tooltip, DUNGEON_SCORE_PER_DUNGEON_NO_RATING:format(leaderDungeonScoreInfo.mapName, leaderDungeonScoreInfo.mapScore))
    elseif (leaderDungeonScoreInfo.finishedSuccess) then
      GameTooltip_AddNormalLine(tooltip, DUNGEON_SCORE_DUNGEON_RATING:format(leaderDungeonScoreInfo.mapName, color:WrapTextInColorCode(leaderDungeonScoreInfo.mapScore), leaderDungeonScoreInfo.bestRunLevel))
    else
      GameTooltip_AddNormalLine(tooltip, DUNGEON_SCORE_DUNGEON_RATING_OVERTIME:format(leaderDungeonScoreInfo.mapName, color:WrapTextInColorCode(leaderDungeonScoreInfo.mapScore), leaderDungeonScoreInfo.bestRunLevel))
    end
  end
  if (searchResultInfo.age > 0) then
    tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_AGE, SecondsToTime(searchResultInfo.age, false, false, 1, false)))
  end

  if (searchResultInfo.leaderName or searchResultInfo.age > 0) then
    tooltip:AddLine(" ")
  end

  if (activityInfo.displayType == LE_LFG_LIST_DISPLAY_TYPE_CLASS_ENUMERATE) then
    tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_MEMBERS_SIMPLE, searchResultInfo.numMembers))
    for i = 1, searchResultInfo.numMembers do
      local role, class, classLocalized = C_LFGList.GetSearchResultMemberInfo(resultID, i)
      local classColor = RAID_CLASS_COLORS[class] or NORMAL_FONT_COLOR
      tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_CLASS_ROLE, classLocalized, _G[role]), classColor.r, classColor.g, classColor.b)
    end
  else
    tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_MEMBERS, searchResultInfo.numMembers, memberCounts.TANK, memberCounts.HEALER, memberCounts.DAMAGER))
  end

  if (searchResultInfo.numBNetFriends + searchResultInfo.numCharFriends + searchResultInfo.numGuildMates > 0) then
    tooltip:AddLine(" ")
    tooltip:AddLine(LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP)
    tooltip:AddLine(LFGListSearchEntryUtil_GetFriendList(resultID), 1, 1, 1, true)
  end

  local completedEncounters = C_LFGList.GetSearchResultEncounterInfo(resultID)
  if (completedEncounters and #completedEncounters > 0) then
    tooltip:AddLine(" ")
    tooltip:AddLine(LFG_LIST_BOSSES_DEFEATED)
    for i = 1, #completedEncounters do
      tooltip:AddLine(completedEncounters[i], RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    end
  end

  autoAcceptOption = autoAcceptOption or LFG_LIST_UTIL_ALLOW_AUTO_ACCEPT_LINE

  if autoAcceptOption == LFG_LIST_UTIL_ALLOW_AUTO_ACCEPT_LINE and searchResultInfo.autoAccept then
    tooltip:AddLine(" ")
    tooltip:AddLine(LFG_LIST_TOOLTIP_AUTO_ACCEPT, LIGHTBLUE_FONT_COLOR:GetRGB())
  end

  if (searchResultInfo.isDelisted) then
    tooltip:AddLine(" ")
    tooltip:AddLine(LFG_LIST_ENTRY_DELISTED, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
  end

  tooltip:Show()
end

local function L_LFGListSearchEntry_OnEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 25, 0)
  local resultID = self.resultID
  L_LFGListUtil_SetSearchEntryTooltip(GameTooltip, resultID)
end

local SearchEntryUpdate = function(self)
  if (not LFMPlus.mPlusSearch) or (not LFGListFrame.SearchPanel:IsShown()) then
    return
  end

  local resultID = self.resultID
  local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
  local _, appStatus, pendingStatus, appDuration = C_LFGList.GetApplicationInfo(resultID)
  local isApplication = (appStatus ~= "none" or pendingStatus)
  local isAppFinished = LFGListUtil_IsStatusInactive(appStatus) or LFGListUtil_IsStatusInactive(pendingStatus)

  --Update visibility based on whether we're an application or not
  self.isApplication = isApplication
  self.ApplicationBG:SetShown(isApplication and not isAppFinished)
  self.ResultBG:SetShown(not isApplication or isAppFinished)
  self.DataDisplay:SetShown(not isApplication)
  self.CancelButton:SetShown(isApplication and pendingStatus ~= "applied")
  self.CancelButton:SetEnabled(LFGListUtil_IsAppEmpowered())
  self.CancelButton.Icon:SetDesaturated(not LFGListUtil_IsAppEmpowered())
  self.CancelButton.tooltip = (not LFGListUtil_IsAppEmpowered()) and LFG_LIST_APP_UNEMPOWERED
  self.Spinner:SetShown(pendingStatus == "applied")

  if (pendingStatus == "applied" and C_LFGList.GetRoleCheckInfo()) then
    self.PendingLabel:SetText(LFG_LIST_ROLE_CHECK)
    self.PendingLabel:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif (pendingStatus == "cancelled" or appStatus == "cancelled" or appStatus == "failed") then
    self.PendingLabel:SetText(LFG_LIST_APP_CANCELLED)
    self.PendingLabel:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif (appStatus == "declined" or appStatus == "declined_full" or appStatus == "declined_delisted") then
    self.PendingLabel:SetText((appStatus == "declined_full") and LFG_LIST_APP_FULL or LFG_LIST_APP_DECLINED)
    self.PendingLabel:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif (appStatus == "timedout") then
    self.PendingLabel:SetText(LFG_LIST_APP_TIMED_OUT)
    self.PendingLabel:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif (appStatus == "invited") then
    self.PendingLabel:SetText(LFG_LIST_APP_INVITED)
    self.PendingLabel:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif (appStatus == "inviteaccepted") then
    self.PendingLabel:SetText(LFG_LIST_APP_INVITE_ACCEPTED)
    self.PendingLabel:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif (appStatus == "invitedeclined") then
    self.PendingLabel:SetText(LFG_LIST_APP_INVITE_DECLINED)
    self.PendingLabel:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif (isApplication and pendingStatus ~= "applied") then
    self.PendingLabel:SetText("")
    self.PendingLabel:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Show()
    self.CancelButton:Show()
  else
    self.PendingLabel:Hide()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  end

  --Center justify if we're on more than one line
  if (self.PendingLabel:GetHeight() > 15) then
    self.PendingLabel:SetJustifyH("CENTER")
  else
    self.PendingLabel:SetJustifyH("RIGHT")
  end
  self.ExpirationTime:ClearAllPoints()
  self.ExpirationTime:SetPoint("BOTTOMRIGHT", self.DataDisplay.Enumerate.Icon5, "BOTTOMLEFT", 0, 0)
  --Change the anchor of the label depending on whether we have the expiration time
  if (self.ExpirationTime:IsShown()) then
    self.ExpirationTime:SetWidth(20)
    self.PendingLabel:ClearAllPoints()
    self.PendingLabel:SetPoint("RIGHT", self.ExpirationTime, "LEFT", 0, 0)
  else
    self.PendingLabel:ClearAllPoints()
    self.PendingLabel:SetPoint("BOTTOMRIGHT", self.DataDisplay.Enumerate.Icon5, "BOTTOMLEFT", 0, 0)
  end

  self.expiration = GetTime() + appDuration

  local activityName = C_LFGList.GetActivityFullName(searchResultInfo.activityID, nil, searchResultInfo.isWarMode)

  self.resultID = resultID
  self.Selected:SetShown(LFMPlusFrame.selectedResult == resultID and not isApplication and not searchResultInfo.isDelisted)
  self.Highlight:SetShown(LFMPlusFrame.selectedResult ~= resultID and not isApplication and not searchResultInfo.isDelisted)
  local nameColor = NORMAL_FONT_COLOR
  local activityColor = GRAY_FONT_COLOR
  if (searchResultInfo.isDelisted or isAppFinished) then
    nameColor = LFG_LIST_DELISTED_FONT_COLOR
    activityColor = LFG_LIST_DELISTED_FONT_COLOR
  elseif (searchResultInfo.numBNetFriends > 0 or searchResultInfo.numCharFriends > 0 or searchResultInfo.numGuildMates > 0) then
    nameColor = BATTLENET_FONT_COLOR
  end
  self.Name:SetWidth(0)
  self.Name:SetText(searchResultInfo.name)
  self.Name:SetTextColor(nameColor.r, nameColor.g, nameColor.b)
  self.ActivityName:SetText(activityName)
  self.ActivityName:SetTextColor(activityColor.r, activityColor.g, activityColor.b)
  self.VoiceChat:SetShown(searchResultInfo.voiceChat ~= "")
  self.VoiceChat.tooltip = searchResultInfo.voiceChat

  local displayData = C_LFGList.GetSearchResultMemberCounts(resultID)
  LFGListGroupDataDisplay_Update(self.DataDisplay, searchResultInfo.activityID, displayData, searchResultInfo.isDelisted)

  local nameWidth = isApplication and 165 or 176
  if (searchResultInfo.voiceChat ~= "") then
    nameWidth = nameWidth - 22
  end
  if (self.Name:GetWidth() > nameWidth) then
    self.Name:SetWidth(nameWidth)
  end
  self.ActivityName:SetWidth(nameWidth)

  local mouseFocus = GetMouseFocus()
  if (mouseFocus == self) then
    L_LFGListSearchEntry_OnEnter(self)
  end
  if (mouseFocus == self.VoiceChat) then
    mouseFocus:GetScript("OnEnter")(mouseFocus)
  end

  local UpdateExpiration = function(btn)
    local duration = 0
    local now = GetTime()
    if (btn.expiration and btn.expiration > now) then
      duration = btn.expiration - now
    end

    local minutes = math.floor(duration / 60)
    local seconds = duration % 60
    if minutes > 1 then
      btn.ExpirationTime:SetFormattedText("%dm", minutes)
    else
      btn.ExpirationTime:SetFormattedText("%.2ds", seconds)
    end
  end

  if (isApplication) then
    self:SetScript("OnUpdate", UpdateExpiration)
    UpdateExpiration(self)
  else
    self:SetScript("OnUpdate", nil)
  end

  local playstyleString = GREEN_FONT_COLOR:WrapTextInColorCode(ns.constants.playStyleString[searchResultInfo.playstyle] or "")
  local numMembers = searchResultInfo.numMembers
  local orderIndexes = {}

  for i = 1, numMembers do
    local role, class = C_LFGList.GetSearchResultMemberInfo(resultID, i)
    local leader = i == 1 or false
    local orderIndex = getIndex(LFG_LIST_GROUP_DATA_ROLE_ORDER, role)
    -- Insert the orderIndex of the role (Tank, Healer, DPS) along with the class, group leader indicator and role.
    table.insert(orderIndexes, {orderIndex, class, leader, role})
  end

  -- Sort the table by order index placing Tanks over Healers over DPS.
  table.sort(
    orderIndexes,
    function(a, b)
      return a[1] < b[1]
    end
  )

  local dataDisplayEnum = self.DataDisplay.Enumerate
  -- Process each member of the group.
  for i = 1, numMembers do
    -- Icon Frames go right to left where group member 1 is Icon5 and group member 5 is Icon1.
    -- To account for this, we do some simple math to get the Icon frame for the group member we are currently working with.
    local iconNumber = (5 - i) + 1
    local class = orderIndexes[i][2]

    -- The role icons we use match for TANK and HEALER but not for DPS.
    local roleName = orderIndexes[i][4] == "DAMAGER" and "DPS" or orderIndexes[i][4]
    local classColor = RAID_CLASS_COLORS[class]
    local r, g, b, _ = classColor:GetRGBA()

    local iconFrame = dataDisplayEnum["Icon" .. iconNumber]
    iconFrame:SetSize(18, 18)

    for _, v in ipairs(ns.constants.searchEntryFrames) do
      if iconFrame[v] then
        iconFrame[v]:Hide()
      end
    end

    -- dot - Displays a sphere colored to the class behind a smaller role icon in the same position as the default UI.
    -- icon - Displays an icon for the class in the same position as the default UI with a small role (if tank or healer) attached to the bottom of the icon.
    if db.classRoleDisplay == "dot" or db.classRoleDisplay == "icon" then
      -- Create and configure the frame needed.

      if not iconFrame.classDot then
        local f = CreateFrame("Frame", dataDisplayEnum["ClassDot" .. iconNumber], dataDisplayEnum)
        f:SetFrameLevel(dataDisplayEnum:GetFrameLevel())
        f:SetPoint("CENTER", iconFrame)
        f:SetSize(18, 18)

        f.tex = f:CreateTexture(dataDisplayEnum["ClassDot" .. iconNumber .. "Tex"], "ARTWORK")
        f.tex:SetAllPoints(f)

        f.tex:SetTexture([[Interface\AddOns\LFM+\Textures\Circle_Smooth_Border]])
        f:Hide()
        iconFrame.classDot = f
      end

      if not iconFrame.roleIcon then
        ---@type Texture
        local f = dataDisplayEnum:CreateTexture(dataDisplayEnum["RoleIcon" .. iconNumber], "OVERLAY")
        f:SetSize(10, 10)
        f:SetPoint("TOP", iconFrame, "CENTER", -1, -3)
        f:Hide()
        iconFrame.roleIcon = f
      end

      iconFrame.roleIcon:SetAtlas("roleicon-tiny-" .. string.lower(roleName))

      if db.classRoleDisplay == "dot" then
        iconFrame:Hide()
        iconFrame.classDot.tex:SetVertexColor(r, g, b, 1)
        iconFrame.classDot:Show()
        iconFrame.roleIcon:SetPoint("TOP", iconFrame, "CENTER", 0, 5)
      elseif db.classRoleDisplay == "icon" then
        iconFrame.roleIcon:SetPoint("TOP", iconFrame, "CENTER", -1, -3)
        iconFrame:SetAtlas("groupfinder-icon-class-" .. string.lower(class))
      end

      iconFrame.roleIcon:Show()
    elseif db.classRoleDisplay == "bar" then
      -- Ensure the display is set to default settings.
      if not iconFrame.classBar then
        ---@type Texture
        local f = dataDisplayEnum:CreateTexture(dataDisplayEnum["ClassBar" .. iconNumber], "ARTWORK")
        f:SetSize(10, 3)
        f:SetPoint("TOP", iconFrame, "BOTTOM")
        f:Hide()
        iconFrame.classBar = f
      end
      iconFrame.classBar:SetColorTexture(r, g, b, 1)
      iconFrame.classBar:Show()
    elseif db.classRoleDisplay == "def" then
      iconFrame:SetSize(18, 18)
      for _, v in ipairs(ns.constants.searchEntryFrames) do
        if iconFrame[v] then
          iconFrame[v]:Hide()
        end
      end
    end

    -- Displays a crown attached to the top of the leaders role icon.
    if db.showPartyLeader == true then
      if not dataDisplayEnum.leader then
        local f = dataDisplayEnum:CreateTexture(dataDisplayEnum["LeaderIcon"], "OVERLAY")
        f:SetSize(10, 5)
        f:SetPoint("BOTTOM", iconFrame, "TOP", 0, 0)
        f:SetAtlas("groupfinder-icon-leader", false, "LINEAR")
        f:Hide()
        dataDisplayEnum.leader = f
      end

      if orderIndexes[i][3] then
        dataDisplayEnum.leader:SetPoint("BOTTOM", iconFrame, "TOP", 0, 0)
        dataDisplayEnum.leader:Show()
      end
    else
      if dataDisplayEnum.leader then
        dataDisplayEnum.leader:Hide()
      end
    end
  end

  -- Hide any new member icons that may have been created but do not need to be shown for the current group.
  if numMembers < 5 then
    for i = numMembers + 1, 5 do
      local icon = dataDisplayEnum["Icon" .. ((5 - i) + 1)]
      if (icon) then
        for _, v in ipairs(ns.constants.searchEntryFrames) do
          if icon[v] then
            icon[v]:Hide()
          end
        end
      end
    end
  end

  if db.alwaysShowRoles then
    self.DataDisplay:ClearAllPoints()
    self.DataDisplay:SetPoint("BOTTOMRIGHT", self.CancelButton, "BOTTOMLEFT", 5, -5)
    if not self.DataDisplay:IsShown() then
      self.DataDisplay:Show()
    end
  end

  if db.showLeaderScore and not searchResultInfo.isDelisted and LFMPlusFrame.dungeonList[searchResultInfo.activityID] then
    local formattedLeaderScore = LFMPlus:formatMPlusRating(searchResultInfo.leaderOverallDungeonScore or 0)
    self.Name:SetText(formattedLeaderScore .. " " .. self.Name:GetText())
    self.ActivityName:SetWordWrap(false)
  end

  if db.shortenActivityName and ns.constants.actvityInfo[searchResultInfo.activityID] then
    self.ActivityName:SetText(ns.constants.actvityInfo[searchResultInfo.activityID].shortName .. " (M+)")
    self.ActivityName:SetWordWrap(false)
  end

  if db.showRealmName and LFMPlusFrame.dungeonList[searchResultInfo.activityID] then
    local leaderName, realmName = LFMPlus:GetNameRealm(searchResultInfo.leaderName)
    if (leaderName) then
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
        self.ActivityName:SetText(self.ActivityName:GetText() .. " " .. realmName)
        self.ActivityName:SetWordWrap(false)
      end
    end
  end
  if searchResultInfo.playstyle > 1 then
    self.ActivityName:SetText(self.ActivityName:GetText() .. "/" .. playstyleString)
  end

  --LFGListFrame.SearchPanel.ScrollFrame.buttons[self.idx]:Hide()
end

local function L_LFGListSearchPanel_UpdateResults(self)
  LFMPlusFrame.results = self.results
  LFMPlusFrame.applications = self.applications
  L_LFGListUtil_SortSearchResults(LFMPlusFrame.results)
  local offset = HybridScrollFrame_GetOffset(self.ScrollFrame)
  local buttons = LFMPlusFrame.buttons

  if (self.searching) then
    self.SearchingSpinner:Show()
    for i = 1, #buttons do
      buttons[i]:Hide()
    end
  else
    local results = LFMPlusFrame.results
    local apps = LFMPlusFrame.applications
    for i = 1, #buttons do
      local button = buttons[i]
      local idx = i + offset
      local result = results[idx] --local result = (idx <= #apps) and apps[idx] or results[idx - #apps];

      if (result) then
        button.resultID = result
        SearchEntryUpdate(button)
        button:Show()
      else
        button.resultID = nil
        button:Hide()
      end
    end
    local totalHeight = buttons[1]:GetHeight() * (#results + #apps)

    HybridScrollFrame_Update(LFGListFrame.SearchPanel.ScrollFrame, totalHeight, LFGListFrame.SearchPanel.ScrollFrame:GetHeight())
  end
end

local function L_LFGListSearchEntry_OnClick(self, button)
  LFMPlusFrame.selectedResult = self.resultID
  LFGListSearchEntry_OnClick(LFGListFrame.SearchPanel.ScrollFrame.buttons[self.idx], button)
end

local SortApplicants = function(applicants)
  if not LFMPlus.mPlusListed then
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
      for i = 1, applicantInfo.numMembers do
        local name,
          className,
          _,
          _,
          _,
          _,
          _, --tank,
          _, --healer,
          _, --damage,
          _,
          relationship,
          dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, i)

        local _, realmName = LFMPlus:GetNameRealm(name)

        if not db.realmList[realmName] then
          db.realmList[realmName] = true
        end

        --[[
        if tank or healer or healer or damage then
        end
        ]]
        relationship = relationship or false
        friendFound = friendFound or relationship
        neededClassFound = neededClassFound or LFMPlusFrame.classList[className].checked
        requiredScoreFound = requiredScoreFound or (dungeonScore > db.ratingFilterMin)
      end

      if ((db.ratingFilter and (requiredScoreFound == false)) or (db.classFilter and (neededClassFound == false))) then
        if not (LFMPlusFrame.exemptIDs[applicantID]) then
          LFMPlus:addFilteredId(LFGListFrame.ApplicationViewer, applicantID)
        end
      else
        if not LFMPlus.eligibleApplicantList[applicantID] then
          LFMPlus.newEligibleApplicant = true
          LFMPlus.eligibleApplicantList[applicantID] = true
        end
      end
    else
      LFMPlus.newEligibleApplicant = true
      LFMPlus.eligibleApplicantList[applicantID] = true
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

    if (LFGListFrame.activePanel.filteredIDs) then
      LFMPlus:filterTable(applicants, LFGListFrame.activePanel.filteredIDs)
      LFGListFrame.activePanel.filteredIDs = nil
    end
  end

  table.sort(applicants, SortApplicantsCB)

  if (#applicants > 0) then
    LFMPlusFrame.totalResults = #applicants
  --LFGListApplicationViewer_UpdateResults(LFGListFrame.activePanel)
  end

  LFMPlusFrame.totalResults = #applicants
  LFMPlusFrame:UpdateDeclineButtonInfo()
end

local UpdateApplicantMember = function(member, appID, memberIdx, status, pendingStatus, ...)
  if (not LFMPlus.mPlusListed) or (not LFGListFrame.ApplicationViewer:IsShown()) then
    return
  end

  local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
  --[[   local grayedOut =
    not pendingStatus and
    (status == "failed" or status == "cancelled" or status == "declined" or status == "declined_full" or status == "declined_delisted" or status == "invitedeclined" or
      status == "timedout" or
      status == "inviteaccepted" or
      status == "invitedeclined") ]]
  if (not activeEntryInfo) then
    return
  end

  -- local textName = member.Name:GetText()
  local _,
    _, --className,
    _,
    _,
    _,
    _,
    _,
    _,
    _,
    _,
    relationship,
    dungeonScore = C_LFGList.GetApplicantMemberInfo(appID, memberIdx)

  local bestDungeonScoreForEntry = C_LFGList.GetApplicantDungeonScoreForListing(appID, memberIdx, activeEntryInfo.activityID)
  local scoreText = LFMPlus:formatMPlusRating(dungeonScore)

  local bestRunString = bestDungeonScoreForEntry and ("|" .. (bestDungeonScoreForEntry.finishedSuccess and "cFF00FF00" or "cFFFF0000") .. bestDungeonScoreForEntry.bestRunLevel .. "|r") or ""
  member.Rating:SetText(" " .. scoreText .. " - " .. bestRunString)

  local nameLength = 100
  if (relationship) then
    nameLength = nameLength - 22
  end

  if (member.Name:GetWidth() > nameLength) then
    member.Name:SetWidth(nameLength)
  end
end

local function InitializeUI()
  do
    local f = LFMPlusFrame
    f:SetPoint("BOTTOMRIGHT", GroupFinderFrame, "TOPRIGHT")

    -- Set defaults to the LFMPlusFrame
    f.buttons = {}
    f.classList = {}
    f.classListLoaded = false
    f.declineButtonInfo = {}
    f.dungeonList = {}
    f.dungeonListLoaded = false
    f.exemptIDs = {}
    f.expand = true
    f.filteredIDs = {}
    f.fixedHeight = 50
    f.frames = {search = {}, app = {}, all = {}}
    f.nextAppDecline = nil
    f.results = {}
    f.selectedResult = nil
    f.spacing = 5
    f.totalResults = 0

    ---@class DialogHeaderTemplate:Frame
    ---@field Text FontString
    f.Header = CreateFrame("Frame", nil, LFMPlusFrame, "DialogHeaderTemplate")
    f.Header.Text:SetText("LFM+")
    f.Header:SetWidth(80)
    f.Border = CreateFrame("Frame", nil, LFMPlusFrame, "DialogBorderTemplate")

    function f:UpdateDeclineButtonInfo()
      self.declineButtonInfo = {}
      if (not LFMPlus.mPlusListed) then
        LFMPlusFrame.declineButton:SetText(0)
      else
        for i = 1, ns.constants.declineQueueMax do
          if not self.filteredIDs[i] then
            break
          end
          local applicantID = self.filteredIDs[i]
          local applicantData = C_LFGList.GetApplicantInfo(applicantID)
          if applicantData then
            local groupEntry = {}
            for memberIdx = 1, applicantData.numMembers do
              local name, className, _, _, _, _, tank, healer, damage, _, _, dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
              local shortName, server = LFMPlus:GetNameRealm(name)
              local formattedName = RAID_CLASS_COLORS[className]:WrapTextInColorCode(string.format(ns.constants.lengths.name, shortName))
              local roleIcons = string.format("%s%s%s", CreateAtlasMarkup(tank and "roleicon-tiny-tank" or "groupfinder-icon-emptyslot", 10, 10), CreateAtlasMarkup(healer and "roleicon-tiny-healer" or "groupfinder-icon-emptyslot", 10, 10), CreateAtlasMarkup(damage and "roleicon-tiny-dps" or "groupfinder-icon-emptyslot", 10, 10))

              local header = CreateAtlasMarkup(((applicantID == self.nextAppDecline and memberIdx == 1) and "pvpqueue-sidebar-nextarrow" or ""), 10, 10)
              local memberString = string.format("%s%s %s %s %s", header, LFMPlus:formatMPlusRating(dungeonScore), roleIcons, formattedName, string.format(ns.constants.lengths.server, server))
              table.insert(groupEntry, memberString)
            end
            self.declineButtonInfo[applicantID] = groupEntry
          end
        end
        LFMPlusFrame.declineButton:SetText(#LFMPlusFrame.filteredIDs > 0 and GREEN_FONT_COLOR:WrapTextInColorCode(tostring(#LFMPlusFrame.filteredIDs)) or 0)
        if GameTooltip:IsShown() and GameTooltip:GetOwner():GetName() == "LFMPlusFrame.declineButton" then
          LFMPlus:DeclineButtonTooltip()
        end
      end
    end

    function f:FindFilteredId(id)
      for i = 1, #LFMPlusFrame.filteredIDs do
        if LFMPlusFrame.filteredIDs[i] == id then
          return i
        end
      end
      return nil
    end

    function f:ProcessFilteredApp(action)
      -- If the applicant status is anything other than invited or applied it means thier listing is "inactive".
      -- This would be indicated by the default UI as faded entry in the scroll from and happens when an application
      -- expires due to time, the applicant cancels their own application or the applicant gets invited to another group.
      -- At this point, RemoveApplicant is simply clearing the application from the list versus actually declining it like DeclineApplicant.
      if LFMPlusFrame.nextAppDecline then
        local applicantInfo = C_LFGList.GetApplicantInfo(LFMPlusFrame.nextAppDecline)
        if applicantInfo then
          local inactiveApplication = (applicantInfo.applicationStatus ~= "applied" and applicantInfo.applicationStatus ~= "invited")
          if action == "decline" and LFMPlus.isLeader then
            if inactiveApplication then
              C_LFGList.RemoveApplicant(LFMPlusFrame.nextAppDecline)
            else
              C_LFGList.DeclineApplicant(LFMPlusFrame.nextAppDecline)
            end
            LFMPlus:RemoveApplicantId(LFMPlusFrame.nextAppDecline)
          elseif action == "exclude" then
            LFMPlus:excludeFilteredId(LFMPlusFrame.nextAppDecline)
            if not LFGListFrame.activePanel.searching then
              LFGListFrame.activePanel.RefreshButton:Click()
            end
          end
        end
      end
    end

    function f:ShiftDeclineSelection(direction)
      local newVal = nil

      for i = 1, #LFMPlusFrame.filteredIDs do
        local id = LFMPlusFrame.filteredIDs[i]

        if ((LFMPlusFrame.nextAppDecline == id) or (LFMPlusFrame.nextAppDecline == nil)) and direction == nil then
          LFMPlusFrame.nextAppDecline = id
          LFMPlusFrame:UpdateDeclineButtonInfo()
          return
        end

        local nextId = LFMPlusFrame.filteredIDs[i + 1]
        local prevId = LFMPlusFrame.filteredIDs[i - 1]

        if LFMPlusFrame.nextAppDecline == id then
          if direction == true and (nextId and (i + 1 <= ns.constants.declineQueueMax)) then
            newVal = nextId
            break
          elseif direction == false then
            if prevId then
              newVal = prevId
            else
              newVal = LFMPlusFrame.filteredIDs[ns.constants.declineQueueMax] or LFMPlusFrame.filteredIDs[#LFMPlusFrame.filteredIDs]
            end
            break
          end
        end
      end

      if (newVal == nil and LFMPlusFrame.filteredIDs[1]) then
        newVal = LFMPlusFrame.filteredIDs[1]
      end
      LFMPlusFrame.nextAppDecline = newVal
      LFMPlusFrame:UpdateDeclineButtonInfo()
    end

    -- Create score filter slider
    ---@class OptionsSliderTemplate:Frame
    ---@field Text FontString
    ---@field Low FontString
    ---@field High FontString
    ---@field SetValueStep function
    ---@field SetObeyStepOnDrag function
    ---@field SetMinMaxValues function
    ---@field SetValue function
    ---@field Enable function
    ---@field Disable function
    f.scoreMinFrame = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")

    f.scoreMinFrame.bottomPadding = 13
    f.scoreMinFrame.layoutIndex = 3
    f.scoreMinFrame.leftPadding = 35
    f.scoreMinFrame.rightPadding = 15
    f.scoreMinFrame.topPadding = 32

    function f.scoreMinFrame:SetDisplayValue(value)
      self.noclick = true
      self:SetValue(value)
      self.Value:SetText(LFMPlus:formatMPlusRating(value))
      db.ratingFilterMin = value
      db.ratingFilter = value > 0
      LFMPlus:RefreshResults()
      self.noclick = false
    end

    function f.scoreMinFrame:SetEnable(value)
      if value then
        self:Enable()
        self:SetAlpha(1)
      else
        self:Disable()
        self:SetAlpha(.5)
      end
    end

    f.scoreMinFrame:SetScript(
      "OnValueChanged",
      function(self, value)
        self:SetDisplayValue(value)
      end
    )

    f.scoreMinFrame:SetValueStep(100)
    f.scoreMinFrame:SetObeyStepOnDrag(false)
    f.scoreMinFrame:SetSize(125, 15)

    f.scoreMinFrame.Value = f.scoreMinFrame.Text
    f.scoreMinFrame.Value:ClearAllPoints()
    f.scoreMinFrame.Value:SetPoint("TOP", f.scoreMinFrame, "BOTTOM", 0, 3)

    f.scoreMinFrame:SetMinMaxValues(ns.constants.ratingMin, ns.constants.ratingMax)
    f.scoreMinFrame:SetDisplayValue(db.ratingFilterMin)
    f.scoreMinFrame.Low:SetText(LFMPlus:formatMPlusRating(ns.constants.ratingMin))
    f.scoreMinFrame.High:SetText(LFMPlus:formatMPlusRating(ns.constants.ratingMax))

    f.frames.search["scoreMinFrame"] = true
    f.frames.app["scoreMinFrame"] = true

    f:Hide()
  end

  do
    -- Create button to toggle filtering search results based on the result having a spot for your active role.
    local f = CreateFrame("Frame", "$parent.activeRoleFrame", LFMPlusFrame)

    f.bottomPadding = 10
    f.layoutIndex = 1
    f.leftPadding = 15
    f.rightPadding = 10
    f.topPadding = 28

    function f:UpdateRoleIcon()
      if CanInspect("player", false) then
        NotifyInspect("player")
        LFMPlus:RegisterEvent(
          "INSPECT_READY",
          function(_, guid)
            if UnitGUID("player") == guid then
              LFMPlus:UnregisterEvent("INSPECT_READY")
              local role = GetSpecializationRoleByID(GetInspectSpecialization("player"))
              local roleAtlas = ns.constants.atlas[role] or ns.constants.atlas.NA
              self.roleIcon:SetText(CreateAtlasMarkup(roleAtlas, 25, 25))
            end
          end
        )
      end
    end

    function f:ToggleGlow()
      if db.activeRoleFilter then
        f.roleIconGlow:Show()
      else
        f.roleIconGlow:Hide()
      end
    end

    --f:SetFrameLevel(1)
    f:SetSize(25, 25)
    --f:SetPoint("LEFT", LFMPlusFrame, "LEFT", 10, 0)
    f.roleIcon = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.roleIcon:SetText(L["Role"])
    f.roleIcon:SetSize(30, 30)
    f.roleIcon:SetPoint("CENTER", f, "CENTER")

    f.roleIconGlow = f:CreateFontString(nil, "BORDER", "GameFontNormal")
    f.roleIconGlow:SetText(CreateAtlasMarkup("groupfinder-eye-highlight", 40, 40))
    f.roleIconGlow:SetSize(45, 45)
    f.roleIconGlow:SetPoint("CENTER", f.roleIcon, "CENTER")

    f.tooltipText = L["ActiveRoleTooltip"]
    f:SetScript("OnEnter", showTooltip)
    f:SetScript("OnLeave", hideTooltip)
    f:SetScript(
      "OnMouseDown",
      function(self, button)
        if button == "LeftButton" then
          db.activeRoleFilter = not db.activeRoleFilter
          f.ToggleGlow()
          LFMPlus:RefreshResults()
        end
      end
    )

    LFMPlusFrame.activeRoleFrame = f
    LFMPlusFrame.frames.search["activeRoleFrame"] = true

    f:UpdateRoleIcon()
    f:ToggleGlow()
    f:Hide()
  end

  do
    -- Create the dropdown menu used for dungeon and class filtering.
    local f = LibDD:Create_UIDropDownMenu("LFMPlusDD", LFMPlusFrame)
    LibDD:UIDropDownMenu_SetWidth(f, 30, 0)

    f.bottomPadding = 13
    f.layoutIndex = 2
    f.leftPadding = -15
    f.rightPadding = 10
    f.topPadding = 28

    function f:SelectedCount()
      local activeList = LFMPlus.mPlusSearch and LFMPlusFrame.dungeonList or LFMPlusFrame.classList
      local c = 0
      for _, v in pairs(activeList) do
        c = v.checked and c + 1 or c
      end
      return c
    end

    function f:SetCountText()
      LibDD:UIDropDownMenu_SetText(f, f:SelectedCount() > 0 and GREEN_FONT_COLOR:WrapTextInColorCode(f:SelectedCount()) or f:SelectedCount())
      LibDD:UIDropDownMenu_JustifyText(f, "CENTER")
    end

    local function LFMPlusDD_OnClick(self, id)
      local activeList = LFMPlus.mPlusSearch and LFMPlusFrame.dungeonList or LFMPlus.mPlusListed and LFMPlusFrame.classList
      if id == false then
        for _, v in pairs(activeList) do
          v.checked = false
        end
      else
        activeList[id].checked = not activeList[id].checked
        LibDD:UIDropDownMenu_SetSelectedValue(f, id)
      end
      db.dungeonFilter = (LFMPlus.mPlusSearch and f:SelectedCount() > 0)
      db.classFilter = (LFMPlus.mPlusListed and f:SelectedCount() > 0)
      LibDD:UIDropDownMenu_Refresh(f)
      f:SetCountText()
      LFMPlus:RefreshResults()
    end

    function f.LFMPlusDD_Initialize(self)
      if not LFMPlusFrame.classListLoaded then
        -- Build out class list.
        for i = 1, GetNumClasses() do
          local name, file, id = GetClassInfo(i)
          local coloredName = RAID_CLASS_COLORS[file]:WrapTextInColorCode(name)

          LFMPlusFrame.classList[file] = {
            name = coloredName,
            id = file,
            classId = id,
            sName = name,
            checked = false
          }
          db.classFilter = false
          LFMPlusFrame.classListLoaded = true
        end
      end

      if not LFMPlusFrame.dungeonListLoaded then
        -- Build out dungeon list.
        local activityIDs = C_LFGList.GetAvailableActivities(2, nil, 1)
        local mapChallengeModeIDs = C_ChallengeMode.GetMapTable()
        if ((not activityIDs) or (#activityIDs == 0)) or ((not mapChallengeModeIDs) or (#mapChallengeModeIDs == 0)) then
          return
        end
        local mapChallengeModeInfo = {}
        if (not activityIDs) or (#activityIDs == 0) or (not mapChallengeModeIDs) or (#mapChallengeModeIDs == 0) then
          LFMPlusFrame.dungeonListLoaded = false
          return
        end
        for _, mapChallengeModeID in pairs(mapChallengeModeIDs) do
          local name, id, timeLimit, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
          table.insert(
            mapChallengeModeInfo,
            {
              id = nil,
              name = nil,
              longName = name,
              challMapID = id,
              timeLimit = timeLimit,
              texture = texture,
              backgroundTexture = backgroundTexture,
              checked = false
            }
          )
        end
        for _, activityID in pairs(activityIDs) do
          local fullName, _, _, _, _, _, _, _, _, _, _, _, isMythicPlus, _, _ = C_LFGList.GetActivityInfo(activityID)
          if isMythicPlus then
            for _, challMap in pairs(mapChallengeModeInfo) do
              if fullName:find(challMap.longName) then
                local dungeon = challMap
                dungeon.id = activityID
                dungeon.name = ns.constants.actvityInfo[activityID].shortName or fullName
                LFMPlusFrame.dungeonList[activityID] = dungeon
              end
            end
          end
        end
        LFMPlusFrame.dungeonListLoaded = true
      end
      local activeList = LFMPlus.mPlusSearch and LFMPlusFrame.dungeonList or LFMPlusFrame.classList
      local info = LibDD:UIDropDownMenu_CreateInfo()

      info.justifyH = "CENTER"
      info.isTitle = true
      info.notCheckable = true
      info.disabled = true
      info.text = LFMPlus.mPlusSearch and DUNGEONS or CLASS
      info.owner = self
      LibDD:UIDropDownMenu_AddButton(info)

      for id, item in pairs(activeList) do
        info.isTitle = false
        info.func = LFMPlusDD_OnClick
        info.keepShownOnClick = true
        info.ignoreAsMenuSelection = true
        info.notCheckable = false
        info.disabled = false
        info.text = item.name
        info.checked = function()
          local list = LFMPlus.mPlusSearch and LFMPlusFrame.dungeonList or LFMPlusFrame.classList
          if (list) and list[id] then
            return list[id].checked
          end
          return false
        end
        info.arg1 = id
        LibDD:UIDropDownMenu_AddButton(info)
      end
      info.text = "Clear"
      info.notClickable = self:SelectedCount() < 1
      info.notCheckable = true
      info.arg1 = false
      LibDD:UIDropDownMenu_AddSeparator()
      LibDD:UIDropDownMenu_AddButton(info)
      f:SetCountText()
    end

    LibDD:UIDropDownMenu_Initialize(f, f.LFMPlusDD_Initialize)

    f:Hide()

    LFMPlusFrame.DD = f
    LFMPlusFrame.frames.search["DD"] = true
    LFMPlusFrame.frames.app["DD"] = true
  end

  do
    -- Create button used for declining filtered applicants.
    local f = CreateFrame("Button", "$parent.declineButton", LFMPlusFrame, "SharedGoldRedButtonTemplate")

    f.app = nil
    f.bottomPadding = 13
    f.layoutIndex = 1
    f.leftPadding = 15
    f.rightPadding = 5
    f.topPadding = 28

    f:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    f:SetFrameLevel(1)
    f:SetFrameStrata("HIGH")
    f:SetNormalFontObject("GameFontNormalSmall")
    f:SetPoint("CENTER", LFMPlusFrame.activeRoleFrame, "CENTER", 0, 0)
    f:SetSize(40, 25)
    f:SetText("0")

    f:SetScript(
      "OnClick",
      function(s, b, d)
        if b == "LeftButton" then
          LFMPlusFrame:ProcessFilteredApp(IsShiftKeyDown() and "exclude" or "decline")
        elseif b == "RightButton" then
          LFMPlusFrame:ShiftDeclineSelection(IsShiftKeyDown() and false)
        end
      end
    )

    f:SetScript(
      "OnEnter",
      function(s)
        LFMPlusFrame:ShiftDeclineSelection()
        LFMPlus:DeclineButtonTooltip()
      end
    )

    f:SetScript("OnLeave", GameTooltip_Hide)
    f:Hide()

    LFMPlusFrame.declineButton = f
    LFMPlusFrame.frames.app["declineButton"] = true
  end

  LFMPlusFrame:Layout()
end

local options = {
  type = "group",
  name = L["LFMPlus"],
  desc = L["LFMPlus"],
  get = function(info)
    return db[info.arg]
  end,
  args = {
    enabled = {
      type = "toggle",
      name = L["Enable LFMPlus"],
      desc = L["Enable or disable LFMPlus"],
      order = 1,
      arg = "enabled",
      set = function(info, v)
        db[info.arg] = v
        if v then
          LFMPlus:Enable()
        else
          LFMPlus:Disable()
        end
      end,
      disabled = false
    },
    lfgListing = {
      type = "group",
      name = L["LFG Listings"],
      desc = L["Settings that modify how listings in LFG are shown."],
      descStyle = "inline",
      order = 10,
      get = function(info)
        return db[info.arg]
      end,
      set = function(info, v)
        db[info.arg] = v
        LFMPlus:FilterChanged()
      end,
      disabled = function()
        return not db.enabled
      end,
      args = {
        showLeaderScore = {
          type = "toggle",
          width = "full",
          name = L["Show Leader Score"],
          descStyle = "inline",
          desc = L["Toggle appending the group leaders score to the start of group listings in LFG."],
          arg = "showLeaderScore",
          order = 10
        },
        showLeaderScoreDesc = {
          type = "description",
          width = "full",
          name = "         " .. LFMPlus:formatMPlusRating(2200) .. " " .. NORMAL_FONT_COLOR:WrapTextInColorCode("19 PF LUST"),
          fontSize = "medium",
          order = 11
        },
        classRoleDisplay = {
          type = "select",
          width = "full",
          name = "Class/Role Display Type",
          desc = "The type of icons the default UI's role icons are replaced with.",
          descStyle = "inline",
          arg = "classRoleDisplay",
          style = "radio",
          values = {
            ["def"] = "Default Icons",
            ["dot"] = "Role Icon Over Class Color",
            ["icon"] = "Class Icon with Role Icon",
            ["bar"] = "Class Colored Bar"
          },
          sorting = {"def", "bar", "dot", "icon"},
          set = function(info, v)
            db[info.arg] = v
            LFMPlus:FilterChanged()
          end,
          order = 30
        },
        showPartyLeader = {
          type = "toggle",
          width = "full",
          name = "Indicate Party Leader",
          desc = "Toggle the display of an icon indicating which role is the group leader.",
          descStyle = "inline",
          arg = "showPartyLeader",
          set = function(info, v)
            db[info.arg] = v
            LFMPlus:FilterChanged()
          end,
          order = 30
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
          order = 31
        },
        shortenActivityName = {
          type = "toggle",
          width = "full",
          name = L["Shorten Dungeon Names"],
          desc = L["Toggle the length of dungeon names in LFG listings."],
          descStyle = "inline",
          arg = "shortenActivityName",
          order = 40
        },
        alwaysShowFriends = {
          type = "toggle",
          width = "full",
          name = L["Friends or Guildies"],
          desc = L["If enabled, LFM+ will always show groups or applicants if they include Friends or Guildies"],
          descStyle = "inline",
          arg = "alwaysShowFriends",
          order = 50
        }
      }
    },
    uiEnhancements = {
      type = "group",
      name = L["UI Enhancements"],
      desc = L["Settings that make enhancements to the default UI to improve functionality"],
      descStyle = "inline",
      order = 20,
      get = function(info)
        return db[info.arg]
      end,
      set = function(info, v)
        db[info.arg] = v
        LFMPlus:FilterChanged()
      end,
      disabled = function()
        return not db.enabled
      end,
      args = {
        lfgListingDoubleClick = {
          type = "toggle",
          width = "full",
          name = L["Enable Double-Click Sign Up"],
          desc = L["Toggle the ability to double-click on LFG listings to bring up the sign-up dialog."],
          descStyle = "inline",
          arg = "lfgListingDoubleClick",
          order = 10
        },
        autoFocusSignUp = {
          type = "toggle",
          width = "full",
          name = L["Auto Focus Sign Up Box"],
          desc = L["Toggle the abiity to have description field of the Sign Up box auto focused when you sign up for a listing."],
          descStyle = "inline",
          arg = "autoFocusSignUp",
          order = 20
        },
        signupOnEnter = {
          type = "toggle",
          width = "full",
          name = L["Sign Up On Enter"],
          desc = L["Toggle the abiity to press the Sign Up button after pressing enter while typing in the description field when applying for listings."],
          descStyle = "inline",
          arg = "signupOnEnter",
          order = 30
        },
        alwaysShowRoles = {
          type = "toggle",
          width = "full",
          name = L["Always Show Listing Roles"],
          desc = L["Toggle the ability to show what slots have filled for an LFG listing, even if you have applied for it."],
          descStyle = "inline",
          arg = "alwaysShowRoles",
          order = 40
        },
        hideAppViewerOverlay = {
          type = "toggle",
          width = "full",
          name = L["Hide Application Viewer Overlay"],
          desc = L["Toggle the ability to hide the overlay shown in the application viewer, even if you are not the group leader."],
          descStyle = "inline",
          arg = "hideAppViewerOverlay",
          order = 50
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
              order = 1
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
              order = 10
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
              order = 20
            },
            flagRealmList = {
              type = "multiselect",
              width = "full",
              descStyle = "inline",
              name = L["Realms"],
              desc = L["Realms selected below will be selected for filtering/flagging"],
              values = function()
                local rtnVal = {}
                for k, _ in pairs(db.flagRealmList) do
                  rtnVal[k] = k
                end
                return rtnVal
              end,
              get = function(info, key)
                return db[info.arg][key]
              end,
              set = function(info, value)
                db[info.arg][value] = not db[info.arg][value]
                local newTbl = {}
                for k, v in pairs(db[info.arg]) do
                  if (k ~= value) or v then
                    newTbl[k] = v
                  end
                end
                db[info.arg] = newTbl
                LFMPlus:FilterChanged()
              end,
              arg = "flagRealmList",
              order = 30
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
                for k, _ in pairs(ns.realmFilterPresets) do
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
              order = 40
            }
          }
        },
        flagPlayerGroup = {
          type = "group",
          name = L["Player Flag/Filter Options"],
          desc = L["Options for indicating or filtering out specific players"],
          disabled = true,
          args = {
            excludePlayerList = {
              type = "toggle",
              width = "full",
              descStyle = "inline",
              name = L["Inclusive/Exclusive Player List"],
              desc = L["InclusiveExclusivePlayer"],
              arg = "excludePlayerList",
              order = 1
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
              order = 10
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
              order = 20
            },
            flagPlayerList = {
              type = "multiselect",
              width = "full",
              descStyle = "inline",
              name = L["Players"],
              desc = L["Players selected below will be selected for filtering/flagging"],
              values = function()
                local rtnVal = {}
                for k, _ in pairs(db.flagPlayerList) do
                  rtnVal[k] = k
                end
                return rtnVal
              end,
              get = function(info, key)
                return db[info.arg][key]
              end,
              set = function(info, value)
                db[info.arg][value] = not db[info.arg][value]
                local newTbl = {}
                for k, v in pairs(db[info.arg]) do
                  if (k ~= value) or v then
                    newTbl[k] = v
                  end
                end
                db[info.arg] = newTbl
                LFMPlus:FilterChanged()
              end,
              arg = "flagPlayerList",
              order = 30
            }
          }
        }
      }
    }
  }
}

function LFMPlus:OnInitialize()
  ---@type defaults.global
  db = LibStub("AceDB-3.0"):New(ns.constants.friendlyName .. "DB", defaults, true).global

  -- Register options table and slash command
  LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(addonName, options, true)
  self:RegisterChatCommand(
    "lfm",
    function()
      LibStub("AceConfigDialog-3.0"):Open(addonName)
    end
  )

  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonName)
  InitializeUI()
  local function EventHandler(event, ...)
    if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
      local unitId = ...
      if unitId == "player" then
        LFMPlusFrame.activeRoleFrame:UpdateRoleIcon()
      end
    end

    if event == "LFG_LIST_APPLICANT_UPDATED" then
      local applicantID = ...
      if applicantID then
        local applicantInfo = C_LFGList.GetApplicantInfo(applicantID)
        if applicantInfo and (applicantInfo.applicationStatus ~= "applied") and (applicantInfo.applicationStatus ~= "invited") and (applicantInfo.applicationStatus ~= "inviteaccepted") then
          LFMPlus:RemoveApplicantId(applicantID)
        end
      end
    end

    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" or event == "GROUP_ROSTER_UPDATE" then
      if C_LFGList.HasActiveEntryInfo() then
        local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
        if activeEntryInfo then
          local _, _, _, _, _, _, _, _, _, _, _, _, isMythicPlusActivity = C_LFGList.GetActivityInfo(activeEntryInfo.activityID)
          if isMythicPlusActivity then
            LFMPlus.mPlusListed = true
            LFMPlus.mPlusSearch = false
            LFMPlus:ToggleFrames("app", "show")
          end
        else
          LFMPlus:ClearValues()
          LFMPlus:ToggleFrames("app", "hide")
        end
      else
        LFMPlus:ClearValues()
        LFMPlus:ToggleFrames("app", "hide")
      end
      LFMPlus.isLeader = UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME)
    end
    -- QueueStatusMinimapButton_SetGlowLock(self, lock, enabled, numPingSounds)

    if event == "PARTY_LEADER_CHANGED" then
      LFMPlus.isLeader = UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME)
    end
    if event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
      local id = ...
      if (LFGListFrame.SearchPanel.selectedResult == id) then
        LFGListSearchPanel_ValidateSelected(LFGListFrame.SearchPanel)
        if (LFGListFrame.SearchPanel.selectedResult ~= id) then
          L_LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel)
        end
      end
    end
  end

  -- Register Events
  for k, v in pairs(ns.constants.trackedEvents) do
    if v then
      LFMPlus:RegisterEvent(k, EventHandler)
    end
  end
  for k, v in pairs(LFMPlusFrame.frames.search) do
    LFMPlusFrame.frames.all[k] = v
  end

  for k, v in pairs(LFMPlusFrame.frames.app) do
    LFMPlusFrame.frames.all[k] = v
  end

  if db.enabled then
    LFMPlus:Enable()
  end
end

function LFMPlus:ClearValues()
  LFMPlus.mPlusSearch = false
  LFMPlus.mPlusListed = false
  LFMPlus.newEligibleApplicant = false
  LFMPlus.eligibleApplicantList = {}

  LFMPlusFrame.exemptIDs = {}
  LFMPlusFrame.declineButtonInfo = {}
  LFMPlusFrame.filteredIDs = {}
  LFMPlusFrame.results = {}
  LFMPlusFrame.totalResults = 0

  LFMPlusFrame.nextAppDecline = nil
  -- Dropdown Mode
  LFMPlusFrame.DD.m = 3
end

function LFMPlus:ToggleFrames(frame, action)
  if db.enabled and action == "show" then
    LFMPlusFrame:Show()
    LFMPlusFrame.activeRoleFrame:UpdateRoleIcon()

    for k, _ in pairs(LFMPlusFrame.frames[frame]) do
      LFMPlusFrame[k]:Show()
    end
    LFMPlusFrame:Layout()
    LibDD:UIDropDownMenu_Initialize(LFMPlusFrame.DD, LFMPlusFrame.DD.LFMPlusDD_Initialize)
    self:FilterChanged()
  end

  if action == "hide" then
    LFMPlusFrame:Hide()
    LFMPlus:ClearValues()
    for k, _ in pairs(LFMPlusFrame.frames.all) do
      LFMPlusFrame[k]:Hide()
    end
  end
end

function LFMPlus:RunHooks()
  if not ns.InitHooksRan then
    --hooksecurefunc("LFGListUtil_SortSearchResults", SortSearchResults)
    --hooksecurefunc("LFGListSearchEntry_Update", SearchEntryUpdate)
    --hooksecurefunc("LFGListSearchPanel_UpdateResultList", L_LFGListSearchPanel_UpdateResultList)
    hooksecurefunc("LFGListSearchPanel_UpdateResults", L_LFGListSearchPanel_UpdateResults)
    --hooksecurefunc("LFGListUtil_SortApplicants", SortApplicants)
    --hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", UpdateApplicantMember)
    -- hooksecurefunc("QueueStatusMinimapButton_SetGlowLock",CheckForPings)
    ns.InitHooksRan = true
  end
end

function LFMPlus:Enable()
  if not ns.SecondHookRan then
    -- Hooks for frames that may not exist when the addon done loading so we hook into a frame that should be available and run these hooks once its shown.
    LFMPlus:HookScript(
      PVEFrame,
      "OnShow",
      function()
        for i = 1, 10, 1 do
          local f = CreateFrame("Button", "LFMPlusSearchEntryButton" .. i, LFGListFrame.SearchPanel.ScrollFrame.ScrollChild, "LFGListSearchEntryTemplate")
          f.idx = i

          f:SetPoint("TOPLEFT", LFGListFrame.SearchPanel.ScrollFrame.buttons[i])
          f:SetPoint("BOTTOMRIGHT", LFGListFrame.SearchPanel.ScrollFrame.buttons[i])

          f:SetScript("OnClick", L_LFGListSearchEntry_OnClick)
          f:SetScript("OnEnter", L_LFGListSearchEntry_OnEnter)
          f:SetScript(
            "OnDoubleClick",
            function()
              LFGListApplicationDialog_Show(LFGListApplicationDialog, LFMPlusFrame.selectedResult)
            end
          )
          f:SetScript(
            "OnEvent",
            function(s, event, ...)
              if (event == "LFG_LIST_SEARCH_RESULT_UPDATED") then
                local id = ...
                if (id == s.resultID) then
                  SearchEntryUpdate(s)
                end
              elseif (event == "LFG_ROLE_CHECK_UPDATE") then
                if (s.resultID) then
                  SearchEntryUpdate(s)
                end
              end
            end
          )

          f:Hide()
          LFMPlusFrame.buttons[#LFMPlusFrame.buttons + 1] = f
          -- Hide the old button frame as we wont be using it.
          LFGListFrame.SearchPanel.ScrollFrame.buttons[i]:HookScript(
            "OnShow",
            function(s)
              if LFGListFrame.CategorySelection.selectedCategory == 2 then
                s:Hide()
              end
            end
          )
        end

        --[[         LFMPlus:HookScript(
          LFGListFrame.SearchPanel,
          "OnShow",
          function(s)
            if LFGListFrame.CategorySelection.selectedCategory == 2 then
              LFMPlusFrame.DD.m = 1
              LFMPlus:ToggleFrames("search", "show")
            end
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.SearchPanel,
          "OnHide",
          function(s)
            if LFGListFrame.CategorySelection.selectedCategory == 2 then
              LFMPlusFrame.DD.m = 3
              LFMPlus:ToggleFrames("search", "hide")
            end
          end
        ) ]]
        --[[         LFMPlus:HookScript(
          LFGListFrame.ApplicationViewer,
          "OnShow",
          function(s)
            LFMPlusFrame.DD.m = 2
            if LFMPlus.mPlusListed then
              LFMPlus:ToggleFrames("app", "show")
            end
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.ApplicationViewer,
          "OnHide",
          function()
            LFMPlus:ToggleFrames("app", "hide")
          end
        ) ]]
        LFMPlus:HookScript(
          LFGListFrame.CategorySelection.FindGroupButton,
          "OnClick",
          function(s)
            LFMPlus.mPlusSearch = LFGListFrame.CategorySelection.selectedCategory == 2
            LFMPlus:ToggleFrames("search", "show")
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.SearchPanel.BackButton,
          "OnClick",
          function(s)
            LFMPlus.mPlusSearch = false
            LFMPlus:ToggleFrames("search", "hide")
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.EntryCreation.ListGroupButton,
          "OnClick",
          function()
            LFMPlus.mPlusListed = true
            LFMPlus:ToggleFrames("app", "show")
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.ApplicationViewer.RemoveEntryButton,
          "OnClick",
          function()
            LFMPlus.mPlusListed = false
            LFMPlus:ToggleFrames("app", "hide")
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.ApplicationViewer.BrowseGroupsButton,
          "OnClick",
          function()
            LFMPlus.mPlusListed = false
            LFMPlus:ToggleFrames("app", "hide")
            LFMPlus.mPlusSearch = true
            LFMPlus:ToggleFrames("search", "show")
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.SearchPanel.BackToGroupButton,
          "OnClick",
          function()
            LFMPlus.mPlusSearch = false
            LFMPlus:ToggleFrames("search", "hide")
            LFMPlus.mPlusListed = true
            LFMPlus:ToggleFrames("app", "show")
          end
        )

        for _, v in pairs(LFGListFrame.CategorySelection.CategoryButtons) do
          v:HookScript(
            "OnDoubleClick",
            function()
              if IsShiftKeyDown() then
                LFGListFrame.CategorySelection.StartGroupButton:Click()
              else
                LFGListFrame.CategorySelection.FindGroupButton:Click()
              end
            end
          )
        end

        LFMPlus:HookScript(
          LFGListApplicationDialogDescription.EditBox,
          "OnShow",
          function()
            if db.autoFocusSignUp then
              LFGListApplicationDialogDescription.EditBox:SetFocus()
            end
          end
        )

        LFMPlus:HookScript(
          LFGListApplicationDialogDescription.EditBox,
          "OnEnterPressed",
          function()
            if db.signupOnEnter then
              LFGListApplicationDialog.SignUpButton:Click()
            end
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.ApplicationViewer.UnempoweredCover,
          "OnShow",
          function()
            if db.hideAppViewerOverlay then
              LFGListFrame.ApplicationViewer.UnempoweredCover:Hide()
            end
          end
        )
        LFMPlus:Unhook(PVEFrame, "OnShow")
        ns.SecondHookRan = true
      end
    )
  end
  LFMPlus:RunHooks()
  ns.Init = true
end

function LFMPlus:Disable()
  db.enabled = false
end
