std = "lua51"

max_line_length = 500
max_code_line_length = 500
exclude_files = {
    "/libs/",
    ".luacheckrc"
}
ignore = {
    "11./SLASH_.*", -- Setting an undefined (Slash handler) global variable
    "11./BINDING_.*", -- Setting an undefined (Keybinding header) global variable
    "113/LE_.*", -- Accessing an undefined (Lua ENUM type) global variable
    "113/NUM_LE_.*", -- Accessing an undefined (Lua ENUM type) global variable
    --"211", -- Unused local variable
    --"211/L", -- Unused local variable "L"
    --"211/CL", -- Unused local variable "CL"
    "--212", -- Unused argument
    --"213", -- Unused loop variable
    -- "231", -- Set but never accessed
    --"311", -- Value assigned to a local variable is unused
    --"314", -- Value of a field in a table literal is unused
    --"42.", -- Shadowing a local variable, an argument, a loop variable.
    --"43.", -- Shadowing an upvalue, an upvalue argument, an upvalue loop variable.
    --"542", -- An empty if branch
}
globals = {
	--Global Constants
	"NORMAL_FONT_COLOR",
	"LFG_LIST_ROLE_CHECK",
	"LFG_LIST_APP_CANCELLED",
	"RED_FONT_COLOR",
	"LFG_LIST_APP_FULL",
	"LFG_LIST_APP_DECLINED",
	"LFG_LIST_APP_TIMED_OUT",
	"LFG_LIST_APP_INVITED",
	"GREEN_FONT_COLOR",
	"LFG_LIST_APP_INVITE_ACCEPTED",
	"LFG_LIST_APP_INVITE_DECLINED",
	"LFG_LIST_PENDING",
	"GRAY_FONT_COLOR",
	"LFG_LIST_DELISTED_FONT_COLOR",
	"LFG_LIST_DELISTED_FONT_COLOR",
	"BATTLENET_FONT_COLOR",
	"LFG_LIST_FRESH_FONT_COLOR",
	"PVP_RATING_GROUP_FINDER",
	"HIGHLIGHT_FONT_COLOR",
	"DUNGEON_SCORE_LEADER",
	"HIGHLIGHT_FONT_COLOR",
	"DUNGEON_SCORE_PER_DUNGEON_NO_RATING",
	"DUNGEON_SCORE_DUNGEON_RATING",
	"DUNGEON_SCORE_DUNGEON_RATING_OVERTIME",
	"LFG_LIST_TOOLTIP_AGE",
	"LFG_LIST_TOOLTIP_MEMBERS_SIMPLE",
	"LFG_LIST_TOOLTIP_CLASS_ROLE",
	"LFG_LIST_TOOLTIP_MEMBERS",
	"LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP",
	"LFG_LIST_BOSSES_DEFEATED",
	"LFG_LIST_UTIL_ALLOW_AUTO_ACCEPT_LINE",
	"LFG_LIST_UTIL_ALLOW_AUTO_ACCEPT_LINE",
	"LFG_LIST_TOOLTIP_AUTO_ACCEPT",
	"LIGHTBLUE_FONT_COLOR",
	"LFG_LIST_ENTRY_DELISTED",
	"LFG_LIST_GROUP_DATA_ROLE_ORDER",
	"RAID_CLASS_COLORS",
	"RAID_CLASS_COLORS",
	"LFG_LIST_COMMENT_FORMAT",
	"GROUP_FINDER_MYTHIC_RATING_REQ_TOOLTIP",
	"GROUP_FINDER_PVP_RATING_REQ_TOOLTIP",
	"LFG_LIST_TOOLTIP_ILVL",
	"LFG_LIST_TOOLTIP_HONOR_LEVEL",
	"LFG_LIST_TOOLTIP_VOICE_CHAT",
	"LFG_LIST_TOOLTIP_LEADER",
	"LFG_LIST_NO_RESULTS_FOUND",
	"LFG_LIST_SEARCH_FAILED",
	"RAID_CLASS_COLORS",
	"LFG_LIST_APP_UNEMPOWERED",
	"DUNGEONS",
	"CLASS",
	--Global Functions
	"GetRealmName",
	"GetSpecializationRole",
	"GetSpecialization",
	"GetMouseFocus",
	"GetTime",
	"GetNumClasses",
	"GetClassInfo",
	"GetUnitName",
	"IsShiftKeyDown",
	"SecondsToTime",
	"tinsert",
	"tremove",
	"UnitExists",
	"PVPUtil",
	"CanInspect",
	"NotifyInspect",
	"UnitGUID",
	"GetSpecializationRoleByID",
	"GetInspectSpecialization",
	"UnitIsGroupLeader",
	--Global Widget Frames
	"PVEFrame",
	"GameTooltip",
	"GroupFinderFrame",
	"LFGListFrame",
	--Widget Functions
	"CreateAtlasMarkup",
	"CreateTextureMarkup",
	"CreateFrame",
	"GameTooltip_AddInstructionLine",
	"GameTooltip_SetTitle",
	"GameTooltip_AddColoredLine",
	"GameTooltip_AddNormalLine",
	"GameTooltip_Hide",
	"HybridScrollFrame_ScrollToIndex",
	"HybridScrollFrame_Update",
	"HybridScrollFrame_GetOffset",
	--LFG Global Functions
	"LFGListApplicationDialog_Show",
	"LFGListApplicationDialog",
	"LFGListApplicationDialogDescription",
	"LFGListApplicationDialogDescription",
	"LFGListApplicationDialogDescription",
	"LFGListApplicationDialog",
	"LFGListSearchPanel_DoSearch",
	"LFGListSearchEntry_Update",
	"LFGListUtil_IsStatusInactive",
	"LFGListUtil_IsStatusInactive",
	"LFGListUtil_IsAppEmpowered",
	"LFGListUtil_IsAppEmpowered",
	"LFGListUtil_IsAppEmpowered",
	"LFGListGroupDataDisplay_Update",
	"LFGListSearchEntry_OnEnter",
	"LFGListSearchEntry_UpdateExpiration",
	"LFGListSearchEntry_UpdateExpiration",
	"LFMPlus_GetPlaystyleString",
	"LFGListEntryCreation_SetTitleFromActivityInfo",
	"LFMPlus_GetPlaystyleString",
	"LFGListSearchEntryUtil_GetFriendList",
	"LFGListUtil_GetQuestDescription",
	"LFGListSearchEntry_OnEnter",
	"LFGListSearchPanel_UpdateResults",
	"LFGListSearchPanel_ValidateSelected",
	"LFGListSearchEntry_Update",
	"LFGListSearchPanel_UpdateButtonStatus",
	"LFGListSearchPanel_UpdateResultList",
	"LFGListUtil_SortSearchResults",
	"LFGListSearchPanel_UpdateResults",
	"LFGListSearchPanel_UpdateResultList",
	"LFGListUtil_SortSearchResultsCB",
	--Library Functions
	"LibStub",
	--C API
	"C_ChallengeMode",
	"C_LFGList"
}
