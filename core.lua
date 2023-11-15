--Rev/Hash: 147 - 83e4c758408b98249482554c103c9df48fd2e4b1
---wow.api.start
---@type string
local addonName = select(1, ...)
---@class LFMP
local LFMP = select(2, ...)

local U = LFMP.U
local C = LFMP.C

local FACTION_STRINGS = { [0] = FACTION_HORDE, [1] = FACTION_ALLIANCE};
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

local AceAddon = LibStub:GetLibrary("AceAddon-3.0")

---@class LFMPlus : AceAddon, AceConsole-3.0, AceEvent-3.0, AceHook-3.0
local LFMPlus = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

function LFMPlus.Table_UpdateWithDefaults(table, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if table[k] == nil then table[k] = {} end
            LFMPlus.Table_UpdateWithDefaults(table[k], v)
        else
            if table[k] == nil then table[k] = v end
        end
    end
end

---@class LFMPlusFrame : Frame, ManagedHorizontalLayoutFrameTemplate, DefaultPanelBaseTemplate, BackdropTemplate
LFMPlusFrame = CreateFrame("Frame", "LFMPlusFrame", GroupFinderFrame, "ManagedHorizontalLayoutFrameTemplate, DefaultPanelFlatTemplate, BackdropTemplate")

LFMPlusFrame.textString = "LFM+"

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
LFMPlus.doubleClickHooked = {}

local L = LibStub("AceLocale-3.0"):GetLocale(addonName, false)

local COLOR_RESET = "|r"
local COLOR_GRAY = "|cffbbbbbb"
local COLOR_ORANGE = "|cffffaa66"

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

LFMP.Init = false

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
    if idLoc <= C.declineQueueMax then
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
  local rtnVal = LFMPDB.global.flagRealmList[realm] or false
  if realm then
    if LFMPDB.global.excludeRealmList then
      return rtnVal
    else
      return not rtnVal
    end
  end
end

function LFMPlus:checkPlayer(player)
  local rtnVal = LFMPDB.global.flagPlayerList[player] or false
  if player then
    if LFMPDB.global.excludePlayerList then
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
  for i = 1, C.declineQueueMax do
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
  if not LFMPDB.global.flagPlayerList[name .. "-" .. realm] then
    LFMPDB.global.flagPlayerList[name .. "-" .. realm] = true
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

LFMPlus.lastRefresh = 0
function LFMPlus:RefreshResults()
  if LFMP.Init then
    if LFGListFrame.activePanel.searching == false then
      if LFGListFrame.SearchPanel:IsShown() then
        local now = GetTime()
        if (now - self.lastRefresh) > 5 then
          self.lastRefresh = now
          LFGListFrame.SearchPanel.RefreshButton:Click()
        end
      end
    elseif LFGListFrame.ApplicationViewer:IsShown() then
      LFGListFrame.ApplicationViewer.RefreshButton:Click()
    end
  end
end

LFMP.realmFilterPresets = {
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

LFMP.DebugLog = function(text,type)
  local messagePrefix = "|cFF00FF00LFM+ Debug:|r "
  if LFMP.DEBUG_ENABLED then
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
    ---@class DLAPI
    if DLAPI then DLAPI.DebugLog("LFM+", text) end
    print(messagePrefix .. message)
  end
end

LFMP.InitHooksRan = false
LFMP.FrameHooksRan = false
-- local LFMPlusFrame = LFMPlusFrame

function LFMPlusFrame:showTooltip()
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

---@param values table
---@param val string|integer
---@return integer index
local getIndex = function(values,val)
  local index = {}
  for k, v in pairs(values) do
    index[v] = k
  end
  return index[val]
end

LFMP.DEBUG_ENABLED = false

function LFMPlus:GetTooltipInfo(resultID)
  local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
  local activityID = searchResultInfo.activityID
  if not activityID then
    return nil
  end
  local numMembers = searchResultInfo.numMembers
  local playStyle = 0--searchResultInfo.playstyle
  local numBNetFriends = searchResultInfo.numBNetFriends
  local numCharFriends = searchResultInfo.numCharFriends
  local numGuildMates = searchResultInfo.numGuildMates
  local questID = searchResultInfo.questID
  local activityInfo = C_LFGList.GetActivityInfoTable(activityID, questID, searchResultInfo.isWarMode)

  local classCounts = {}
  local memberList = {}

  for i = 1, numMembers do
    local role, class, classLocalized, specLocalized = C_LFGList.GetSearchResultMemberInfo(resultID, i)
    local classSpec = string.format("%s (%s)",classLocalized, specLocalized)
    local info = {
      role = _G[role],
      title = classSpec,
      color = RAID_CLASS_COLORS[class] or NORMAL_FONT_COLOR
    }
    local roleNumber = {
      ['TANK'] = 1,
      ['HEALER'] = 2,
      ['DAMAGER'] = 3
    }
    table.insert(memberList, info)

    if not classCounts[classSpec] then
      classCounts[classSpec] = {
        title = info.title,
        color = info.color,
        role=_G[role] ,
        counts = {}
      }
    end

    if not classCounts[classSpec].counts[info.role] then
      classCounts[classSpec].counts[info.role] = 0
    end

    classCounts[classSpec].counts[info.role] = classCounts[classSpec].counts[info.role] + 1

    table.sort(classCounts,function(a,b)
      return roleNumber[a.role] < roleNumber[b.role];
    end)
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
    crossFactionListing = searchResultInfo.crossFactionListing,
    leaderFactionGroup = searchResultInfo.leaderFactionGroup,
    playstyleString = "Standard" --C_LFGList.GetPlaystyleString(playStyle, activityInfo)
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
RaiderIO_ProfileTooltip = RaiderIO_ProfileTooltip
function LFMPlus:SearchEntry_OnEnter(s)
  local info = LFMPlus:GetTooltipInfo(s.resultID)
  if not info then return end
  -- setup tooltip
  local owner, anchor, x, y = LFGListFrame.SearchPanel, "ANCHOR_NONE", 0, 0

  if LFMPlusFrame.seasonDetailsFrame and LFMPlusFrame.seasonDetailsFrame:IsShown() then
    owner = LFMPlusFrame.seasonDetailsFrame
  end
  if RaiderIO_ProfileTooltip and RaiderIO_ProfileTooltip:IsShown() then
    owner = RaiderIO_ProfileTooltip
  end

  GameTooltip:SetOwner(owner, anchor, x, y)
  GameTooltip:SetPoint("TOPLEFT",owner,"TOPRIGHT")

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

  local playerProfile = nil
  local leaderProfile = nil

  if info.leaderName then
    GameTooltip:AddLine(string.format(LFG_LIST_TOOLTIP_LEADER, info.leaderName))
    -- load raider.io info if present
    ---@type RaiderIO
    if RaiderIO then
      playerProfile = RaiderIO.GetProfile("player")
      leaderProfile = nil
      if playerProfile then
        leaderProfile = RaiderIO.GetProfile(info.leaderName, playerProfile.faction)
      end
    end
  end
  GameTooltip:AddLine((info.crossFactionListing and GREEN_FONT_COLOR:WrapTextInColorCode("Cross-Faction") or RED_FONT_COLOR:WrapTextInColorCode("Cross-Faction")) .. "/" .. FACTION_STRINGS[info.leaderFactionGroup])
  if info.isRatedPvpActivity and info.leaderPvpRatingInfo then
    GameTooltip_AddNormalLine(GameTooltip, PVP_RATING_GROUP_FINDER:format(info.leaderPvpRatingInfo.activityName, info.leaderPvpRatingInfo.rating, PVPUtil.GetTierName(info.leaderPvpRatingInfo.tier)))
  elseif info.isMythicPlusActivity and info.leaderOverallDungeonScore then
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(info.leaderOverallDungeonScore)
    if not color then
      color = HIGHLIGHT_FONT_COLOR
    end
    GameTooltip:AddLine(DUNGEON_SCORE_LEADER:format(color:WrapTextInColorCode(tostring(info.leaderOverallDungeonScore))))

    -- add last season score if present
    if leaderProfile and leaderProfile.mythicKeystoneProfile and leaderProfile.mythicKeystoneProfile.mplusPrevious then
      local pastScore = leaderProfile.mythicKeystoneProfile.mplusPrevious.score or 0
      local pastSeason = 0
      if leaderProfile.mythicKeystoneProfile.mplusPrevious.season then
          pastSeason = leaderProfile.mythicKeystoneProfile.mplusPrevious.season + 1
      end

      if pastScore > 0 then
          local color = C_ChallengeMode.GetDungeonScoreRarityColor(pastScore) or HIGHLIGHT_FONT_COLOR
          GameTooltip:AddLine(string.format("S%s Rating: %s", pastSeason, color:WrapTextInColorCode(tostring(pastScore))))
      end
    end
  end
  if info.isMythicPlusActivity and info.leaderDungeonScoreInfo then
    local leaderDungeonScoreInfo = info.leaderDungeonScoreInfo
    if leaderDungeonScoreInfo then
      local color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(leaderDungeonScoreInfo.mapScore)
      if not color then
        color = HIGHLIGHT_FONT_COLOR
      end

      local bestDungeonLine = ""
      if leaderDungeonScoreInfo.mapScore == 0 then
        bestDungeonLine = DUNGEON_SCORE_PER_DUNGEON_NO_RATING:format(leaderDungeonScoreInfo.mapName, leaderDungeonScoreInfo.mapScore)
      elseif leaderDungeonScoreInfo.finishedSuccess then
        bestDungeonLine = DUNGEON_SCORE_DUNGEON_RATING:format(leaderDungeonScoreInfo.mapName, color:WrapTextInColorCode(tostring(leaderDungeonScoreInfo.mapScore)), leaderDungeonScoreInfo.bestRunLevel)
      else
        bestDungeonLine = DUNGEON_SCORE_DUNGEON_RATING_OVERTIME:format(leaderDungeonScoreInfo.mapName, color:WrapTextInColorCode(tostring(leaderDungeonScoreInfo.mapScore)), leaderDungeonScoreInfo.bestRunLevel)
      end

      GameTooltip_AddNormalLine(GameTooltip, bestDungeonLine:gsub('Level ','+'))

      -- add in dungeon run counts from raider.io
      if leaderProfile and leaderProfile.mythicKeystoneProfile then
        local twenty = leaderProfile.mythicKeystoneProfile.keystoneTwentyPlus or 0
        local fifteen = leaderProfile.mythicKeystoneProfile.keystoneFifteenPlus or 0
        local ten = leaderProfile.mythicKeystoneProfile.keystoneTenPlus or 0
        local five = leaderProfile.mythicKeystoneProfile.keystoneFivePlus or 0
        local labelString = string.format('%s/%s/%s/%s', twenty, fifteen, ten, five);
        GameTooltip_AddNormalLine(GameTooltip, string.format("%s: %s", 'Timed (+20/15/10/5)', HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(labelString)))
      end
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

---@param self LFGListSearchEntryTemplate
local function LFGListSearchEntry_Update_Post(self)
  ---Hide any shown created icons/textures we create.
  for i = 1, 5 do
    local icon = self.DataDisplay.Enumerate["Icon" .. i]
    if (icon) then
      for _, v in ipairs(C.searchEntryFrames) do
        if icon[v] then
          icon[v]:Hide()
        end
      end
    end
  end

  local resultID = self.resultID
  local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
  local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID)
  if not LFMPlus.doubleClickHooked[self] then
    self:HookScript("OnDoubleClick",function(s)
      if self.isApplication and self.CancelButton:IsShown() then
        C_LFGList.CancelApplication(self.resultID);
        --self.CancelButton:Click()
      else
        LFGListApplicationDialog_Show(LFGListApplicationDialog, self.resultID)
      end
    end)
    LFMPlus.doubleClickHooked[self] = true
  end
  if LFMPDB.global.enabled and LFGListFrame.CategorySelection.selectedCategory == 2 then
    local _, appStatus, pendingStatus, appDuration = C_LFGList.GetApplicationInfo(resultID)
    local isApplication = (appStatus ~= "none" or pendingStatus)
    local isAppFinished = LFGListUtil_IsStatusInactive(appStatus) or LFGListUtil_IsStatusInactive(pendingStatus)

    if not self.factionIcon then
      self.factionIcon = self:CreateTexture (nil, "OVERLAY")
      self.factionIcon:SetDrawLayer("OVERLAY", 7)
      self.factionIcon:SetTexCoord (0, 1, 0, 1)
      self.factionIcon:SetVertexColor (1, 1, 1)
      self.factionIcon:SetDesaturated (false)
      self.factionIcon:SetSize (12, 12)
      self.factionIcon:SetScale (1)
    end
    self.factionIcon:Hide()

    if UnitFactionGroup("player") ~= PLAYER_FACTION_GROUP[searchResultInfo.leaderFactionGroup] then
      local factionString = FACTION_STRINGS[searchResultInfo.leaderFactionGroup];
      self.factionIcon:SetTexture ([[Interface\PVPFrame\PVP-Currency-]] .. factionString)
      self.factionIcon:SetPoint("LEFT",self.Name,"RIGHT")
      self.factionIcon:Show()
    end

    if LFMPDB.global.showLeaderScore and not searchResultInfo.isDelisted and activityInfo.isMythicPlusActivity then
      local formattedLeaderScore = U.formatMPlusRating(searchResultInfo.leaderOverallDungeonScore or 0, true, true)
      local listingName = self.Name:GetText()
      local nameText = string.format("%s %s", formattedLeaderScore, listingName)
      self.Name:SetText(nameText)
      self.ActivityName:SetWordWrap(false)
    end

    ---@type Frame
    local dataDisplayEnum = self.DataDisplay.Enumerate

    if not dataDisplayEnum.leaderIcon then
      dataDisplayEnum.leaderIcon = dataDisplayEnum:CreateTexture("$parentLeaderIcon", "OVERLAY")
      dataDisplayEnum.leaderIcon:SetSize(10, 5)
      dataDisplayEnum.leaderIcon:SetAtlas("groupfinder-icon-leader", false, "LINEAR")
    end

    dataDisplayEnum.leaderIcon:Hide()

    self.ExpirationTime:ClearAllPoints()
    self.ExpirationTime:SetPoint("BOTTOMRIGHT", self.DataDisplay.Enumerate.Icon5, "BOTTOMLEFT", 0, 0)
    self.ExpirationTime:SetJustifyH("RIGHT")

    if (self.ExpirationTime:IsShown()) then
      self.PendingLabel:SetText("")
    end

    local UpdateExpiration = function()
      local duration = 0
      local now = GetTime()
      if (self.expiration and self.expiration > now) then
        duration = self.expiration - now
      end

      local minutes = math.floor(duration / 60)
      local seconds = duration % 60
      if minutes > 1 then
        self.ExpirationTime:SetFormattedText("%dm", minutes)
      else
        self.ExpirationTime:SetFormattedText("%.2ds", seconds)
      end
    end

    if isApplication then
      self:SetScript("OnUpdate", UpdateExpiration)
      UpdateExpiration()
    else
      self:SetScript("OnUpdate", nil)
    end

    local numMembers = searchResultInfo.numMembers

    ---@type table<integer,{orderIndex: integer, class: string, leader: boolean, role: string}>
    local groupMemberInfo = {}

    for i = 1, numMembers do
      ---@return string,string
      local role, class, _, _ = C_LFGList.GetSearchResultMemberInfo(resultID, i)
      local memberInfo = {
        orderIndex = C.roleOrder[role],
        class = class,
        leader = i == 1,
        role = role
      }
      table.insert(groupMemberInfo,memberInfo)
    end

    -- Sort the table by order index placing Tanks over Healers over DPS.
    table.sort(
      groupMemberInfo,
      function(a,b)
        return a.orderIndex < b.orderIndex
      end
    )

    for i = 1, numMembers do
      -- Icon Frames go right to left where group member 1 is Icon5 and group member 5 is Icon1.
      -- To account for this, we do some simple math to get the Icon frame for the group member we are currently working with.
      local currentIconNumber = (5 - i) + 1
      local currentClass = groupMemberInfo[i].class

      -- The role icons we use match for TANK and HEALER but not for DPS.
      local roleName = groupMemberInfo[i].role == "DAMAGER" and "DPS" or groupMemberInfo[i].role
      local classColor = RAID_CLASS_COLORS[currentClass]
      local r, g, b, _ = classColor:GetRGBA()

      local iconFrame = dataDisplayEnum["Icon" .. currentIconNumber]
      if not iconFrame then
        return
      end
      iconFrame:SetSize(18, 18)

      if not iconFrame.classDot then
        iconFrame.classDot = CreateFrame("Frame", dataDisplayEnum["ClassDot" .. currentIconNumber], dataDisplayEnum)
        iconFrame.classDot:SetFrameLevel(dataDisplayEnum:GetFrameLevel())
        iconFrame.classDot:SetPoint("CENTER", iconFrame)
        iconFrame.classDot:SetSize(18, 18)
        iconFrame.classDot.tex = iconFrame.classDot:CreateTexture(dataDisplayEnum["ClassDot" .. currentIconNumber .. "Tex"], "ARTWORK")
        iconFrame.classDot.tex:SetAllPoints(iconFrame.classDot)
        iconFrame.classDot.tex:SetTexture([[Interface\AddOns\LFM+\Textures\Circle_Smooth_Border]])
      end
      iconFrame.classDot:Hide()

      if not iconFrame.roleIcon then
        iconFrame.roleIcon = dataDisplayEnum:CreateTexture(dataDisplayEnum["RoleIcon" .. currentIconNumber], "OVERLAY")
        iconFrame.roleIcon:SetSize(10, 10)
        iconFrame.roleIcon:SetPoint("TOP", iconFrame, "CENTER", -1, -3)
      end
      iconFrame.roleIcon:SetAtlas("roleicon-tiny-" .. string.lower(roleName))
      iconFrame.roleIcon:Hide()

      if not iconFrame.classBar then
        ---@type Texture
        iconFrame.classBar = dataDisplayEnum:CreateTexture(dataDisplayEnum["ClassBar" .. currentIconNumber], "ARTWORK")
        iconFrame.classBar:SetSize(10, 3)
        iconFrame.classBar:SetPoint("TOP", iconFrame, "BOTTOM")
      end
      iconFrame.classBar:Hide()

      -- dot - Displays a sphere colored to the class behind a smaller role icon in the same position as the default UI.
      -- icon - Displays an icon for the class in the same position as the default UI with a small role (if tank or healer) attached to the bottom of the icon.
      if LFMPDB.global.classRoleDisplay == "dot" or LFMPDB.global.classRoleDisplay == "icon" then

        iconFrame.roleIcon:SetAtlas("roleicon-tiny-" .. string.lower(roleName))
        if LFMPDB.global.classRoleDisplay == "dot" then
          iconFrame:Hide()
          iconFrame.classDot.tex:SetVertexColor(r, g, b, 1)
          iconFrame.classDot:Show()
          iconFrame.roleIcon:SetPoint("TOP", iconFrame, "CENTER", 0, 5)
        elseif LFMPDB.global.classRoleDisplay == "icon" then
          iconFrame.roleIcon:SetPoint("TOP", iconFrame, "CENTER", -1, -3)
          iconFrame:SetAtlas("groupfinder-icon-class-" .. string.lower(currentClass))
        end
        iconFrame.roleIcon:Show()
      elseif LFMPDB.global.classRoleDisplay == "bar" then
        iconFrame.classBar:SetColorTexture(r, g, b, 1)
        iconFrame.classBar:Show()
      elseif LFMPDB.global.classRoleDisplay == "def" then
        iconFrame:SetSize(18, 18)
      end

      -- Displays a crown attached to the top of the leaders role icon.
      if LFMPDB.global.showPartyLeader then
        if groupMemberInfo[i].leader then
          dataDisplayEnum.leaderIcon:ClearAllPoints()
          dataDisplayEnum.leaderIcon:SetPoint("BOTTOM", iconFrame, "TOP", 0, 0)
          dataDisplayEnum.leaderIcon:Show()
        end
      else
        dataDisplayEnum.leaderIcon:Hide()
      end
    end

    if LFMPDB.global.alwaysShowRoles then
      self.DataDisplay:ClearAllPoints()
      self.DataDisplay:SetPoint("BOTTOMRIGHT", self.CancelButton, "BOTTOMLEFT", 5, -5)
      if not self.DataDisplay:IsShown() then
        self.DataDisplay:Show()
      end
    end
    local dungeonInfo = C.activityInfo(searchResultInfo.activityID)
    if LFMPDB.global.shortenActivityName and dungeonInfo and activityInfo.isMythicPlusActivity then
      self.ActivityName:SetText(dungeonInfo.shortName .. " (M+)")
      self.ActivityName:SetWordWrap(false)
    end

    if LFMPDB.global.showRealmName and activityInfo.isMythicPlusActivity then
      local leaderName, realmName = LFMPlus:GetNameRealm(searchResultInfo.leaderName)
      if (leaderName) then
        if realmName then
          if (LFMPDB.global.flagRealm and LFMPlus:checkRealm(realmName)) or (LFMPDB.global.flagPlayer and LFMPlus:checkPlayer(leaderName)) then
            realmName = RED_FONT_COLOR:WrapTextInColorCode(realmName)
          else
            realmName = NORMAL_FONT_COLOR:WrapTextInColorCode(realmName)
          end
        else
          realmName = BATTLENET_FONT_COLOR:WrapTextInColorCode(GetRealmName())
        end
        if realmName then
          local activityName = self.ActivityName:GetText() .. " " .. realmName
          self.ActivityName:SetText(activityName)
          self.ActivityName:SetWordWrap(false)
        end
      end
    end
  else
    self.DataDisplay:ClearAllPoints()
    self.DataDisplay:SetPoint("RIGHT",self.DataDisplay:GetParent(),"RIGHT",0,-1)
  end
end

hooksecurefunc('LFGListSearchEntry_Update',LFGListSearchEntry_Update_Post)
local roleRemainingKeyLookup = {
	["TANK"] = "TANK_REMAINING",
	["HEALER"] = "HEALER_REMAINING",
	["DAMAGER"] = "DAMAGER_REMAINING",
};
local function HasRemainingSlotsForLocalPlayerRole(lfgSearchResultID)
	local roles = C_LFGList.GetSearchResultMemberCounts(lfgSearchResultID);
	local playerRole = GetSpecializationRole(GetSpecialization());
	return roles[roleRemainingKeyLookup[playerRole]] > 0;
end
local dungeonSelected = function(activityId)
  if LFMPlusFrame.dungeonList[activityId] then
    return LFMPlusFrame.dungeonList[activityId].checked
  else
    return false
  end
end
function LFGListSearchPanel_UpdateResultList_Post(self)
  local results = self.results

    if LFMPDB.global.enabled and LFGListFrame.CategorySelection.selectedCategory == 2 then
      local minAge = nil
      for i = #results, 1, -1 do
        local resultID = results[i]
        local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)

        local age = searchResultInfo.age
        local activityID = searchResultInfo.activityID
        local leaderName, realmName = LFMPlus:GetNameRealm(searchResultInfo.leaderName)

        local activityInfoTable = C_LFGList.GetActivityInfoTable(activityID, nil, searchResultInfo.isWarMode)
        local hasSlots = HasRemainingSlotsForLocalPlayerRole(resultID)

        local friendsOrGuild = (searchResultInfo.numBNetFriends or 0) + (searchResultInfo.numCharFriends or 0) + (searchResultInfo.numGuildMates or 0)
        if not minAge or (age < minAge) then
          minAge = age
        end

        local matches = true
        if matches and LFMPDB.global.activeRoleFilter then
          matches = hasSlots
        end

        if matches and LFMPDB.global.ratingFilter then
          matches = (searchResultInfo.leaderOverallDungeonScore or 0) >= LFMPDB.global.ratingFilterMin
        end

        if matches and LFMPDB.global.filterRealm and searchResultInfo.leaderName then
          matches = LFMPlus:checkRealm(realmName)
        end

        if matches and LFMPDB.global.filterPlayer and searchResultInfo.leaderName then
          matches = LFMPlus:checkPlayer(leaderName)
        end

        if matches and LFMPDB.global.dungeonFilter then
          matches = dungeonSelected(activityID)
        end

        if matches and LFMPDB.global.ratingFilter then
          matches = activityInfoTable.isMythicPlusActivity
        end

        if not matches and LFMPDB.global.alwaysShowFriends then
          matches = friendsOrGuild > 0
        end

        if not matches then
          table.remove(results, i)
        end
      end
      table.sort(results, LFGListUtil_SortSearchResultsCB_Post);
      self.results = results
      self.totalResults = #self.results
    else
      LFGListUtil_SortSearchResults(self.results);
    end

    LFGListSearchPanel_UpdateResults(self)
end
hooksecurefunc('LFGListSearchPanel_UpdateResultList', LFGListSearchPanel_UpdateResultList_Post)

function LFGListApplicationDialog_Show(self, resultID)
	local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID);

	self.resultID = resultID;
	self.activityID = searchResultInfo.activityID;
  local applicationNote = self.Description.EditBox:GetText()
	LFGListApplicationDialog_UpdateRoles(self);
	StaticPopupSpecial_Show(self);
  if LFMPDB.global.lfgListingDoubleClick and applicationNote ~= "" then
    if(IsShiftKeyDown()) then
      print("LFM+: Shift detected, skipping auto sign up.")
    else
      LFGListApplicationDialog.SignUpButton:Click()
      print("LFM+: Signed Up with Note: " .. self.Description.EditBox:GetText())
    end
  end
end

function LFGListUtil_SortSearchResultsCB_Post(id1,id2)
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

--hooksecurefunc('LFGListUtil_SortSearchResultsCB',LFGListUtil_SortSearchResultsCB_Post)

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
        local classFoundInParty = not LFMPDB.global.classFilter
        local ratingFoundInParty = not LFMPDB.global.ratingFilter
        for m = 1, applicantInfo.numMembers do
          if LFMPDB.global.classFilter and LFMPlusFrame.classList[groupInfo[m].mClass].checked then
            classFoundInParty = true
          end
          if LFMPDB.global.ratingFilter and groupInfo[m].mDungeonScore >= LFMPDB.global.ratingFilterMin then
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

LFMPlusFrame:SetScript("OnEvent",function(self,event,...)
  if ( event == "LFG_LIST_APPLICATION_STATUS_UPDATED" ) then
		local searchResultID, newStatus, oldStatus, kstringGroupName = ...;
		local chatMessage = LFGListFrame_GetChatMessageForSearchStatusChange(newStatus);
    local searchResultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
    local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID)
    --TODO: Handle 'applied', 'cancelled' and 'invited' statuses
		if ( chatMessage and activityInfo.isMythicPlusActivity) then
      local chatFormatString = "%s: Listing: '%s' (%s) - Status: %s."
      local lfmHeader = GREEN_FONT_COLOR:WrapTextInColorCode("LFM+")
      local groupName = YELLOW_FONT_COLOR:WrapTextInColorCode(kstringGroupName)
      local reason = "Unknown"
      if newStatus == "declined" then
        reason = "Declined"
      elseif newStatus == "declined_full" then
        reason = "Filled"
      elseif newStatus == "declined_delisted" then
        reason = "Delisted"
      else
        reason = "Expired"
      end
      reason = newStatus == "declined" and RED_FONT_COLOR:WrapTextInColorCode(newStatus) or YELLOW_FONT_COLOR:WrapTextInColorCode(reason)
      local dungeonInfo = C.activityInfo(searchResultInfo.activityID)
      local activtyShortName = dungeonInfo and string.format("%s (M+)", dungeonInfo.shortName) or activityInfo.fullName
      local defaultChatMessage = LFGListFrame_GetChatMessageForSearchStatusChange(newStatus);
      local newMessage = chatFormatString:format(lfmHeader, groupName, activtyShortName, reason)

      local messageFound = false
      local function ShouldChangeToDeleted(message, r, g, b, ...)
        if not messageFound and message == defaultChatMessage then
          messageFound = true
          return true
        end
      end

      local function TransformFunction(message,r,g,b,...)
        return newMessage
      end

      DEFAULT_CHAT_FRAME:TransformMessages(ShouldChangeToDeleted, TransformFunction)
      --DEFAULT_CHAT_FRAME:AddMessage(chatFormatString:format(lfmHeader, groupName, activityInfo.fullName, reason), nil, nil, nil, 1);
			--ChatFrame_DisplaySystemMessageInPrimary(chatFormatString:format(kstringGroupName,activityInfo.fullName,reason));
		end
	end
end)

function LFMPlusFrame:RegisterEvents()
  self:RegisterEvent('LFG_LIST_APPLICATION_STATUS_UPDATED')
  print('Registered LFG_LIST_APPLICATION_STATUS_UPDATED')
end

local activeRoleFrame_OnMouseDown = function(self,button)
  if button == "LeftButton" then
    LFMPDB.global.activeRoleFilter = not LFMPDB.global.activeRoleFilter
    self.ToggleGlow()
    LFMPlus:RefreshResults()
  end
end

local InitializeUI = function()
  do
    local f = CreateFrame("Frame",nil,LFMPlusFrame)
    f:EnableMouse(true)
    f:SetSize(35,32)
    f.noclick = false
    f.value = 0

    f.layoutIndex = 3
    f.topPadding = 26
    f.rightPadding = 20
    f.leftPadding = 20
    f.bottomPadding = 13

    f.RatingText = f:CreateFontString("$parent.LFMP_RatingText", "OVERLAY", "GameFontNormal")
    f.RatingText:SetTextColor(1, 1, 1, 1)
    f.RatingText:SetPoint("LEFT")
    f.RatingText:SetPoint("RIGHT")
    ---@return integer
    function f:GetValue()
      return self.value
    end

    ---@param value integer
    function f:SetValue(value)
      if self.noclick then
        local setValue = type(value) == "number" and value >= C.ratingMin and value <= C.ratingMax and value or C.ratingMin
        LFMPDB.global.ratingFilterMin = setValue
        LFMPDB.global.ratingFilter = setValue > 0
        self.value = setValue
      end
    end

    ---@param value integer
    function f:SetDisplayValue(value)
      self.noclick = true
      self:SetValue(value)
      self.RatingText:SetText(U.formatMPlusRating(self:GetValue(), true, true))
      LFMPlus:RefreshResults()
      self.noclick = false
    end

    f:SetScript("OnMouseWheel",function(self, delta)
      local newValue  = (self:GetValue() + delta * 100)
      if((self:GetValue() ~= newValue) and (newValue >= C.ratingMin and newValue <= C.ratingMax))then
        self:SetDisplayValue(newValue)
      end
    end)

    LFMPlusFrame.RatingFrame = f
    LFMPlusFrame.frames.search["RatingFrame"] = true
    LFMPlusFrame.frames.app["RatingFrame"] = true
    f:SetDisplayValue(C.ratingMin)
    f:Hide()
  end
  do
    local f = LFMPlusFrame

    f:SetPoint("BOTTOMRIGHT", GroupFinderFrame, "TOPRIGHT")
    f:SetTitle("LFM+")

    ---@class DialogHeaderTemplate:Frame
    ---@field Text FontString
    --f.Header = CreateFrame("Frame", nil, LFMPlusFrame, "DialogHeaderTemplate")
    --f.Header.Text:SetText("LFM+")
    --f.Header:SetWidth(80)
    --f.Border = CreateFrame("Frame", nil, LFMPlusFrame, "DialogBorderTemplate")

    function LFMPlusFrame:UpdateDeclineButtonInfo()
      self.declineButtonInfo = {}
      if (not LFMPlus.mPlusListed) then
        self.declineButton:SetText(0)
      else
        for i = 1, C.declineQueueMax do
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
              local formattedName = RAID_CLASS_COLORS[className]:WrapTextInColorCode(string.format(C.lengths.name, shortName))
              local roleIcons = string.format("%s%s%s", CreateAtlasMarkup(tank and "roleicon-tiny-tank" or "groupfinder-icon-emptyslot", 10, 10), CreateAtlasMarkup(healer and "roleicon-tiny-healer" or "groupfinder-icon-emptyslot", 10, 10), CreateAtlasMarkup(damage and "roleicon-tiny-dps" or "groupfinder-icon-emptyslot", 10, 10))

              local header = CreateAtlasMarkup(((applicantID == self.nextAppDecline and memberIdx == 1) and "pvpqueue-sidebar-nextarrow" or ""), 10, 10)
              local memberString = string.format("%s%s %s %s %s", header, U.formatMPlusRating(dungeonScore, true, true), roleIcons, formattedName, string.format(C.lengths.server, server))
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
          if direction == true and (nextId and (i + 1 <= C.declineQueueMax)) then
            newVal = nextId
            break
          elseif direction == false then
            if prevId then
              newVal = prevId
            else
              newVal = self.filteredIDs[C.declineQueueMax] or self.filteredIDs[#self.filteredIDs]
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

  end

  do
    -- Create button to toggle filtering search results based on the result having a spot for your active role.
    local f = CreateFrame("Frame", nil, LFMPlusFrame)
    f.tooltipText = "Hide groups without current spec role available."

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
              local roleAtlas = C.atlas[role] or C.atlas.NA
              self.roleIcon:SetText(CreateAtlasMarkup(roleAtlas, 25, 25))
            end
          end
        )
      end
    end

    function f:ToggleGlow()
      if LFMPDB.global.activeRoleFilter then
        f.roleIconGlow:Show()
      else
        f.roleIconGlow:Hide()
      end
    end

    f:SetSize(25, 25)
    f.roleIcon = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.roleIcon:SetText(L["Role"])
    f.roleIcon:SetPoint("CENTER", f, "CENTER")

    f.roleIconGlow = f:CreateFontString(nil, "BORDER", "GameFontNormal")
    f.roleIconGlow:SetText(CreateAtlasMarkup("groupfinder-eye-highlight", 40, 40))
    f.roleIconGlow:SetSize(45, 45)
    f.roleIconGlow:SetPoint("CENTER", f.roleIcon, "CENTER")

    f.tooltipText = L["ActiveRoleTooltip"]
    f:SetScript("OnEnter", LFMPlusFrame.showTooltip)
    f:SetScript("OnLeave", hideTooltip)
    f:SetScript(
      "OnMouseDown",
      function(self,button)
        if button == "LeftButton" then
          LFMPDB.global.activeRoleFilter = not LFMPDB.global.activeRoleFilter
          f:ToggleGlow()
          if LFGListFrame.activePanel.searching == false then
            if LFGListFrame.SearchPanel:IsShown() then
              LFGListFrame.SearchPanel.RefreshButton:Click()
            elseif LFGListFrame.ApplicationViewer:IsShown() then
              LFGListFrame.ApplicationViewer.RefreshButton:Click()
            end
          end
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

    local function LFMPlusDD_OnClick(self, id, arg2)
      local activeList = LFMPlus.mPlusSearch and LFMPlusFrame.dungeonList or LFMPlusFrame.classList
      if id == false then
        for _, v in pairs(activeList) do
          v.checked = false
        end
      else
        activeList[id].checked = not activeList[id].checked
        LibDD:UIDropDownMenu_SetSelectedValue(f, id)
      end
      LFMPDB.global.dungeonFilter = (LFMPlus.mPlusSearch and f:SelectedCount() > 0)
      LFMPDB.global.classFilter = (LFMPlus.mPlusListed and f:SelectedCount() > 0)
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
          LFMPDB.global.classFilter = false
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

        ---@class ChallengeMapInfo
        ---@field id integer
        ---@field name string
        ---@field longName string
        ---@field challMapID integer
        ---@field timeLimit integer
        ---@field texture string
        ---@field backgroundTexture string
        ---@field checked boolean

        ---@type table<integer, ChallengeMapInfo>
        local mapChallengeModeInfo = {}

        if (not activityIDs) or (#activityIDs == 0) or (not mapChallengeModeIDs) or (#mapChallengeModeIDs == 0) then
          LFMPlusFrame.dungeonListLoaded = false
          return
        end
        for shortName, dungeon in pairs(C.dungeons) do
          local name, id, timeLimit, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(dungeon.cmID)
          table.insert(
            mapChallengeModeInfo,
            {
              id = dungeon.aID,
              name = shortName,
              longName = name,
              challMapID = id,
              timeLimit = timeLimit,
              texture = texture,
              backgroundTexture = backgroundTexture,
              checked = false
            }
          )
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
        local dungeonListLength = 0
        for _, activityID in pairs(activityIDs) do
          local activityInfoTable = C_LFGList.GetActivityInfoTable(activityID)
          if activityInfoTable.isMythicPlusActivity then
            for _, challMap in pairs(mapChallengeModeInfo) do
              local dungeonInfo = C.challengeMode(challMap.challMapID)
              if dungeonInfo and dungeonInfo.aID == activityID then
                local dungeon = challMap
                dungeon.name = dungeonInfo and dungeonInfo.shortName or activityInfoTable.fullName
                LFMPlusFrame.dungeonList[activityID] = dungeon
                dungeonListLength = dungeonListLength + 1
              end
            end
          end
        end

        LFMPlusFrame.dungeonListLoaded = dungeonListLength > 1
      end
      local activeList = LFMPlus.mPlusSearch and LFMPlusFrame.dungeonList or LFMPlusFrame.classList
      local info = LibDD:UIDropDownMenu_CreateInfo()
      local sortedKeys = {}

      for k,v in pairs(activeList) do
        table.insert(sortedKeys,k)
      end

      local normalButtonAdded = false
      for _, id in pairs(sortedKeys) do
        if LFMPlus.mPlusSearch and ((not C.timewalk[id]) and (not normalButtonAdded)) then
          info.justifyH = "CENTER"
          info.isTitle = true
          info.notCheckable = true
          info.disabled = true
          info.text = 'M+'
          info.owner = self
          LibDD:UIDropDownMenu_AddButton(info)
          normalButtonAdded = true
        end
        local item = activeList[id]
        info.justifyH = "LEFT"
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
      info.justifyH = "CENTER"
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
    LFMPDB.global.dungeonFilter = (LFMPlus.mPlusSearch and f:SelectedCount() > 0)
    LFMPDB.global.classFilter = (LFMPlus.mPlusListed and f:SelectedCount() > 0)
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
  for k, v in pairs(LFMPlusFrame.frames.search) do
    LFMPlusFrame.frames.all[k] = v
  end

  for k, v in pairs(LFMPlusFrame.frames.app) do
    LFMPlusFrame.frames.all[k] = v
  end

  LFMPlusFrame:RegisterEvents()
end

local function ToggleFrames(frame,action)
  if LFMPDB.global.enabled and action == "show" then
    LFMPlusFrame:Show()
    LFMPlusFrame.activeRoleFrame:UpdateRoleIcon()

    for k, _ in pairs(LFMPlusFrame.frames[frame]) do
      LFMPlusFrame[k]:Show()
    end
    LFMPlusFrame:Layout()
    LibDD:UIDropDownMenu_Initialize(LFMPlusFrame.DD, LFMPlusFrame.DD.LFMPlusDD_Initialize)
    LFMPlus:RefreshResults()
  end

  if (not LFMPDB.global.enabled) or action == "hide" then
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
    return LFMPDB.global[info.arg]
  end,
  args = {
    enabled = {
      type = "toggle",
      name = L["Enable LFMPlus"],
      desc = L["Enable or disable LFMPlus"],
      order = 1,
      arg = "enabled",
      set = function(info,v)
        LFMPDB.global[info.arg] = v
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
        return LFMPDB.global[info.arg]
      end,
      set = function(info,v)
        LFMPDB.global[info.arg] = v
        LFMPlus:RefreshResults()
      end,
      disabled = function()
        return not LFMPDB.global.enabled
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
          name = "         ",
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
            LFMPDB.global[info.arg] = v
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
            LFMPDB.global[info.arg] = v
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
            LFMPDB.global[info.arg] = v
            if v and not LFMPDB.global.shortenActivityName then
              LFMPDB.global.shortenActivityName = true
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
        return LFMPDB.global[info.arg]
      end,
      set = function(info,v)
        LFMPDB.global[info.arg] = v
        LFMPlus:RefreshResults()
      end,
      disabled = function()
        return not LFMPDB.global.enabled
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
                LFMPDB.global[info.arg] = v
                if v then
                  LFMPDB.global.filterRealm = not v
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
                LFMPDB.global[info.arg] = v
                if v then
                  LFMPDB.global.flagRealm = not v
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
                for k, _ in pairs(LFMPDB.global.flagRealmList) do
                  rtnVal[k] = k
                end
                return rtnVal
              end,
              get = function(info,key)
                return LFMPDB.global[info.arg][key]
              end,
              set = function(info,value)
                LFMPDB.global[info.arg][value] = not LFMPDB.global[info.arg][value]
                local newTbl = {}
                for k, v in pairs(LFMPDB.global[info.arg]) do
                  if (k ~= value) or v then
                    newTbl[k] = v
                  end
                end
                LFMPDB.global[info.arg] = newTbl
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
                for k, _ in pairs(LFMP.realmFilterPresets) do
                  rtnVal[k] = k
                end
                return rtnVal
              end,
              set = function(info,value)
                if LFMP.realmFilterPresets[value] then
                  LFMPDB.global[info.arg] = LFMP.realmFilterPresets[value].realms
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
                LFMPDB.global[info.arg] = v
                if v then
                  LFMPDB.global.filterPlayer = not v
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
                LFMPDB.global[info.arg] = v
                if v then
                  LFMPDB.global.flagPlayer = not v
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
                for k, _ in pairs(LFMPDB.global.flagPlayerList) do
                  rtnVal[k] = k
                end
                return rtnVal
              end,
              get = function(info,key)
                return LFMPDB.global[info.arg][key]
              end,
              set = function(info,value)
                LFMPDB.global[info.arg][value] = not LFMPDB.global[info.arg][value]
                local newTbl = {}
                for k, v in pairs(LFMPDB.global[info.arg]) do
                  if (k ~= value) or v then
                    newTbl[k] = v
                  end
                end
                LFMPDB.global[info.arg] = newTbl
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
  LFMPDB = LFMPDB or {}
  LFMPlus.Table_UpdateWithDefaults(LFMPDB,C.defaults)
  --LFMPDB = LibStub("AceDB-3.0"):New(ns.constants.friendlyName .. "DB", ns.constants.defaults, true)

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

  LFMPlus:Enable()
  LFMP.Init = true
end
function FixGetPlayStyleString()
    -- Copy/Pasta from https://github.com/0xbs/premade-groups-filter/blob/master/FixGetPlaystyleString.lua
    -- By overwriting C_LFGList.GetPlaystyleString, we taint the code writing the tooltip (which does not matter),
    -- and also code related to the dropdows where you can select the playstyle. The only relevant protected function
    -- here is C_LFGList.SetEntryTitle, which is only called from LFGListEntryCreation_SetTitleFromActivityInfo.
    -- Players that do not have an authenticator attached to their account cannot set the title or comment when creating
    -- groups. Instead, Blizzard sets the title programmatically. If we taint this function, these players can not create
    -- groups anymore, so we check on an arbitrary mythic plus dungeon if the player is authenticated to create a group.
    local activityIdOfArbitraryMythicPlusDungeon = 703 -- Mists of Tirna Scithe
    if not C_LFGList.IsPlayerAuthenticatedForLFG(activityIdOfArbitraryMythicPlusDungeon) then
        print("LFM+: Will not apply fix for 'Interface action failed because of an AddOn' errors because you don't seem to have a fully secured account and otherwise can't create premade groups. See addon FAQ for more information and how to fix this issue.")
        return
    end

    -- Overwrite C_LFGList.GetPlaystyleString with a custom implementation because the original function is
    -- hardware protected, causing an error when a group tooltip is shown as we modify the search result list.
    -- Original code from https://github.com/ChrisKader/LFMPlus/blob/36bca68720c724bf26cdf739614d99589edb8f77/core.lua#L38
    -- but sligthly modified.
    C_LFGList.GetPlaystyleString = function(playstyle, activityInfo)
        if not ( activityInfo and playstyle and playstyle ~= 0
                and C_LFGList.GetLfgCategoryInfo(activityInfo.categoryID).showPlaystyleDropdown ) then
            return nil
        end
        local globalStringPrefix
        if activityInfo.isMythicPlusActivity then
            globalStringPrefix = "GROUP_FINDER_PVE_PLAYSTYLE"
        elseif activityInfo.isRatedPvpActivity then
            globalStringPrefix = "GROUP_FINDER_PVP_PLAYSTYLE"
        elseif activityInfo.isCurrentRaidActivity then
            globalStringPrefix = "GROUP_FINDER_PVE_RAID_PLAYSTYLE"
        elseif activityInfo.isMythicActivity then
            globalStringPrefix = "GROUP_FINDER_PVE_MYTHICZERO_PLAYSTYLE"
        end
        return globalStringPrefix and _G[globalStringPrefix .. tostring(playstyle)] or nil
    end

    -- Disable automatic group titles to prevent tainting errors
    LFGListEntryCreation_SetTitleFromActivityInfo = function(_) end
end
function LFMPlus:HookScripts()
  if not LFMP.FrameHooksRan then
    if PVEFrame:IsShown() then
      PVEFrame:Hide()
    end
    --FixGetPlayStyleString()
    LFMPlus:HookScript(
      PVEFrame,
      "OnShow",
      function()
        if not IsAddOnLoaded("Blizzard_ChallengesUI") then
          LoadAddOn("Blizzard_ChallengesUI")
        end
        --LFMP:loadSeasonDetails()

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
            if LFMPDB.global.autoFocusSignUp then
              LFGListApplicationDialogDescription.EditBox:SetFocus()
            end
          end
        )

        LFMPlus:HookScript(
          LFGListApplicationDialogDescription.EditBox,
          "OnEnterPressed",
          function()
            if LFMPDB.global.signupOnEnter then
              LFGListApplicationDialog.SignUpButton:Click()
            end
          end
        )

        LFMPlus:HookScript(
          LFGListFrame.ApplicationViewer.UnempoweredCover,
          "OnShow",
          function()
            if LFMPDB.global.hideAppViewerOverlay then
              LFGListFrame.ApplicationViewer.UnempoweredCover:Hide()
            end
          end
        )
        LFMPlus:Unhook(PVEFrame, "OnShow")
        LFMP.FrameHooksRan = true
      end
    )
  end
end

function LFMPlus:Enable()
  LFMPlus:HookScripts()
end

function LFMPlus:Disable()
  LFMPlus:UnhookAll()
  LFMP.FrameHooksRan = false
  LFMPDB.global.enabled = false
end
