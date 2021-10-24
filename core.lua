---@type string
local addonName,
---@type ns
ns = ...

local CreateFrame = CreateFrame
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_Refresh = UIDropDownMenu_Refresh
local UIDropDownMenu_AddSeparator = UIDropDownMenu_AddSeparator
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local UIDropDownMenu_JustifyText = UIDropDownMenu_JustifyText
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth

local LFMPlus = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

---@class LFMPlusFrame:ManagedHorizontalLayoutFrameTemplate
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

StaticPopupDialogs["LFMPLUS_FILTER"] = {
  text = "Do you want to add server %s, or player %s?",
  -- YES, NO, ACCEPT, CANCEL, etc, are global WoW variables containing localized
  -- strings, and should be used wherever possible.
  button1 = CANCEL,
  button2 = "Server",
  button3 = PLAYER,
  OnButton1 = function(self, data)
    print("Cancel pressed")
  end,
  OnButton2 = function(self, data)
    print("Filter Server")
  end,
  OnButton3 = function(self, data)
    print("Filter Player")
  end,
  timeout = 30,
  whileDead = true,
  hideOnEscape = true
}

function LFMPlus:showDialog(name, realm)
  local data = {name, realm}
  print(name,realm)
  StaticPopup_Show("LFMPLUS_FILTER", name, realm, data)
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

function LFMPlus:filterTable(t, ids)
  LFMPlusFrame.filteredIDs = {}
  for _, id in ipairs(ids) do
    for j = #t, 1, -1 do
      if (t[j] == id) then
        tremove(t, j)
        tinsert(LFMPlusFrame.filteredIDs, id)
        table.sort(LFMPlusFrame.filteredIDs)
        if LFMPlus.mPlusListed then
          LFMPlusFrame:UpdateDeclineButtonInfo()
        end
        break
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
  if ns.Init and LFGListFrame and LFGListFrame.activePanel and LFGListFrame.activePanel.RefreshButton then
    LFGListFrame.activePanel.RefreshButton:Click()
  end
end

function LFMPlus:GetNameRealm(unit, tempRealm)
  local name,
    realm = nil, tempRealm
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
    if LFMPlus.mPlusSearch then
      LFGListSearchPanel_UpdateResultList(LFGListFrame.activePanel)
    end
    LFGListFrame.activePanel.RefreshButton:Click()
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

local function EventHandler(event, ...)
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
      if
        applicantInfo and (applicantInfo.applicationStatus ~= "applied") and (applicantInfo.applicationStatus ~= "invited") and
          (applicantInfo.applicationStatus ~= "inviteaccepted")
       then
        LFMPlus:RemoveApplicantId(applicantID)
      end
    end
  end

  if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" or event == "GROUP_ROSTER_UPDATE" then
    if C_LFGList.HasActiveEntryInfo() then
      local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
      if activeEntryInfo then
        local _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          isMythicPlusActivity = C_LFGList.GetActivityInfo(activeEntryInfo.activityID)
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
end

-- Register Events
for k, v in pairs(ns.constants.trackedEvents) do
  if v then
    LFMPlus:RegisterEvent(k, EventHandler)
  end
end

local SortSearchResults = function(results)
  if not LFMPlus.mPlusSearch then
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
      local filterFriends =
        db.alwaysShowFriends and ((searchResultInfo.numBNetFriends or 0) + (searchResultInfo.numCharFriends or 0) + (searchResultInfo.numGuildMates or 0)) > 0 or false
      if (not filterFriends) then
        local leaderName,
          realmName = LFMPlus:GetNameRealm(searchResultInfo.leaderName)
        -- local realmName = leaderName:find("-") ~= nil and string.sub(leaderName, leaderName:find("-") + 1, string.len(leaderName)) or GetRealmName()
        local filterRole = db.activeRoleFilter and not RemainingSlotsForLocalPlayerRole(searchResultID) or false
        local filterRating =
          db.ratingFilter and not (searchResultInfo.leaderOverallDungeonScore and searchResultInfo.leaderOverallDungeonScore >= db.ratingFilterMin or false) or false
        local filterRealm = db.filterRealm and LFMPlus:checkRealm(realmName) or false
        local filterPlayer = db.filterPlayer and LFMPlus:checkPlayer(leaderName) or false
        local filterDungeon = (db.dungeonFilter and LFMPlusFrame.DD:SelectedCount() > 0) and LFMPlusFrame.dungeonList[searchResultInfo.activityID] == nil or false
        local filterActivity =
          (db.dungeonFilter and LFMPlusFrame.dungeonList[searchResultInfo.activityID] and LFMPlusFrame.DD:SelectedCount() > 0) and
          (not LFMPlusFrame.dungeonList[searchResultInfo.activityID].checked) or
          false
        if (filterRole or filterRating or filterRealm or filterDungeon or filterPlayer or filterActivity) then
          LFMPlus:addFilteredId(LFGListFrame.SearchPanel, searchResultID)
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
    -- If one has more friends, do that one first

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
    -- If we aren't sorting by anything else, just go by ID
    return searchResultID1 < searchResultID2
  end

  if (#results > 0) then
    for _, id in ipairs(results) do
      FilterSearchResults(id)
    end

    if (LFGListFrame.SearchPanel.filteredIDs) then
      LFMPlus:filterTable(LFGListFrame.SearchPanel.results, LFGListFrame.SearchPanel.filteredIDs)
      LFGListFrame.SearchPanel.filteredIDs = nil
    end
  end

  table.sort(results, SortSearchResultsCB)

  if #results > 0 then
    LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel)
  end

end

---@param entry LFGListSearchEntryTemplate
local SearchEntryUpdate = function(entry)
  if (not LFMPlus.mPlusSearch) or (not LFGListFrame.SearchPanel:IsShown()) then
    return
  end

  local resultID = entry.resultID
  local resultInfo = C_LFGList.GetSearchResultInfo(resultID)

  local numMembers = resultInfo.numMembers
  local orderIndexes = {}

  for i = 1, numMembers do
    local role,
      class = C_LFGList.GetSearchResultMemberInfo(resultID, i)
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

  local dataDisplayEnum = entry.DataDisplay.Enumerate
  -- Process each member of the group.
  for i = 1, numMembers do
    -- Icon Frames go right to left where group member 1 is Icon5 and group member 5 is Icon1.
    -- To account for this, we do some simple math to get the Icon frame for the group member we are currently working with.
    local iconNumber = (5 - i) + 1
    local class = orderIndexes[i][2]

    -- The role icons we use match for TANK and HEALER but not for DPS.
    local roleName = orderIndexes[i][4] == "DAMAGER" and "DPS" or orderIndexes[i][4]
    local classColor = RAID_CLASS_COLORS[class]
    local r,
      g,
      b,
      _ = classColor:GetRGBA()

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
    local formattedLeaderScore = LFMPlus:formatMPlusRating(resultInfo.leaderOverallDungeonScore or 0)
    entry.Name:SetText(formattedLeaderScore .. " " .. entry.Name:GetText())
    entry.ActivityName:SetWordWrap(false)
  end

  if db.shortenActivityName and ns.constants.actvityInfo[resultInfo.activityID] then
    entry.ActivityName:SetText(ns.constants.actvityInfo[resultInfo.activityID].shortName .. " (M+)")
    entry.ActivityName:SetWordWrap(false)
  end

  if db.showRealmName and LFMPlusFrame.dungeonList[resultInfo.activityID] then
    local leaderName,
      realmName = LFMPlus:GetNameRealm(resultInfo.leaderName)
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
        entry.ActivityName:SetText(entry.ActivityName:GetText() .. " " .. realmName)
        entry.ActivityName:SetWordWrap(false)
      end
    end
  end
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
          _,--tank,
          _,--healer,
          _,--damage,
          _,
          relationship,
          dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, i)

        local _,
          realmName = LFMPlus:GetNameRealm(name)

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

    local _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      dungeonScore1 = C_LFGList.GetApplicantMemberInfo(applicantInfo1.applicantID, 1)
    local _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      dungeonScore2 = C_LFGList.GetApplicantMemberInfo(applicantInfo2.applicantID, 1)

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
    LFGListApplicationViewer_UpdateResults(LFGListFrame.activePanel)
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
    _,--className,
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

  local bestRunString =
    bestDungeonScoreForEntry and ("|" .. (bestDungeonScoreForEntry.finishedSuccess and "cFF00FF00" or "cFFFF0000") .. bestDungeonScoreForEntry.bestRunLevel .. "|r") or ""
  member.DungeonScore:SetText(" " .. scoreText .. " - " .. bestRunString)

  local nameLength = 100
  if (relationship) then
    nameLength = nameLength - 22
  end

  if (member.Name:GetWidth() > nameLength) then
    member.Name:SetWidth(nameLength)
  end
end

-- Hook the minimap ping function to check for pings that may not be for eligible applicants.
local origQueueStatusMinimapButton_SetGlowLock = QueueStatusMinimapButton_SetGlowLock
QueueStatusMinimapButton_SetGlowLock = function(...)
  local s,
    lock,
    enabled,
    numPingSounds = ...
  local reallyEnabled = enabled
  if db.enabled and LFMPlus.mPlusListed and lock == "lfglist-applicant" then
    if enabled then
      if LFMPlus.newEligibleApplicant then
        LFMPlus.newEligibleApplicant = false
      else
        reallyEnabled = false
        numPingSounds = -1
      end
    end
  end
  origQueueStatusMinimapButton_SetGlowLock(s, lock, reallyEnabled, numPingSounds)
end

-- Begining functionality for adding players/realms to the addons internal flag list.
--[[ do
  -- Inspired by the RaiderIO addon.
  local LibDropDownExtension = LibStub and LibStub:GetLibrary("LibDropDownExtension-1.0", true)
  local dropdown = {
    enabled = false
  }

  function dropdown:IsEnabled()
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
    local tempName,
      tempRealm = bdropdown.name, bdropdown.server
    local name, realm, level = nil, nil, nil

    -- unit
    if not name and UnitExists(unit) then
      if UnitIsPlayer(unit) then
        name,
          realm = LFMPlus:GetNameRealm(unit)
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
          name,
            realm = LFMPlus:GetNameRealm(whisperButton.arg1)
          break
        end
      end
    end

    -- dropdown by name and realm
    if not name and tempName then
      name,
        realm = LFMPlus:GetNameRealm(tempName, tempRealm)
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

  local selectedName,
    selectedRealm,
    selectedLevel
  local unitOptions

  local function OnToggle(bdropdown, event, opt)
    if event == "OnShow" then
      if not IsValidDropDown(bdropdown) then
        return
      end
      selectedName,
        selectedRealm = GetNameRealmForDropDown(bdropdown)
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
        local name, realm = GetNameRealmForDropDown(dropdown)
        LFMPlus:showDialog(name, realm);
      end
    }
  }
  LibDropDownExtension:RegisterEvent("OnShow OnHide", OnToggle, 1, dropdown)
end ]]

local function InitializeUI()
  -- Create the frame for toggling the active role filter.
  do
    local f = LFMPlusFrame
    f.expand = true
    f.spacing = 5
    f.fixedHeight = 50

    f:SetPoint("BOTTOMRIGHT", GroupFinderFrame, "TOPRIGHT")

    f.frames = {search = {}, app = {}, all = {}}
    f.exemptIDs = {}
    f.declineButtonInfo = {}
    f.filteredIDs = {}

    f.dungeonList = {}
    f.dungeonListLoaded = false

    f.classList = {}
    f.classListLoaded = false

    f.totalResults = 0

    f.nextAppDecline = nil

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
              local name,
                className,
                _,
                _,
                _,
                _,
                tank,
                healer,
                damage,
                _,
                _,
                dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
              local shortName,
                server = LFMPlus:GetNameRealm(name)
              local formattedName = RAID_CLASS_COLORS[className]:WrapTextInColorCode(string.format(ns.constants.lengths.name, shortName))
              local roleIcons =
                string.format(
                "%s%s%s",
                CreateAtlasMarkup(tank and "roleicon-tiny-tank" or "groupfinder-icon-emptyslot", 10, 10),
                CreateAtlasMarkup(healer and "roleicon-tiny-healer" or "groupfinder-icon-emptyslot", 10, 10),
                CreateAtlasMarkup(damage and "roleicon-tiny-dps" or "groupfinder-icon-emptyslot", 10, 10)
              )

              local header = CreateAtlasMarkup(((applicantID == self.nextAppDecline and memberIdx == 1) and "pvpqueue-sidebar-nextarrow" or ""), 10, 10)
              local memberString =
                string.format("%s%s %s %s %s", header, LFMPlus:formatMPlusRating(dungeonScore), roleIcons, formattedName, string.format(ns.constants.lengths.server, server))
              table.insert(groupEntry, memberString)
            end
            self.declineButtonInfo[applicantID] = groupEntry
          end
        end
        LFMPlusFrame.declineButton:SetText(#LFMPlusFrame.filteredIDs > 0 and GREEN_FONT_COLOR:WrapTextInColorCode(tostring(#LFMPlusFrame.filteredIDs)) or 0)
        if GameTooltip:IsShown() and (GameTooltip:GetOwner():GetName() == "LFMPlusFrame.declineButton") then
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
            LFGListFrame.activePanel.RefreshButton:Click()
          end
        end
      end
    end

    f.scoreMinFrame = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")

    f.scoreMinFrame.layoutIndex = 3
    f.scoreMinFrame.leftPadding = 35
    f.scoreMinFrame.topPadding = 32
    f.scoreMinFrame.rightPadding = 15
    f.scoreMinFrame.bottomPadding = 13

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

    -- f.scoreMinFrame:SetBackdrop(f.scoreMinFrame:GetBackdrop())

    f.scoreMinFrame:SetValueStep(100)
    f.scoreMinFrame:SetObeyStepOnDrag(false)
    f.scoreMinFrame:SetSize(125, 15)
    --f.scoreMinFrame:SetPoint("RIGHT", f, "RIGHT", -15, 0)

    f.scoreMinFrame.Value = f.scoreMinFrame.Text
    f.scoreMinFrame.Value:ClearAllPoints()
    f.scoreMinFrame.Value:SetPoint("TOP", f.scoreMinFrame, "BOTTOM", 0, 3)

    f.scoreMinFrame:SetMinMaxValues(ns.constants.ratingMin, ns.constants.ratingMax)
    f.scoreMinFrame:SetDisplayValue(db.ratingFilterMin)
    f.scoreMinFrame.Low:SetText(LFMPlus:formatMPlusRating(ns.constants.ratingMin))
    f.scoreMinFrame.High:SetText(LFMPlus:formatMPlusRating(ns.constants.ratingMax))

    f:Hide()
    f.frames.search["scoreMinFrame"] = true
    f.frames.app["scoreMinFrame"] = true
  end
  do
    LFMPlusFrame.activeRoleFrame = CreateFrame("Frame", "$parent.activeRoleFrame", LFMPlusFrame)
    local f = LFMPlusFrame.activeRoleFrame

    f.layoutIndex = 1
    f.leftPadding = 15
    f.topPadding = 28
    f.rightPadding = 10
    f.bottomPadding = 10

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
        LFMPlusFrame.activeRoleFrame.roleIconGlow:Show()
      else
        LFMPlusFrame.activeRoleFrame.roleIconGlow:Hide()
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

    LFMPlusFrame.frames.search["activeRoleFrame"] = true

    f:UpdateRoleIcon()
    f:ToggleGlow()
    f:Hide()
  end

  -- Create the dropdown menu used for dungeon and class filtering.
  do
    local f = CreateFrame("Frame", "LFMPlusDD", LFMPlusFrame, "UIDropDownMenuTemplate")

    f.layoutIndex = 2
    f.leftPadding = -15
    f.topPadding = 28
    f.rightPadding = 10
    f.bottomPadding = 13
    -- 1 = Dungeons, 2 = Class, 3 = none
    f.ml = {
      "dungeonList",
      "classList",
      "noList"
    }
    f.m = 1

    function f:SelectedCount()
      local c = 0
      if f.m >= 3 then
        return c
      else
        for _, v in pairs(LFMPlusFrame[f.ml[f.m]]) do
          c = v.checked and c + 1 or c
        end
        return c
      end
    end

    local function LFMPlusDD_OnClick(self, id)
      if id == false then
        for _, v in pairs(LFMPlusFrame[f.ml[f.m]]) do
          v.checked = false
        end
      else
        LFMPlusFrame[f.ml[f.m]][id].checked = not LFMPlusFrame[f.ml[f.m]][id].checked
        UIDropDownMenu_SetSelectedValue(f, id)
      end
      if f.m == 1 then
        db.dungeonFilter = f:SelectedCount() > 0
      elseif f.m == 2 then
        db.classFilter = f:SelectedCount() > 0
      end
      UIDropDownMenu_Refresh(f)
      UIDropDownMenu_SetText(f, f:SelectedCount() > 0 and GREEN_FONT_COLOR:WrapTextInColorCode(f:SelectedCount()) or f:SelectedCount())
      UIDropDownMenu_JustifyText(f, "CENTER")
      LFMPlus:RefreshResults()
    end

    function LFMPlus.LFMPlusDD_Initialize(self)
      if (LFMPlusFrame[string.format("%sLoaded", f.ml[f.m])] == false) then
        if f.m == 2 then
          -- Build out class list.
          for i = 1, GetNumClasses() do
            local name,
              file,
              id = GetClassInfo(i)
            local coloredName = RAID_CLASS_COLORS[file]:WrapTextInColorCode(name)

            LFMPlusFrame[f.ml[f.m]][file] = {
              name = coloredName,
              id = file,
              classId = id,
              sName = name,
              checked = false
            }
            db.classFilter = false
            LFMPlusFrame[f.ml[f.m] .. "Loaded"] = true
          end
        elseif f.m == 1 then
          -- Build out dungeonList
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
            local name,
              id,
              timeLimit,
              texture,
              backgroundTexture = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
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
            local fullName,
              _,
              _,
              _,
              _,
              _,
              _,
              _,
              _,
              _,
              _,
              _,
              isMythicPlus,
              _,
              _ = C_LFGList.GetActivityInfo(activityID)
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
          LFMPlusFrame[f.ml[f.m] .. "Loaded"] = true
        end
      end

      if not LFMPlusFrame[f.ml[f.m] .. "Loaded"] then
        return
      end
      local info = UIDropDownMenu_CreateInfo()

      info.justifyH = "CENTER"
      info.isTitle = true
      info.notCheckable = true
      info.disabled = true
      info.text = f.m == 1 and DUNGEONS or CLASS
      info.owner = f
      UIDropDownMenu_AddButton(info)

      for id, item in pairs(LFMPlusFrame[f.ml[f.m]]) do
        info.isTitle = false
        info.func = LFMPlusDD_OnClick
        info.keepShownOnClick = true
        info.ignoreAsMenuSelection = true
        info.notCheckable = false
        info.disabled = false
        info.text = item.name
        info.checked = function()
          return LFMPlusFrame[f.ml[f.m]][id].checked
        end
        info.arg1 = id
        UIDropDownMenu_AddButton(info)
      end

      info.text = "Clear"
      info.notClickable = self:SelectedCount() < 1
      info.notCheckable = true
      info.arg1 = false
      UIDropDownMenu_AddSeparator()
      UIDropDownMenu_AddButton(info)
    end
    UIDropDownMenu_Initialize(f, LFMPlus.LFMPlusDD_Initialize)
    UIDropDownMenu_SetSelectedValue(f, 0)
    UIDropDownMenu_SetText(f, 0)
    UIDropDownMenu_SetWidth(f, 30, 0)
    f:Hide()

    LFMPlusFrame.DD = f
    LFMPlusFrame.frames.search["DD"] = true
    LFMPlusFrame.frames.app["DD"] = true
  end

  do
    local f = CreateFrame("Button", "$parent.declineButton", LFMPlusFrame, "SharedGoldRedButtonTemplate")
    f.layoutIndex = 1
    f.leftPadding = 15
    f.topPadding = 28
    f.rightPadding = 5
    f.bottomPadding = 13
    f.app = nil
    f:SetFrameLevel(1)
    f:SetFrameStrata("HIGH")
    f:SetPoint("CENTER", LFMPlusFrame.activeRoleFrame, "CENTER", 0, 0)
    f:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    f:SetSize(40, 25)
    f:SetText("0")
    f:SetNormalFontObject("GameFontNormalSmall")
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

function LFMPlus:ToggleFrames(frame, action)
  if db.enabled and action == "show" then
    LFMPlusFrame:Show()
    LFMPlusFrame.activeRoleFrame:UpdateRoleIcon()

    for k, _ in pairs(LFMPlusFrame.frames[frame]) do
      LFMPlusFrame[k]:Show()
    end
    LFMPlusFrame:Layout()
    UIDropDownMenu_Initialize(LFMPlusFrame.DD, LFMPlus.LFMPlusDD_Initialize)
    UIDropDownMenu_SetSelectedValue(LFMPlusFrame.DD, 0)
    UIDropDownMenu_SetText(LFMPlusFrame.DD, 0)
    self:FilterChanged()
  end

  if action == "hide" then
    LFMPlusFrame:Hide()
    for k, _ in pairs(LFMPlusFrame.frames.all) do
      LFMPlusFrame[k]:Hide()
    end
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

  LFMPlusFrame.totalResults = 0

  LFMPlusFrame.nextAppDecline = nil
  -- Dropdown Mode
  LFMPlusFrame.DD.m = 3
end

function LFMPlus:RunHooks()
  if not ns.InitHooksRan then
    LFGListFrame.SearchPanel:HookScript(
      "OnShow",
      function()
        if LFGListFrame.CategorySelection.selectedCategory == 2 then
          LFMPlusFrame.DD.m = 1
          LFMPlus:ToggleFrames("search", "show")
        end
      end
    )

    LFGListFrame.SearchPanel:HookScript(
      "OnHide",
      function()
        LFMPlusFrame.DD.m = 3
        LFMPlus:ToggleFrames("search", "hide")
      end
    )

    LFGListFrame.SearchPanel.BackButton:HookScript(
      "OnClick",
      function()
        LFMPlus:ClearValues()
      end
    )

    LFGListFrame.ApplicationViewer:HookScript(
      "OnShow",
      function()
        LFMPlusFrame.DD.m = 2
        if LFMPlus.mPlusListed then
          LFMPlus:ToggleFrames("app", "show")
        end
      end
    )

    LFGListFrame.ApplicationViewer:HookScript(
      "OnHide",
      function()
        LFMPlus:ToggleFrames("app", "hide")
      end
    )

    LFGListFrame.CategorySelection.FindGroupButton:HookScript(
      "OnClick",
      function()
        LFMPlus.mPlusSearch = LFGListFrame.CategorySelection.selectedCategory == 2
        LFMPlus.mPlusListed = false
      end
    )

    LFGListFrame.CategorySelection.StartGroupButton:HookScript(
      "OnClick",
      function(s)
        local panel = s:GetParent()
        if (not panel.selectedCategory) then
          return
        end
        --Check if the selected category ID is for dungeons and if the player has a keystone in their bags.
        if panel.selectedCategory == 2 and C_MythicPlus.GetOwnedKeystoneChallengeMapID() then
          local _,
            mapID = C_ChallengeMode.GetMapUIInfo(C_MythicPlus.GetOwnedKeystoneChallengeMapID())
          if mapID then
            LFGListEntryCreation_Select(LFGListFrame.EntryCreation, nil, nil, nil, ns.constants.mapInfo[mapID].activityId)
          end
        end
      end
    )

    hooksecurefunc("LFGListUtil_SortSearchResults", SortSearchResults)
    hooksecurefunc("LFGListSearchEntry_Update", SearchEntryUpdate)
    hooksecurefunc("LFGListUtil_SortApplicants", SortApplicants)
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", UpdateApplicantMember)
    -- hooksecurefunc("QueueStatusMinimapButton_SetGlowLock",CheckForPings)
    ns.InitHooksRan = true
  end
end

function LFMPlus:Enable()
  if not ns.SecondHookRan then
    -- Hooks for frames that may not exist when the addon done loading so we hook into a frame that should be available and run these hooks once its shown.
    PVEFrame:HookScript(
      "OnShow",
      function()
        if not ns.SecondHookRan then
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

          for _, v in pairs(LFGListFrame.SearchPanel.ScrollFrame.buttons) do
            v:HookScript(
              "OnDoubleClick",
              function()
                if db.lfgListingDoubleClick then
                  LFGListFrame.SearchPanel.SignUpButton:Click()
                end
              end
            )
          end

          LFGListApplicationDialogDescription.EditBox:HookScript(
            "OnShow",
            function()
              if db.autoFocusSignUp then
                LFGListApplicationDialogDescription.EditBox:SetFocus()
              end
            end
          )

          LFGListApplicationDialogDescription.EditBox:HookScript(
            "OnEnterPressed",
            function()
              if db.signupOnEnter then
                LFGListApplicationDialog.SignUpButton:Click()
              end
            end
          )

          LFGListFrame.ApplicationViewer.UnempoweredCover:HookScript(
            "OnShow",
            function()
              if db.hideAppViewerOverlay then
                LFGListFrame.ApplicationViewer.UnempoweredCover:Hide()
              end
            end
          )
          ns.SecondHookRan = true
        end
      end
    )
  end
  LFMPlus:RunHooks()
  ns.Init = true
end

function LFMPlus:Disable()
  db.enabled = false
end
