---@type ns
local _, ns = ...


ns.constants = {
  playStyleString = {
    [1] = "",
    [2] = "Compl",
    [3] = "Time",
  },
  friendlyName = "LFMP",
  ratingMin = 0,
  ratingMax = 3500,
  atlas = {
    DAMAGER = "groupfinder-icon-role-large-dps",
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-healer",
    NA = "communities-icon-redx"
  },
  declineQueueMax = 15,
  lengths = {name = "%-12s", server = "%-15s", score = "%-4s"},
  dungeons = {
    ["PF"] = {cmID = 379, aID = 691},
    ["DOS"] = {cmID = 377, aID = 695},
    ["HOA"] = {cmID = 378, aID = 699},
    ["MOTS"] = {cmID = 375, aID = 703},
    ["SD"] = {cmID = 380, aID = 705},
    ["SOA"] = {cmID = 381, aID = 709},
    ["NW"] = {cmID = 376, aID = 713},
    ["TOP"] = {cmID = 382, aID = 717}
  },
  mapInfo = {
    [379] = {shortName = "PF", activityId = 691},
    [377] = {shortName = "DOS", activityId = 695},
    [378] = {shortName = "HOA", activityId = 699},
    [375] = {shortName = "MOTS", activityId = 703},
    [380] = {shortName = "SD", activityId = 705},
    [381] = {shortName = "SOA", activityId = 709},
    [376] = {shortName = "NW", activityId = 713},
    [382] = {shortName = "TOP", activityId = 717},
  },
  trackedEvents = {
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
    ["LFG_LIST_APPLICATION_STATUS_UPDATED"] = false,
    ["LFG_GROUP_DELISTED_LEADERSHIP_CHANGE"] = false,
    ["PLAYER_SPECIALIZATION_CHANGED"] = true,
    ["PARTY_LEADER_CHANGED"] = true,
    ["GROUP_ROSTER_UPDATE"] = true
  },
  searchEntryFrames = {"classDot", "roleIcon", "classBar"}
}

ns.constants.actvityInfo = {
  [691] = ns.constants.mapInfo[379],
  [695] = ns.constants.mapInfo[377],
  [699] = ns.constants.mapInfo[378],
  [703] = ns.constants.mapInfo[375],
  [705] = ns.constants.mapInfo[380],
  [709] = ns.constants.mapInfo[381],
  [713] = ns.constants.mapInfo[376],
  [717] = ns.constants.mapInfo[382],
}
