---@type string
local LFMPAddonName = select(1,...)
---@class LFMP
local LFMP = select(2, ...)

LFMP.C = {}

local C = LFMP.C

C.playStyleString = {
  [1] = "",
  [2] = "Compl",
  [3] = "Time",
}

C.roleOrder = {
  TANK = 1,
  HEALER = 2,
  DAMAGER = 3
}

C.friendlyName = "LFMP"
C.ratingMin = 0
C.ratingMax = 3500

C.atlas = {
  tiny = {
    DAMAGER = "roleicon-tiny-dps",
    TANK = "roleicon-tiny-tank",
    HEALER = "roleicon-tiny-healer",
  },
  DAMAGER = "groupfinder-icon-role-large-dps",
  TANK = "groupfinder-icon-role-large-tank",
  HEALER = "groupfinder-icon-role-large-healer",
  NA = "communities-icon-redx"
}

C.declineQueueMax = 15
C.lengths = { name = "%-12s", server = "%-15s", score = "%-4s" }

C.dungeons = {
  ["PF"] = { cmID = 379, aID = 691, shortName = "PF", },
  ["DOS"] = { cmID = 377, aID = 695, shortName = "DOS", },
  ["HOA"] = { cmID = 378, aID = 699, shortName = "HOA", },
  ["MISTS"] = { cmID = 375, aID = 703, shortName = "MISTS", },
  ["SD"] = { cmID = 380, aID = 705, shortName = "SD", },
  ["SOA"] = { cmID = 381, aID = 709, shortName = "SOA", },
  ["NW"] = { cmID = 376, aID = 713, shortName = "NW", },
  ["TOP"] = { cmID = 382, aID = 717, shortName = "TOP", },
  ["STRT"] = { cmID = 391, aID = 1016, shortName = "STRT", },
  ["GMBT"] = { cmID = 392, aID = 1017, shortName = "GMBT", },
  ["WKSHP"] = { cmID = 370, aID = 683, shortName = "WKSHP", },
  ["DOCK"] = { cmID = 169, aID = 180, shortName = "DOCK", },
  ["GRIM"] = { cmID = 166, aID = 183, shortName = "GRIM", },
  ["UPPR"] = { cmID = 234, aID = 473, shortName = "UPPR", },
  ["JUNK"] = { cmID = 369, aID = 679, shortName = "JUNK", },
  ["LOWR"] = { cmID = 227, aID = 471, shortName = "LOWR", },
  ["SBG"] = { cmID = 165, aID = 1193, shortName = "SBG", },
  ["TAV"] = { cmID = 401, aID = 1180, shortName = "TAV", },
  ["TNO"] = { cmID = 400, aID = 1184, shortName = "TNO", },
  ["AA"] = { cmID = 402, aID = 1160, shortName = "AA", },
  ["COS"] = { cmID = 210, aID = 466, shortName = "COS", },
  ["HOV"] = { cmID = 200, aID = 461, shortName = "HOV", },
  ["TJS"] = { cmID = 2, aID = 1192, shortName = "TJS", },
  ["RLP"] = { cmID = 399, aID = 1176, shortName = "RLP", },
  ["BH"] = { cmID = 405, aID = 1164, shortName = "BH", },
  ["FH"] = { cmID = 245, aID = 518, shortName = "FH", },
  ["HOI"] = { cmID = 406, aID = 1168, shortName = "HOI", },
  ["UNDR"] = { cmID = 251, aID = 507, shortName = "UNDR", },
  ["NL"] = { cmID = 206, aID = 462, shortName = "NL", },
  ["NELT"] = { cmID = 404, aID = 1172, shortName = "NELT", },
  ["VP"] = { cmID = 438, aID = 1195, shortName = "VP", },
  ["ULD"] = { cmID = 403, aID = 1188, shortName = "ULD", },
 }

---@param activityId integer
---@return { cmID: integer, aID: integer, shortName: string }|nil
C.activityInfo = function(activityId)
  for _, dungeon in pairs(C.dungeons) do
    if dungeon.aID == activityId then
      return dungeon
    end
  end
end

---@param challengeModeId integer
---@return { cmID: integer, aID: integer, shortName: string }|nil
C.challengeMode = function(challengeModeId)
  for _, dungeon in pairs(C.dungeons) do
    if dungeon.cmID == challengeModeId then
      return dungeon
    end
  end
end

C.timewalk = {
  [459] = { shortName = "EOA" },
  [460] = { shortName = "DHT" },
  [462] = { shortName = "NL" },
  [464] = { shortName = "VOTW" },
  [463] = { shortName = "BRH" },
  --[466] = { shortName = "COS" },
}

C.trackedEvents = {
  ["LFG_LIST_AVAILABILITY_UPDATE"] = false,
  ["LFG_LIST_ACTIVE_ENTRY_UPDATE"] = true,
  ["LFG_LIST_ENTRY_CREATION_FAILED"] = false,
  ["LFG_LIST_SEARCH_RESULTS_RECEIVED"] = true,
  ["LFG_LIST_SEARCH_RESULT_UPDATED"] = true,
  ["LFG_LIST_SEARCH_FAILED"] = false,
  ["LFG_LIST_APPLICANT_LIST_UPDATED"] = false,
  ["LFG_LIST_APPLICANT_UPDATED"] = true,
  ["LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS"] = false,
  ["LFG_LIST_ENTRY_EXPIRED_TIMEOUT"] = false,
  ["LFG_LIST_APPLICATION_STATUS_UPDATED"] = true,
  ["LFG_GROUP_DELISTED_LEADERSHIP_CHANGE"] = false,
  ["PLAYER_SPECIALIZATION_CHANGED"] = true,
  ["PARTY_LEADER_CHANGED"] = true,
  ["GROUP_ROSTER_UPDATE"] = true
}

C.searchEntryFrames = { "classDot", "roleIcon", "classBar" }

C.defaults = {
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
      [717] = "TOP",
      [1016] = "STRT",
      [1017] = "GMBT",
      [1193] = "SBG",
      [1180] = "TAV",
      [1184] = "TNO",
      [1160] = "AA",
      [466] = "COS",
      [461] = "HOV",
      [1192] = "TJS",
      [1176] = "RLP"
    }
  }
}
