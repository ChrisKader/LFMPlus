---@type string
local addonName, ---@type ns
  ns = ...

local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local LFMPlus = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

---@class LFMPlusFrame:Frame
---@field Layout function Layout child in the frame.
local LFMPlusFrame = CreateFrame("Frame", "LFMPlusFrame", GroupFinderFrame, "ManagedHorizontalLayoutFrameTemplate")

LFMPlusFrame.buttons = {}
LFMPlusFrame.classList = {}
LFMPlusFrame.classListLoaded = false
LFMPlusFrame.declineButtonInfo = {}
LFMPlusFrame.dungeonList = {}
LFMPlusFrame.dungeonListLoaded = false
LFMPlusFrame.exemptIDs = {}
LFMPlusFrame.expand = true
LFMPlusFrame.filteredIDs = {}
LFMPlusFrame.fixedHeight = 50
LFMPlusFrame.frames = {search = {}, app = {}, all = {}}
LFMPlusFrame.nextAppDecline = nil
LFMPlusFrame.results = {}
LFMPlusFrame.selectedResult = nil
LFMPlusFrame.spacing = 5
LFMPlusFrame.totalResults = 0

LFMPlusFrame:RegisterEvent("ADDON_LOADED")

local L = LibStub("AceLocale-3.0"):GetLocale(addonName, false)

local COLOR_RESET = "|r"
local COLOR_GRAY = "|cffbbbbbb"
local COLOR_ORANGE = "|cffffaa66"

function LFMPlus_GetPlaystyleString(playstyle,activityInfo)
  if activityInfo and playstyle ~= (0 or nil) and C_LFGList.GetLfgCategoryInfo(activityInfo.categoryID).showPlaystyleDropdown then
    local typeStr
    if activityInfo.isMythicPlusActivity then
      typeStr = "GROUP_FINDER_PVE_PLAYSTYLE"
    elseif activityInfo.isRatedPvpActivity then
      typeStr = "GROUP_FINDER_PVP_PLAYSTYLE"
    elseif activityInfo.isCurrentRaidActivity then
      typeStr = "GROUP_FINDER_PVE_RAID_PLAYSTYLE"
    elseif activityInfo.isMythicActivity then
      typeStr = "GROUP_FINDER_PVE_MYTHICZERO_PLAYSTYLE"
    end
    return typeStr and _G[typeStr .. tostring(playstyle)] or nil
  else
    return nil
  end
end

--There is no reason to do this api func protected, but they do.
C_LFGList.GetPlaystyleString = function(playstyle,activityInfo)
  return LFMPlus_GetPlaystyleString(playstyle, activityInfo)
end

--Protected func, not completable with addons. No name when creating activity without authenticator now.
function LFGListEntryCreation_SetTitleFromActivityInfo(_)
end

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

function LFMPlus:FindFilteredId(id,frame)
  for i = 1, #LFMPlusFrame.filteredIDs do
    if frame.filteredIDs[i] == id then
      return i
    end
  end
  return nil
end

function LFMPlus:removeFilteredId(id)
  local idLoc = LFMPlus:FindFilteredId(id, LFMPlusFrame)

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

function LFMPlus:addFilteredId(s,id)
  if (not s.filteredIDs) then
    s.filteredIDs = {}
  end
  if not LFMPlus:FindFilteredId(id, LFMPlusFrame) then
    tinsert(s.filteredIDs, id)
  end
end

function LFMPlus:filterTable(results,idsToFilter)
  LFMPlusFrame.filteredIDs = {}
  for _, id in ipairs(idsToFilter) do
    for j = #results, 1, -1 do
      if (results[j] == id) then
        tremove(results, j)
        tinsert(LFMPlusFrame.filteredIDs, id)
        table.sort(
          LFMPlusFrame.filteredIDs,
          function(a,b)
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

function LFMPlus:AddToFilter(name,realm)
  if not db.flagPlayerList[name .. "-" .. realm] then
    db.flagPlayerList[name .. "-" .. realm] = true
  end
end

function LFMPlus:GetNameRealm(unit,tempRealm)
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
      if LFGListFrame.SearchPanel:IsShown() then
        LFGListFrame.SearchPanel.RefreshButton:Click()
      end
    elseif LFGListFrame.ApplicationViewer:IsShown() then
      LFGListFrame.ApplicationViewer.RefreshButton:Click()
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

ns.DebugLog = function(text,type)
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
ns.FrameHooksRan = false
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

local getIndex = function(values,val)
  local index = {}
  for k, v in pairs(values) do
    index[v] = k
  end
  return index[val]
end

ns.DEBUG_ENABLED = false

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

function LFMPlus:GetTooltipInfo(resultID)
  local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
  local activityID = searchResultInfo.activityID
  if not activityID then
    return nil
  end
  local numMembers = searchResultInfo.numMembers
  local playStyle = searchResultInfo.playstyle
  local numBNetFriends = searchResultInfo.numBNetFriends
  local numCharFriends = searchResultInfo.numCharFriends
  local numGuildMates = searchResultInfo.numGuildMates
  local questID = searchResultInfo.questID
  local activityInfo = C_LFGList.GetActivityInfoTable(activityID, questID, searchResultInfo.isWarMode)

  local classCounts = {}
  local memberList = {}

  for i = 1, numMembers do
    local role, class, classLocalized = C_LFGList.GetSearchResultMemberInfo(resultID, i)
    local info = {
      role = _G[role],
      title = classLocalized,
      color = RAID_CLASS_COLORS[class] or NORMAL_FONT_COLOR
    }

    table.insert(memberList, info)

    if not classCounts[class] then
      classCounts[class] = {
        title = info.title,
        color = info.color,
        counts = {}
      }
    end

    if not classCounts[class].counts[info.role] then
      classCounts[class].counts[info.role] = 0
    end

    classCounts[class].counts[info.role] = classCounts[class].counts[info.role] + 1
  end

  local friendList = {}
  if numBNetFriends + numCharFriends + numGuildMates > 0 then
    friendList = LFGListSearchEntryUtil_GetFriendList(resultID)
  end

  return {
    memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID),
    completedEncounters = C_LFGList.GetSearchResultEncounterInfo(resultID),
    autoAccept = searchResultInfo.autoAccept,
    isDelisted = searchResultInfo.isDelisted,
    name = searchResultInfo.name,
    comment = searchResultInfo.comment,
    iLvl = searchResultInfo.requiredItemLevel,
    HonorLevel = searchResultInfo.requiredHonorLevel,
    DungeonScore = searchResultInfo.requiredDungeonScore,
    PvpRating = searchResultInfo.requiredPvpRating,
    voiceChat = searchResultInfo.voiceChat,
    leaderName = searchResultInfo.leaderName,
    age = searchResultInfo.age,
    leaderOverallDungeonScore = searchResultInfo.leaderOverallDungeonScore,
    leaderDungeonScoreInfo = searchResultInfo.leaderDungeonScoreInfo,
    leaderPvpRatingInfo = searchResultInfo.leaderPvpRatingInfo,
    playStyle = playStyle,
    questID = questID,
    activityID = activityID,
    numMembers = numMembers,
    classCounts = classCounts,
    friendList = friendList,
    activityName = activityInfo.fullName,
    useHonorLevel = activityInfo.useHonorLevel,
    displayType = activityInfo.displayType,
    isMythicPlusActivity = activityInfo.isMythicPlusActivity,
    isRatedPvpActivity = activityInfo.isRatedPvpActivity,
    playstyleString = LFMPlus_GetPlaystyleString(playStyle, activityInfo)
  }
end

local function LFGListSearchPanel_UpdateAdditionalButtons(self,totalHeight,showNoResults,showStartGroup,lastVisibleButton)
  local startGroupButton = self.ScrollFrame.ScrollChild.StartGroupButton
  local noResultsFound = self.ScrollFrame.ScrollChild.NoResultsFound

  noResultsFound:SetShown(showNoResults)
  startGroupButton:SetShown(showStartGroup)
  local topFrame, bottomFrame

  if showNoResults then
    noResultsFound:ClearAllPoints()
    topFrame = noResultsFound
    bottomFrame = noResultsFound

    if lastVisibleButton then
      noResultsFound:SetPoint("TOP", lastVisibleButton, "BOTTOM", 0, -10)
    else
      noResultsFound:SetPoint("TOP", self.ScrollFrame.ScrollChild, "TOP", 0, -27)
    end
  end

  if showStartGroup then
    startGroupButton:ClearAllPoints()

    bottomFrame = startGroupButton
    if not topFrame then
      topFrame = startGroupButton
    end

    if showNoResults then
      startGroupButton:SetPoint("TOP", noResultsFound, "BOTTOM", 0, -5)
    elseif lastVisibleButton then
      startGroupButton:SetPoint("TOP", lastVisibleButton, "BOTTOM", 0, -10)
    else
      startGroupButton:SetPoint("TOP", self.ScrollFrame.ScrollChild, "TOP", 0, -27)
    end

    noResultsFound:SetText(showStartGroup and LFG_LIST_NO_RESULTS_FOUND or LFG_LIST_SEARCH_FAILED)
  end

  if topFrame and bottomFrame then
    local _, _, _, _, offsetY = topFrame:GetPoint(1)
    totalHeight = totalHeight - offsetY + (topFrame:GetTop() - bottomFrame:GetBottom())
  end

  return totalHeight
end

function LFMPlus:SearchEntry_OnEnter(s)
  local info = LFMPlus:GetTooltipInfo(s.resultID)

  -- setup tooltip
  GameTooltip:SetOwner(s, "ANCHOR_RIGHT", 25, 0)
  GameTooltip:SetText(info.name, 1, 1, 1, true)
  GameTooltip:AddLine(info.activityName)

  if info.playStyle > 0 and info.playstyleString then
    GameTooltip_AddColoredLine(GameTooltip, info.playstyleString, GREEN_FONT_COLOR)
  end

  if info.comment and info.comment == "" and info.questID then
    info.comment = LFGListUtil_GetQuestDescription(info.questID)
  end
  if info.comment ~= "" then
    GameTooltip:AddLine(string.format(LFG_LIST_COMMENT_FORMAT, info.comment), GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true)
  end
  GameTooltip:AddLine(" ")
  if info.DungeonScore > 0 then
    GameTooltip:AddLine(GROUP_FINDER_MYTHIC_RATING_REQ_TOOLTIP:format(info.DungeonScore))
  end
  if info.PvpRating > 0 then
    GameTooltip:AddLine(GROUP_FINDER_PVP_RATING_REQ_TOOLTIP:format(info.PvpRating))
  end
  if info.iLvl > 0 then
    GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_ILVL, info.iLvl))
  end
  if info.useHonorLevel and info.HonorLevel > 0 then
    GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_HONOR_LEVEL, info.HonorLevel))
  end
  if info.voiceChat ~= "" then
    GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_VOICE_CHAT, info.voiceChat), nil, nil, nil, true)
  end
  if info.iLvl > 0 or (info.useHonorLevel and info.HonorLevel > 0) or info.voiceChat ~= "" or info.DungeonScore > 0 or info.PvpRating > 0 then
    GameTooltip:AddLine(" ")
  end

  if info.leaderName then
    GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_LEADER, info.leaderName))
  end
  if info.isRatedPvpActivity and info.leaderPvpRatingInfo then
    GameTooltip_AddNormalLine(GameTooltip, PVP_RATING_GROUP_FINDER:format(info.leaderPvpRatingInfo.activityName, info.leaderPvpRatingInfo.rating, PVPUtil.GetTierName(info.leaderPvpRatingInfo.tier)))
  elseif info.isMythicPlusActivity and info.leaderOverallDungeonScore then
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(info.leaderOverallDungeonScore)
    if not color then
      color = HIGHLIGHT_FONT_COLOR
    end
    GameTooltip:AddLine(DUNGEON_SCORE_LEADER:format(color:WrapTextInColorCode(info.leaderOverallDungeonScore)))
  end
  if info.isMythicPlusActivity and info.leaderDungeonScoreInfo then
    local leaderDungeonScoreInfo = info.leaderDungeonScoreInfo
    local color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(leaderDungeonScoreInfo.mapScore)
    if not color then
      color = HIGHLIGHT_FONT_COLOR
    end
    if leaderDungeonScoreInfo.mapScore == 0 then
      GameTooltip_AddNormalLine(GameTooltip, DUNGEON_SCORE_PER_DUNGEON_NO_RATING:format(leaderDungeonScoreInfo.mapName, leaderDungeonScoreInfo.mapScore))
    elseif leaderDungeonScoreInfo.finishedSuccess then
      GameTooltip_AddNormalLine(GameTooltip, DUNGEON_SCORE_DUNGEON_RATING:format(leaderDungeonScoreInfo.mapName, color:WrapTextInColorCode(leaderDungeonScoreInfo.mapScore), leaderDungeonScoreInfo.bestRunLevel))
    else
      GameTooltip_AddNormalLine(GameTooltip, DUNGEON_SCORE_DUNGEON_RATING_OVERTIME:format(leaderDungeonScoreInfo.mapName, color:WrapTextInColorCode(leaderDungeonScoreInfo.mapScore), leaderDungeonScoreInfo.bestRunLevel))
    end
  end
  if info.age > 0 then
    GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_AGE, SecondsToTime(info.age, false, false, 1, false)))
  end

  if info.leaderName or info.age > 0 then
    GameTooltip:AddLine(" ")
  end

  if info.displayType == LE_LFG_LIST_DISPLAY_TYPE_CLASS_ENUMERATE then
    GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_MEMBERS_SIMPLE, info.numMembers))

    if info.memberList then
      for _, memberInfo in pairs(info.memberList) do
        GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_CLASS_ROLE, memberInfo.title, memberInfo.role), memberInfo.color.r, memberInfo.color.g, memberInfo.color.b)
      end
    end
  else
    GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_MEMBERS, info.numMembers, info.memberCounts.TANK, info.memberCounts.HEALER, info.memberCounts.DAMAGER))

    for _, classInfo in pairs(info.classCounts) do
      local counts = {}
      for role, count in pairs(classInfo.counts) do
        table.insert(counts, COLOR_GRAY .. role .. ": " .. COLOR_ORANGE .. count .. COLOR_RESET)
      end
      GameTooltip:AddLine(string.format("%s (%s)", classInfo.title, table.concat(counts, ", ")), classInfo.color.r, classInfo.color.g, classInfo.color.b)
    end
  end

  if #info.friendList > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP)
    GameTooltip:AddLine(info.friendList, 1, 1, 1, true)
  end

  if info.completedEncounters and #info.completedEncounters > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LFG_LIST_BOSSES_DEFEATED)
    for i = 1, #info.completedEncounters do
      GameTooltip:AddLine(info.completedEncounters[i], RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    end
  end

  local autoAcceptOption = nil or LFG_LIST_UTIL_ALLOW_AUTO_ACCEPT_LINE
  if autoAcceptOption == LFG_LIST_UTIL_ALLOW_AUTO_ACCEPT_LINE and info.autoAccept then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LFG_LIST_TOOLTIP_AUTO_ACCEPT, LIGHTBLUE_FONT_COLOR:GetRGB())
  end

  if info.isDelisted then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LFG_LIST_ENTRY_DELISTED, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
  end

  GameTooltip:Show()
end

function LFGListSearchEntry_OnEnter(self)
  LFMPlus:SearchEntry_OnEnter(self)
end

function LFGListSearchEntry_Update(self)
  local resultID = self.resultID
  local _, appStatus, pendingStatus, appDuration = C_LFGList.GetApplicationInfo(resultID)
  local isApplication = (appStatus ~= "none" or pendingStatus)
  local isAppFinished = LFGListUtil_IsStatusInactive(appStatus) or LFGListUtil_IsStatusInactive(pendingStatus)
  self.DataDisplay:ClearAllPoints()
  self.DataDisplay:SetPoint("RIGHT",0,-1)
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

  if pendingStatus == "applied" and C_LFGList.GetRoleCheckInfo() then
    self.PendingLabel:SetText(LFG_LIST_ROLE_CHECK)
    self.PendingLabel:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif pendingStatus == "cancelled" or appStatus == "cancelled" or appStatus == "failed" then
    self.PendingLabel:SetText(LFG_LIST_APP_CANCELLED)
    self.PendingLabel:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif appStatus == "declined" or appStatus == "declined_full" or appStatus == "declined_delisted" then
    self.PendingLabel:SetText((appStatus == "declined_full") and LFG_LIST_APP_FULL or LFG_LIST_APP_DECLINED)
    self.PendingLabel:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif appStatus == "timedout" then
    self.PendingLabel:SetText(LFG_LIST_APP_TIMED_OUT)
    self.PendingLabel:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif appStatus == "invited" then
    self.PendingLabel:SetText(LFG_LIST_APP_INVITED)
    self.PendingLabel:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif appStatus == "inviteaccepted" then
    self.PendingLabel:SetText(LFG_LIST_APP_INVITE_ACCEPTED)
    self.PendingLabel:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif appStatus == "invitedeclined" then
    self.PendingLabel:SetText(LFG_LIST_APP_INVITE_DECLINED)
    self.PendingLabel:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  elseif isApplication and pendingStatus ~= "applied" then
    self.PendingLabel:SetText(LFG_LIST_PENDING)
    self.PendingLabel:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    self.PendingLabel:Show()
    self.ExpirationTime:Show()
    self.CancelButton:Show()
  else
    self.PendingLabel:Hide()
    self.ExpirationTime:Hide()
    self.CancelButton:Hide()
  end
  self.ExpirationTime:ClearAllPoints()
  self.ExpirationTime:SetPoint("RIGHT", -35, -1)
  --Center justify if we're on more than one line
  if self.PendingLabel:GetHeight() > 15 then
    self.PendingLabel:SetJustifyH("CENTER")
  else
    self.PendingLabel:SetJustifyH("RIGHT")
  end

  --Change the anchor of the label depending on whether we have the expiration time
  if self.ExpirationTime:IsShown() then
    self.PendingLabel:SetPoint("RIGHT", self.ExpirationTime, "LEFT", -3, 0)
  else
    self.PendingLabel:SetPoint("RIGHT", self.ExpirationTime, "RIGHT", -3, 0)
  end

  self.expiration = GetTime() + appDuration

  local panel = self:GetParent():GetParent():GetParent()

  local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
  local activityID = searchResultInfo.activityID
  local name = searchResultInfo.name
  local voiceChat = searchResultInfo.voiceChat
  local isDelisted = searchResultInfo.isDelisted
  local activityName = C_LFGList.GetActivityFullName(activityID, nil, searchResultInfo.isWarMode)
  local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID, nil, searchResultInfo.isWarMode)
  --self.infoName = PremadeFilter_GetInfoName(activityID, name)
  self.resultID = resultID
  self.Selected:SetShown(panel.selectedResult == resultID and not isApplication and not isDelisted)
  self.Highlight:SetShown(panel.selectedResult ~= resultID and not isApplication and not isDelisted)
  local nameColor = NORMAL_FONT_COLOR
  local activityColor = GRAY_FONT_COLOR
  if isDelisted or isAppFinished then
    nameColor = LFG_LIST_DELISTED_FONT_COLOR
    activityColor = LFG_LIST_DELISTED_FONT_COLOR
  elseif searchResultInfo.numBNetFriends > 0 or searchResultInfo.numCharFriends > 0 or searchResultInfo.numGuildMates > 0 then
    nameColor = BATTLENET_FONT_COLOR
  elseif self.fresh then
    nameColor = LFG_LIST_FRESH_FONT_COLOR
  end

  self.Name:SetWidth(0)

  self.Name:SetText(name)
  self.Name:SetTextColor(nameColor.r, nameColor.g, nameColor.b)
  self.ActivityName:SetText(activityName)
  self.ActivityName:SetTextColor(activityColor.r, activityColor.g, activityColor.b)
  self.VoiceChat:SetShown(voiceChat ~= "")
  self.VoiceChat.tooltip = voiceChat

  local displayData = C_LFGList.GetSearchResultMemberCounts(resultID)
  LFGListGroupDataDisplay_Update(self.DataDisplay, activityID, displayData, isDelisted)

  local nameWidth = isApplication and 165 or 176
  if voiceChat ~= "" then
    nameWidth = nameWidth - 22
  end
  if self.Name:GetWidth() > nameWidth then
    self.Name:SetWidth(nameWidth)
  end
  self.ActivityName:SetWidth(nameWidth)

  local mouseFocus = GetMouseFocus()
  if mouseFocus == self then
    LFGListSearchEntry_OnEnter(self)
  end
  if mouseFocus == self.VoiceChat then
    mouseFocus:GetScript("OnEnter")(mouseFocus)
  end

  if isApplication then
    self:SetScript("OnUpdate", LFGListSearchEntry_UpdateExpiration)
    LFGListSearchEntry_UpdateExpiration(self)
  else
    self:SetScript("OnUpdate", nil)
  end

  if self.DataDisplay.Enumerate.leader then
    self.DataDisplay.Enumerate.leader:Hide()
  end

  for i = 1, 5 do
    local icon = self.DataDisplay.Enumerate["Icon" .. i]
    if (icon) then
      for _, v in ipairs(ns.constants.searchEntryFrames) do
        if icon[v] then
          icon[v]:Hide()
        end
      end
    end
  end

  if db.enabled and activityInfo.isMythicPlusActivity then
    local playstyleString = GREEN_FONT_COLOR:WrapTextInColorCode(ns.constants.playStyleString[searchResultInfo.playstyle] or "")
    local numMembers = searchResultInfo.numMembers
    local orderIndexes = {}

    self.ExpirationTime:ClearAllPoints()
    self.ExpirationTime:SetPoint("BOTTOMRIGHT", self.DataDisplay.Enumerate.Icon5, "BOTTOMLEFT", 0, 0)
    self.ExpirationTime:SetJustifyH("RIGHT")
    if (self.ExpirationTime:IsShown()) then
      self.PendingLabel:SetText("")
    end

    if isApplication then
      self:SetScript("OnUpdate", UpdateExpiration)
      UpdateExpiration(self)
    else
      self:SetScript("OnUpdate", nil)
    end

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
      function(a,b)
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
  end
end

function LFGListSearchPanel_UpdateResults(self)
  local offset = HybridScrollFrame_GetOffset(self.ScrollFrame)
  local buttons = self.ScrollFrame.buttons

  --If we have an application selected, deselect it.
  LFGListSearchPanel_ValidateSelected(self)

  local startGroupButton = self.ScrollFrame.ScrollChild.StartGroupButton
  local noResultsFound = self.ScrollFrame.ScrollChild.NoResultsFound

  if self.searching then
    self.SearchingSpinner:Show()
    noResultsFound:Hide()
    startGroupButton:Hide()
    for i = 1, #buttons do
      buttons[i]:Hide()
    end
  else
    self.SearchingSpinner:Hide()
    local results = self.results
    --local apps = self.applications
    local lastVisibleButton
    for i = 1, #buttons do
      local button = buttons[i]
      local idx = i + offset
      local result = results[idx] --(idx <= #apps) and apps[idx] or results[idx - #apps]
      if result then
        --local searchResultInfo = C_LFGList.GetSearchResultInfo(result)
        button.resultID = result
        LFGListSearchEntry_Update(button)
        button:Show()
        lastVisibleButton = button
      else
        button.created = 0
        button.resultID = nil
        button.infoName = nil
        button:Hide()
      end
      button:SetScript("OnEnter", LFGListSearchEntry_OnEnter)
    end
    local totalHeight = buttons[1]:GetHeight() * #results --(#results + #apps)
    local showNoResults = (self.totalResults == 0)
    local showStartGroup = ((self.totalResults == 0) or self.shouldAlwaysShowCreateGroupButton) and not self.searchFailed
    totalHeight = LFGListSearchPanel_UpdateAdditionalButtons(self, totalHeight, showNoResults, showStartGroup, lastVisibleButton)
    HybridScrollFrame_Update(self.ScrollFrame, totalHeight, self.ScrollFrame:GetHeight())
  end
  LFGListSearchPanel_UpdateButtonStatus(self)
end

function LFGListSearchPanel_UpdateResultList(self)
  if not self.searching then
    self.totalResults, self.results = C_LFGList.GetFilteredSearchResults()
    self.applications = C_LFGList.GetApplications()

    local numResults = 0

    local newResults = {}

    local minAge = nil

    local roleRemainingKeyLookup = {
      ["TANK"] = "TANK_REMAINING",
      ["HEALER"] = "HEALER_REMAINING",
      ["DAMAGER"] = "DAMAGER_REMAINING"
    }

    for i = 1, #self.results do
      local resultID = self.results[i]

      local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)

      local age = searchResultInfo.age
      local activityID = searchResultInfo.activityID
      local leaderName, realmName = LFMPlus:GetNameRealm(searchResultInfo.leaderName)

      local activityInfoTable = C_LFGList.GetActivityInfoTable(activityID, nil, searchResultInfo.isWarMode)
      local memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID)
      local playerRole = GetSpecializationRole(GetSpecialization())
      local friendsOrGuild = (searchResultInfo.numBNetFriends or 0) + (searchResultInfo.numCharFriends or 0) + (searchResultInfo.numGuildMates or 0)
      if not minAge or (age < minAge) then
        minAge = age
      end

      local matches = true
      if db.enabled and LFGListFrame.CategorySelection.selectedCategory == 2 then
        if matches and db.activeRoleFilter then
          matches = memberCounts[roleRemainingKeyLookup[playerRole]] > 0
        end

        if matches and db.ratingFilter then
          matches = ((searchResultInfo.leaderOverallDungeonScore or 0) >= db.ratingFilterMin)
        end

        if matches and db.filterRealm then
          matches = LFMPlus:checkRealm(realmName)
        end

        if matches and db.filterPlayer then
          matches = LFMPlus:checkPlayer(leaderName)
        end

        if matches and db.dungeonFilter then
          matches = (LFMPlusFrame.dungeonList[searchResultInfo.activityID] and LFMPlusFrame.dungeonList[searchResultInfo.activityID].checked or false)
        end

        if matches and db.ratingFilter then
          matches = activityInfoTable.isMythicPlusActivity
        end

        if not matches and db.alwaysShowFriends then
          matches = friendsOrGuild > 0
        end
      end
      --[[ -- bosses
        if matches and extraFilters.bosses then
          local completedEncounters = C_LFGList.GetSearchResultEncounterInfo(resultID)
          local bossesDefeated = {}

          if type(completedEncounters) == "table" then
            for i = 1, #completedEncounters do
              local boss = completedEncounters[i]
              local shortName = boss:match("^([^%,%-%s]+)")
              bossesDefeated[shortName] = true
            end
          end

          for boss, filterStatus in pairs(extraFilters.bosses) do
            local shortName = boss:match("^([^%,%-%s]+)")
            local bossStatus = (type(bossesDefeated[shortName]) == "nil")
            if bossStatus ~= filterStatus then
              matches = false
              break
            end
          end
        end ]]
      if matches then
        numResults = numResults + 1
        newResults[numResults] = resultID
      end
    end

    self.totalResults = numResults
    self.results = newResults

    LFGListUtil_SortSearchResults(self.results)
  end
  LFGListSearchPanel_UpdateResults(self)
end

function LFGListSearchPanel_DoSearch(self)
  local languages = C_LFGList.GetLanguageSearchFilter()

  if LFGListFrame.SearchPanel.ScrollFrame:IsVisible() then
    HybridScrollFrame_ScrollToIndex(
      LFGListFrame.SearchPanel.ScrollFrame,
      1,
      function(_)
        return LFGListFrame.SearchPanel.ScrollFrame.buttons[1]:GetHeight()
      end
    )
  end
  C_LFGList.Search(self.categoryID, self.filters, self.preferredFilters, languages)

  self.searching = true
  self.searchFailed = false
  self.selectedResult = nil

  LFGListSearchPanel_UpdateResultList(self)
end

function LFGListUtil_SortSearchResultsCB(id1,id2)
  local searchResultInfo1 = C_LFGList.GetSearchResultInfo(id1)
  local searchResultInfo2 = C_LFGList.GetSearchResultInfo(id2)

  local _, appStatus1, pendingStatus1, appDuration1 = C_LFGList.GetApplicationInfo(id1)
  local _, appStatus2, pendingStatus2, appDuration2 = C_LFGList.GetApplicationInfo(id2)
  local isApplication1, isApplication2 = (appStatus1 ~= "none" or pendingStatus1), (appStatus2 ~= "none" or pendingStatus2)
  --local isAppFinished1, isAppFinished2 = LFGListUtil_IsStatusInactive(appStatus1) or LFGListUtil_IsStatusInactive(pendingStatus1), LFGListUtil_IsStatusInactive(appStatus2) or LFGListUtil_IsStatusInactive(pendingStatus2)

  if (isApplication1 or isApplication2) then
    if (isApplication1 and isApplication2) then
      return appDuration1 > appDuration2
    end
    if (isApplication1) then
      return true
    end

    if (isApplication2) then
      return false
    end
  end
  --Not used
  --[[ 	local sr_id1 = searchResultInfo1.searchResultID
  local sr_id2 = searchResultInfo2.searchResultID
  local activityID1 = searchResultInfo1.activityID
  local activityID2 = searchResultInfo2.activityID
  local leaderName1 = searchResultInfo1.leaderName
  local leaderName2 = searchResultInfo2.leaderName
  local name1 = searchResultInfo1.name
  local name2 = searchResultInfo2.name
  local comment1 = searchResultInfo1.comment
  local comment2 = searchResultInfo2.comment
  local iLvl1 = searchResultInfo1.requiredItemLevel
  local iLvl2 = searchResultInfo2.requiredItemLevel
  local honorLevel1 = searchResultInfo1.requiredHonorLevel
  local honorLevel2 = searchResultInfo2.requiredHonorLevel
  local voiceChat1 = searchResultInfo1.voiceChat
  local voiceChat2 = searchResultInfo2.voiceChat
  local numFriends1 = searchResultInfo1.numMembers
  local numFriends2 = searchResultInfo2.numMembers
  local questID1 = searchResultInfo1.questID
  local questID2 = searchResultInfo2.questID
  local autoAccept1 = searchResultInfo1.autoAccept
  local autoAccept2 = searchResultInfo2.autoAccept
  local isDelisted1 = searchResultInfo1.isDelisted
  local isDelisted2 = searchResultInfo2.isDelisted ]]
  local leaderOverallDungeonScore1 = searchResultInfo1.leaderOverallDungeonScore or 0
  local leaderOverallDungeonScore2 = searchResultInfo2.leaderOverallDungeonScore or 0
  if LFGListFrame.CategorySelection.selectedCategory == 2 then
    if leaderOverallDungeonScore1 ~= leaderOverallDungeonScore2 then
      return leaderOverallDungeonScore1 > leaderOverallDungeonScore2
    end
  end
  --If one has more friends, do that one first
  local numBNetFriends1 = searchResultInfo1.numBNetFriends
  local numBNetFriends2 = searchResultInfo2.numBNetFriends
  if numBNetFriends1 ~= numBNetFriends2 then
    return numBNetFriends1 > numBNetFriends2
  end
  local numCharFriends1 = searchResultInfo1.numCharFriends
  local numCharFriends2 = searchResultInfo2.numCharFriends
  if numCharFriends1 ~= numCharFriends2 then
    return numCharFriends1 > numCharFriends2
  end
  local numGuildMates1 = searchResultInfo1.numGuildMates
  local numGuildMates2 = searchResultInfo2.numGuildMates
  if numGuildMates1 ~= numGuildMates2 then
    return numGuildMates1 > numGuildMates2
  end
  local age1 = searchResultInfo1.age
  local age2 = searchResultInfo2.age
  return age1 < age2
end

function LFGListApplicationViewer_UpdateResultList(self)
  self.applicants = C_LFGList.GetApplicants()

  local numApplicants = 0
  local newApplicants = {}
  --Sort applicants
  LFGListUtil_SortApplicants(self.applicants)

  --Cache off the group sizes for the scroll frame and the total height
  local totalHeight = 0
  self.applicantSizes = {}

  local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
  local activityInfo = C_LFGList.GetActivityInfoTable(activeEntryInfo.activityID)

  for i = 1, #self.applicants do
    local applicantID = self.applicants[i]
    local applicantInfo = C_LFGList.GetApplicantInfo(applicantID)
    local matches = true
    local groupInfo = {}
    if activityInfo.isMythicPlusActivity then
      for m = 1, applicantInfo.numMembers do
        local mName, mClass, mLocalizedClass, mLevel, mItemLevel, mHonorLevel, mTank, mHealer, mDamage, mAssignedRole, mRelationship, mDungeonScore, mPvpItemLevel = C_LFGList.GetApplicantMemberInfo(applicantID, m)
        table.insert(
          groupInfo,
          {
            mName = mName,
            mClass = mClass,
            mLocalizedClass = mLocalizedClass,
            mLevel = mLevel,
            mItemLevel = mItemLevel,
            mHonorLevel = mHonorLevel,
            mTank = mTank,
            mHealer = mHealer,
            mDamage = mDamage,
            mAssignedRole = mAssignedRole,
            mRelationship = mRelationship,
            mDungeonScore = mDungeonScore or 0,
            mPvpItemLevel = mPvpItemLevel
          }
        )
      end

      if matches then
        local classFoundInParty = not db.classFilter
        local ratingFoundInParty = not db.ratingFilter
        for m = 1, applicantInfo.numMembers do
          if db.classFilter and LFMPlusFrame.classList[groupInfo[m].mClass].checked then
            classFoundInParty = true
          end
          if db.ratingFilter and groupInfo[m].mDungeonScore >= db.ratingFilterMin then
            ratingFoundInParty = true
          end
        end
        matches = (classFoundInParty and ratingFoundInParty)
      end
      if matches then
        LFMPlus:removeFilteredId(applicantID)
      else
        LFMPlus:addFilteredId(LFMPlusFrame, applicantID)
      end
      LFMPlusFrame:UpdateDeclineButtonInfo()
    end

    if matches or (not activityInfo.isMythicPlusActivity) then
      self.applicantSizes[i] = applicantInfo.numMembers
      numApplicants = numApplicants + 1
      newApplicants[numApplicants] = applicantID
      totalHeight = totalHeight + LFGListApplicationViewerUtil_GetButtonHeight(applicantInfo.numMembers)
    end

  end

  self.applicants = newApplicants
  self.totalApplicantHeight = totalHeight

  LFGListApplicationViewer_UpdateAvailability(self)
end

function LFMPlus:EventHandler(event,...)
end

local InitializeUI =
  function()
  do
    local f = LFMPlusFrame
    f:SetPoint("BOTTOMRIGHT", GroupFinderFrame, "TOPRIGHT")

    ---@class DialogHeaderTemplate:Frame
    ---@field Text FontString
    f.Header = CreateFrame("Frame", nil, LFMPlusFrame, "DialogHeaderTemplate")
    f.Header.Text:SetText("LFM+")
    f.Header:SetWidth(80)
    f.Border = CreateFrame("Frame", nil, LFMPlusFrame, "DialogBorderTemplate")

    function LFMPlusFrame:UpdateDeclineButtonInfo()
      self.declineButtonInfo = {}
      if (not LFMPlus.mPlusListed) then
        self.declineButton:SetText(0)
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
        self.declineButton:SetText(#self.filteredIDs > 0 and GREEN_FONT_COLOR:WrapTextInColorCode(tostring(#self.filteredIDs)) or 0)
        if GameTooltip:IsShown() and GameTooltip:GetOwner():GetName() == "LFMPlusFrame.declineButton" then
          LFMPlus:DeclineButtonTooltip()
        end
      end
    end

    function LFMPlusFrame:ProcessFilteredApp(action)
      -- If the applicant status is anything other than invited or applied it means thier listing is "inactive".
      -- This would be indicated by the default UI as faded entry in the scroll from and happens when an application
      -- expires due to time, the applicant cancels their own application or the applicant gets invited to another group.
      -- At this point, RemoveApplicant is simply clearing the application from the list versus actually declining it like DeclineApplicant.
      if self.nextAppDecline then
        local applicantInfo = C_LFGList.GetApplicantInfo(self.nextAppDecline)
        if applicantInfo then
          local inactiveApplication = (applicantInfo.applicationStatus ~= "applied" and applicantInfo.applicationStatus ~= "invited")
          if action == "decline" and UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) then
            if inactiveApplication then
              C_LFGList.RemoveApplicant(self.nextAppDecline)
            else
              C_LFGList.DeclineApplicant(self.nextAppDecline)
            end
            LFMPlus:RemoveApplicantId(self.nextAppDecline)
          elseif action == "exclude" then
            LFMPlus:excludeFilteredId(self.nextAppDecline)
            if not LFGListFrame.activePanel.searching then
              LFGListFrame.activePanel.RefreshButton:Click()
            end
          end
        end
      end
    end

    function LFMPlusFrame:ShiftDeclineSelection(direction)
      local newVal = nil

      for i = 1, #self.filteredIDs do
        local id = self.filteredIDs[i]

        if ((self.nextAppDecline == id) or (self.nextAppDecline == nil)) and direction == nil then
          self.nextAppDecline = id
          self:UpdateDeclineButtonInfo()
          return
        end

        local nextId = self.filteredIDs[i + 1]
        local prevId = self.filteredIDs[i - 1]

        if self.nextAppDecline == id then
          if direction == true and (nextId and (i + 1 <= ns.constants.declineQueueMax)) then
            newVal = nextId
            break
          elseif direction == false then
            if prevId then
              newVal = prevId
            else
              newVal = self.filteredIDs[ns.constants.declineQueueMax] or self.filteredIDs[#self.filteredIDs]
            end
            break
          end
        end
      end

      if (newVal == nil and self.filteredIDs[1]) then
        newVal = self.filteredIDs[1]
      end
      self.nextAppDecline = newVal
      self:UpdateDeclineButtonInfo()
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
      function(self,value)
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
          function(_,guid)
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
      function(self,button)
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

    local function LFMPlusDD_OnClick(self,id)
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
    LibDD:UIDropDownMenu_SetSelectedValue(f, 0)

    f:Hide()
    db.dungeonFilter = (LFMPlus.mPlusSearch and f:SelectedCount() > 0)
    db.classFilter = (LFMPlus.mPlusListed and f:SelectedCount() > 0)
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
      function(s,b,d)
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
  -- Register Events
  for k, v in pairs(ns.constants.trackedEvents) do
    if v then
      LFMPlus:RegisterEvent(k, LFMPlus.EventHandler)
    end
  end
  for k, v in pairs(LFMPlusFrame.frames.search) do
    LFMPlusFrame.frames.all[k] = v
  end

  for k, v in pairs(LFMPlusFrame.frames.app) do
    LFMPlusFrame.frames.all[k] = v
  end
end

local function ToggleFrames(frame,action)
  if db.enabled and action == "show" then
    LFMPlusFrame:Show()
    LFMPlusFrame.activeRoleFrame:UpdateRoleIcon()

    for k, _ in pairs(LFMPlusFrame.frames[frame]) do
      LFMPlusFrame[k]:Show()
    end
    LFMPlusFrame:Layout()
    LibDD:UIDropDownMenu_Initialize(LFMPlusFrame.DD, LFMPlusFrame.DD.LFMPlusDD_Initialize)
    LFMPlus:RefreshResults()
  end

  if (not db.enabled) or action == "hide" then
    LFMPlusFrame:Hide()
    LFMPlus:ClearValues()
    for k, _ in pairs(LFMPlusFrame.frames.all) do
      LFMPlusFrame[k]:Hide()
    end
  end
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
      set = function(info,v)
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
      set = function(info,v)
        db[info.arg] = v
        LFMPlus:RefreshResults()
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
          set = function(info,v)
            db[info.arg] = v
            LFMPlus:RefreshResults()
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
          set = function(info,v)
            db[info.arg] = v
            LFMPlus:RefreshResults()
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
          set = function(info,v)
            db[info.arg] = v
            if v and not db.shortenActivityName then
              db.shortenActivityName = true
            end
            LFMPlus:RefreshResults()
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
      set = function(info,v)
        db[info.arg] = v
        LFMPlus:RefreshResults()
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
              set = function(info,v)
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
              set = function(info,v)
                db[info.arg] = v
                if v then
                  db.flagRealm = not v
                end
                LFMPlus:RefreshResults()
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
              get = function(info,key)
                return db[info.arg][key]
              end,
              set = function(info,value)
                db[info.arg][value] = not db[info.arg][value]
                local newTbl = {}
                for k, v in pairs(db[info.arg]) do
                  if (k ~= value) or v then
                    newTbl[k] = v
                  end
                end
                db[info.arg] = newTbl
                LFMPlus:RefreshResults()
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
              set = function(info,value)
                if ns.realmFilterPresets[value] then
                  db[info.arg] = ns.realmFilterPresets[value].realms
                end
                LFMPlus:RefreshResults()
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
              set = function(info,v)
                db[info.arg] = v
                if v then
                  db.filterPlayer = not v
                end
                LFMPlus:RefreshResults()
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
              set = function(info,v)
                db[info.arg] = v
                if v then
                  db.flagPlayer = not v
                end
                LFMPlus:RefreshResults()
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
              get = function(info,key)
                return db[info.arg][key]
              end,
              set = function(info,value)
                db[info.arg][value] = not db[info.arg][value]
                local newTbl = {}
                for k, v in pairs(db[info.arg]) do
                  if (k ~= value) or v then
                    newTbl[k] = v
                  end
                end
                db[info.arg] = newTbl
                LFMPlus:RefreshResults()
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

  if db.enabled then
    LFMPlus:Enable()
    ns.Init = true
  end
end

function LFMPlus:Enable()
  if not ns.FrameHooksRan then
    if PVEFrame:IsShown() then
      PVEFrame:Hide()
    end
    LFMPlus:HookScript(
      PVEFrame,
      "OnShow",
      function()
        for _, v in pairs(LFGListFrame.SearchPanel.ScrollFrame.buttons) do
          LFMPlus:HookScript(
            v,
            "OnDoubleClick",
            function(s)
              LFGListApplicationDialog_Show(LFGListApplicationDialog, s.resultID)
            end
          )
        end

        LFMPlus:SecureHookScript(LFGListFrame.SearchPanel,"OnShow",function()
          if LFGListFrame.CategorySelection.selectedCategory == 2 then
              LFMPlus.mPlusSearch = LFGListFrame.CategorySelection.selectedCategory == 2
              ToggleFrames("search", "show")
            end
        end)

        LFMPlus:SecureHookScript(LFGListFrame.SearchPanel,"OnHide",function()
          LFMPlus.mPlusSearch = false
          ToggleFrames("search", "hide")
        end)

        LFMPlus:SecureHookScript(LFGListFrame.ApplicationViewer,"OnShow",function()
          if LFGListFrame.CategorySelection.selectedCategory == 2 then
            LFMPlus.mPlusListed = true
            LFMPlus.mPlusSearch = false
            ToggleFrames("app", "show")
          end
        end)

        LFMPlus:SecureHookScript(LFGListFrame.ApplicationViewer,"OnHide",function()
          LFMPlus.mPlusListed = false
          ToggleFrames("app", "hide")
        end)

        LFMPlus:SecureHookScript(
          LFGListFrame.ApplicationViewer.BrowseGroupsButton,
          "OnClick",
          function()
            if LFGListFrame.CategorySelection.selectedCategory == 2 then
              LFMPlus.mPlusListed = false
              ToggleFrames("app", "hide")
              LFMPlus.mPlusSearch = true
              ToggleFrames("search", "show")
            end
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.SearchPanel.BackToGroupButton,
          "OnClick",
          function()
            if LFGListFrame.CategorySelection.selectedCategory == 2 then
              LFMPlus.mPlusSearch = false
              ToggleFrames("search", "hide")
              LFMPlus.mPlusListed = true
              ToggleFrames("app", "show")
            end
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
        ns.FrameHooksRan = true
      end
    )
  end
end

function LFMPlus:Disable()
  LFMPlus:UnhookAll()
  ns.FrameHooksRan = false
  db.enabled = false
end
