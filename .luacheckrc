std = "lua51"

max_line_length = 500
max_code_line_length = 500
exclude_files = {
    "libs/**/*.*",
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
	"BATTLENET_FONT_COLOR",
	"CLASS",
	"DUNGEON_SCORE_DUNGEON_RATING_OVERTIME",
	"DUNGEON_SCORE_DUNGEON_RATING",
	"DUNGEON_SCORE_LEADER",
	"DUNGEON_SCORE_PER_DUNGEON_NO_RATING",
	"DUNGEONS",
	"GRAY_FONT_COLOR",
	"GREEN_FONT_COLOR",
	"GROUP_FINDER_MYTHIC_RATING_REQ_TOOLTIP",
	"GROUP_FINDER_PVP_RATING_REQ_TOOLTIP",
	"HIGHLIGHT_FONT_COLOR",
	"HIGHLIGHT_FONT_COLOR",
	"LFG_LIST_APP_CANCELLED",
	"LFG_LIST_APP_DECLINED",
	"LFG_LIST_APP_FULL",
	"LFG_LIST_APP_INVITE_ACCEPTED",
	"LFG_LIST_APP_INVITE_DECLINED",
	"LFG_LIST_APP_INVITED",
	"LFG_LIST_APP_TIMED_OUT",
	"LFG_LIST_APP_UNEMPOWERED",
	"LFG_LIST_BOSSES_DEFEATED",
	"LFG_LIST_COMMENT_FORMAT",
	"LFG_LIST_DELISTED_FONT_COLOR",
	"LFG_LIST_ENTRY_DELISTED",
	"LFG_LIST_FRESH_FONT_COLOR",
	"LFG_LIST_GROUP_DATA_ROLE_ORDER",
	"LFG_LIST_NO_RESULTS_FOUND",
	"LFG_LIST_PENDING",
	"LFG_LIST_ROLE_CHECK",
	"LFG_LIST_SEARCH_FAILED",
	"LFG_LIST_TOOLTIP_AGE",
	"LFG_LIST_TOOLTIP_AUTO_ACCEPT",
	"LFG_LIST_TOOLTIP_CLASS_ROLE",
	"LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP",
	"LFG_LIST_TOOLTIP_HONOR_LEVEL",
	"LFG_LIST_TOOLTIP_ILVL",
	"LFG_LIST_TOOLTIP_LEADER",
	"LFG_LIST_TOOLTIP_MEMBERS_SIMPLE",
	"LFG_LIST_TOOLTIP_MEMBERS",
	"LFG_LIST_TOOLTIP_VOICE_CHAT",
	"LFG_LIST_UTIL_ALLOW_AUTO_ACCEPT_LINE",
	"LIGHTBLUE_FONT_COLOR",
	"NORMAL_FONT_COLOR",
	"PVP_RATING_GROUP_FINDER",
	"RAID_CLASS_COLORS",
	"RED_FONT_COLOR",
	"START_A_GROUP",
	--Global Functions
	"CanInspect",
	"GetClassInfo",
	"GetInspectSpecialization",
	"GetMouseFocus",
	"GetNumClasses",
	"GetRealmName",
	"GetSpecialization",
	"GetSpecializationRole",
	"GetSpecializationRoleByID",
	"GetTime",
	"GetUnitName",
	"IsShiftKeyDown",
	"NotifyInspect",
	"PVPUtil",
	"SecondsToTime",
	"tinsert",
	"tremove",
	"UnitExists",
	"UnitGUID",
	"UnitIsGroupLeader",
	--Global Widget Frames
	"GameTooltip",
	"GroupFinderFrame",
	"LFGListFrame",
	"PVEFrame",
	--Widget Functions
	"CreateAtlasMarkup",
	"CreateFrame",
	"CreateTextureMarkup",
	"GameTooltip_AddColoredLine",
	"GameTooltip_AddInstructionLine",
	"GameTooltip_AddNormalLine",
	"GameTooltip_Hide",
	"GameTooltip_SetTitle",
	"HybridScrollFrame_GetOffset",
	"HybridScrollFrame_ScrollToIndex",
	"HybridScrollFrame_Update",
	--LFG Global Functions
	"LFGListApplicationDialog_Show",
	"LFGListApplicationDialog",
	"LFGListApplicationDialogDescription",
	"LFGListApplicationViewer_UpdateAvailability",
	"LFGListApplicationViewer_UpdateResultList",
	"LFGListApplicationViewerUtil_GetButtonHeight",
	"LFGListEntryCreation_SetTitleFromActivityInfo",
	"LFGListGroupDataDisplay_Update",
	"LFGListSearchEntry_OnEnter",
	"LFGListSearchEntry_Update",
	"LFGListSearchEntry_UpdateExpiration",
	"LFGListSearchEntryUtil_GetFriendList",
	"LFGListSearchPanel_DoSearch",
	"LFGListSearchPanel_UpdateButtonStatus",
	"LFGListSearchPanel_UpdateResultList",
	"LFGListSearchPanel_UpdateResults",
	"LFGListSearchPanel_ValidateSelected",
	"LFGListUtil_GetQuestDescription",
	"LFGListUtil_IsAppEmpowered",
	"LFGListUtil_IsStatusInactive",
	"LFGListUtil_SortApplicants",
	"LFGListUtil_SortSearchResults",
	"LFGListUtil_SortSearchResultsCB",
	"LFMPlus_GetPlaystyleString",
	--Library Functions
	"DLAPI",
	"LibStub",
	--C API
	"C_ChallengeMode",
	"C_LFGList"
}
