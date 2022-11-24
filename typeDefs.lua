require('../RaiderIO')

--https://github.com/RaiderIO/raiderio-addon/blob/master/core.lua
---@class RaiderIO
RaiderIO = {}

---@class Raid
---@field public name string
---@field public shortName string
---@field public bossCount number

---@class DataProviderMythicKeystone
---@field public currentSeasonId number
---@field public numCharacters number
---@field public recordSizeInBytes number
---@field public encodingOrder number[]

-- hack to implement both keystone and raid classes on the dataprovider below so we do this weird inheritance
---@class DataProviderRaid : DataProviderMythicKeystone
---@field public currentRaid Raid
---@field public previousRaid Raid

---@class DataProvider : DataProviderRaid
---@field public name string
---@field public data number @1 (mythic_keystone), 2 (raid), 3 (recruitment), 4 (pvp)
---@field public region string @"eu", "kr", "tw", "us"
---@field public faction number @1 (alliance), 2 (horde)
---@field public date string @"2017-06-03T00:41:07Z"
---@field public db1 table
---@field public lookup1 table
---@field public db2 table
---@field public lookup2 table
---@field public queued boolean @Added dynamically in AddProvider - true when added, later set to false once past the queue check
---@field public desynced boolean @Added dynamically in AddProvider - nil or true if provider tables are desynced
---@field public outdated number @Added dynamically in AddProvider - nil or number of seconds past our time()
---@field public blocked number @Added dynamically in AddProvider - nil or number of seconds past our time()
---@field public blockedPurged boolean @Added dynamically in AddProvider - if true it means the provider is just an empty shell without any data

---@class DungeonInstance
---@field public id number
---@field public instance_map_id number
---@field public lfd_activity_ids number[]
---@field public name string
---@field public shortName string

---@class Dungeon : DungeonInstance
---@field public keystone_instance number
---@field public shortNameLocale string @Assigned dynamically based on the user preference regarding the short dungeon names.
---@field public index number @Assigned dynamically based on the index of the dungeon in the table.

---@class DungeonRaid : DungeonInstance
---@field public index number @Assigned dynamically based on the index of the raid in the table.

---@class SortedDungeon
---@field public dungeon Dungeon
---@field public level number @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedLevel` and `tyrannicalLevel` when possible.
---@field public chests number @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedChests` and `tyrannicalChests` when possible.
---@field public fractionalTime number @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedFractionalTime` and `tyrannicalFractionalTime` when possible. If we have client data `isEnhanced` is set and the values are then `0.0` to `1.0` is within the timer, anything above is depleted over the timer. If `isEnhanced` is false then this value is 0 to 3 where 3 is depleted, and the rest is in time.
---@field public sortOrder string @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedSortOrder` and `tyrannicalSortOrder` when possible.
---@field public fortifiedLevel number @Keystone level
---@field public fortifiedChests number @Number of medals where 1=Bronze, 2=Silver, 3=Gold
---@field public fortifiedFractionalTime number @If we have client data `isEnhanced` is set and the values are then `0.0` to `1.0` is within the timer, anything above is depleted over the timer. If `isEnhanced` is false then this value is 0 to 3 where 3 is depleted, and the rest is in time.
---@field public fortifiedSortOrder string @The sorting weight assigned this entry. Combination of level, chests and name of the dungeon.
---@field public tyrannicalLevel number @Keystone level
---@field public tyrannicalChests number @Number of medals where 1=Bronze, 2=Silver, 3=Gold
---@field public tyrannicalFractionalTime number @If we have client data `isEnhanced` is set and the values are then `0.0` to `1.0` is within the timer, anything above is depleted over the timer. If `isEnhanced` is false then this value is 0 to 3 where 3 is depleted, and the rest is in time.
---@field public tyrannicalSortOrder string @The sorting weight assigned this entry. Combination of level, chests and name of the dungeon.

---@class SortedMilestone
---@field public level number
---@field public label string
---@field public text string

---@class OrderedRolesItem
---@field public pos1 string @"tank","healer","dps"
---@field public pos2 string @"full","partial"

---@class DataProviderMythicKeystoneScore
---@field public season number @The previous season number, otherwise nil if current season
---@field public score number @The score amount
---@field public originalScore number @If set to a number, it means we did override the score but kept a backup of the original here
---@field public roles OrderedRolesItem[] @table of roles associated with the score

---@class DataProviderRaidProgress
---@field public progressCount number
---@field public difficulty number
---@field public killsPerBoss number[]
---@field public raid Raid

---@class DataProviderRaidProfile
---@field public outdated number|nil @number or nil
---@field public hasRenderableData boolean @True if we have any actual data to render in the tooltip without the profile appearing incomplete or empty.
---@field public progress DataProviderRaidProgress[]
---@field public mainProgress DataProviderRaidProgress[]
---@field public previousProgress DataProviderRaidProgress[]
---@field public sortedProgress SortedRaidProgress[]

---@class SortedRaidProgress
---@field public obsolete boolean If this evaluates truthy we hide it unless tooltip is expanded on purpose.
---@field public tier number Weighted number based on current or previous raid, difficulty and boss kill count.
---@field public isProgress boolean
---@field public isProgressPrev boolean
---@field public isMainProgress boolean
---@field public progress DataProviderRaidProgress

---@class DataProviderMythicKeystoneProfile
---@field public outdated number|nil @number or nil
---@field public hasRenderableData boolean @True if we have any actual data to render in the tooltip without the profile appearing incomplete or empty.
---@field public hasOverrideScore boolean @True if we override the score shown using in-game score data for the profile tooltip.
---@field public hasOverrideDungeonRuns boolean @True if we override the dungeon runs shown using in-game data for the profile tooltip.
---@field public blocked number|nil @number or nil
---@field public blockedPurged boolean|nil @True if the provider has been blocked and purged
---@field public softBlocked number|nil @number or nil - Only defined when the profile looked up is the players own profile
---@field public isEnhanced boolean|nil @true if client enhanced data (fractionalTime and .dungeonTimes are 1 for timed and 3 for depleted, but when enhanced it's the actual time fraction)
---@field public currentScore number
---@field public originalCurrentScore number @If set to a number, it means we did override the score but kept a backup of the original here
---@field public currentRoleOrdinalIndex number
---@field public previousScore number
---@field public previousScoreSeason number
---@field public previousRoleOrdinalIndex number
---@field public mainCurrentScore number
---@field public mainCurrentRoleOrdinalIndex number
---@field public mainPreviousScore number
---@field public mainPreviousScoreSeason number
---@field public mainPreviousRoleOrdinalIndex number
---@field public keystoneFivePlus number
---@field public keystoneTenPlus number
---@field public keystoneFifteenPlus number
---@field public keystoneTwentyPlus number
---@field public fortifiedDungeons number[]
---@field public fortifiedDungeonUpgrades number[]
---@field public fortifiedDungeonTimes number[]
---@field public tyrannicalDungeons number[]
---@field public tyrannicalDungeonUpgrades number[]
---@field public tyrannicalDungeonTimes number[]
---@field public dungeons number[] @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedDungeons` and `tyrannicalDungeons` when possible.
---@field public dungeonUpgrades number[] @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedDungeonUpgrades` and `tyrannicalDungeonUpgrades` when possible.
---@field public dungeonTimes number[] @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedDungeonTimes` and `tyrannicalDungeonTimes` when possible.
---@field public fortifiedMaxDungeonIndex number
---@field public fortifiedMaxDungeonLevel number
---@field public fortifiedMaxDungeon Dungeon
---@field public tyrannicalMaxDungeonIndex number
---@field public tyrannicalMaxDungeonLevel number
---@field public tyrannicalMaxDungeon Dungeon
---@field public maxDungeonIndex number @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedMaxDungeonIndex` and `tyrannicalMaxDungeonIndex` when possible.
---@field public maxDungeonLevel number @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedMaxDungeonLevel` and `tyrannicalMaxDungeonLevel` when possible.
---@field public maxDungeon Dungeon @Proxy table that looks up the correct weekly affix table if used. Use `fortifiedMaxDungeon` and `tyrannicalMaxDungeon` when possible.
---@field public maxDungeonUpgrades number @Proxy table that looks up the correct weekly affix table if used. Part of the override score functionality, possibly client data as well.
---@field public sortedDungeons SortedDungeon[]
---@field public sortedMilestones SortedMilestone[]
---@field public mplusCurrent DataProviderMythicKeystoneScore
---@field public mplusPrevious DataProviderMythicKeystoneScore
---@field public mplusMainCurrent DataProviderMythicKeystoneScore
---@field public mplusMainPrevious DataProviderMythicKeystoneScore

---@class RecruitmentTitle
---@field public [1] string
---@field public [2] number?

---@class RecruitmentTitlesCollection

---@class DataProviderRecruitmentProfile
---@field public outdated number|nil @number or nil
---@field public hasRenderableData boolean @True if we have any actual data to render in the tooltip without the profile appearing incomplete or empty.
---@field public titleIndex number
---@field public title RecruitmentTitle
---@field public entityType number @`0` (character), `1` (guild), `2` (team) - use `ns.RECRUITMENT_ENTITY_TYPES` for lookups
---@field public tank? boolean
---@field public healer? boolean
---@field public dps? boolean

---@class DataProviderPvpProfile
---@field public outdated number|nil @number or nil
---@field public hasRenderableData boolean @True if we have any actual data to render in the tooltip without the profile appearing incomplete or empty.

---@class DataProviderCharacterProfile
---@field public success boolean
---@field public guid string @Unique string `region faction realm name`
---@field public name string
---@field public realm string
---@field public faction number
---@field public region string
---@field public mythicKeystoneProfile DataProviderMythicKeystoneProfile
---@field public raidProfile DataProviderRaidProfile
---@field public recruitmentProfile DataProviderRecruitmentProfile
---@field public pvpProfile DataProviderPvpProfile


---@param name string
---@param realm string
---@param faction number
---@param region string @Optional, will use players own region if ommited. Include to avoid ambiguity during debug mode.
---@return DataProviderCharacterProfile @Return value is nil if not found
function RaiderIO:GetProfile(name, realm, faction, region) end

---@class EnumerateTemplate
---@field Icon1 Texture
---@field Icon2 Texture
---@field Icon3 Texture
---@field Icon4 Texture
---@field Icon5 Texture
---@field Icons table<string,Texture>

---@class PlayerCountTemplate
---@field Icon Texture
---@field Count FontString

---@class RoleCountNoScriptsTemplate
---@field DamagerIcon Texture
---@field DamagerCount FontString
---@field HealerIcon Texture
---@field HealerCount FontString
---@field TankIcon Texture
---@field TankCount FontString

---@class LFGListVoiceChatIcon
---@field Icon Texture

---@class BackgroundFrame : Frame
---@field Background Texture
---@field Framing Texture

---@class AnimFrame
---@field Circle Texture
---@field Spark Texture

---@class LoadingSpinnerTemplateAnim : AnimationGroup
---@field AnimFrame Rotation

---@class LoadingSpinnerTemplate
---@field BackgroundFrame BackgroundFrame
---@field AnimFrame AnimFrame
---@field Anim LoadingSpinnerTemplateAnim

---@class LFGListGroupDataDisplayTemplate
---@field RoleCount RoleCountNoScriptsTemplate
---@field Enumerate EnumerateTemplate
---@field PlayerCount PlayerCountTemplate

---@class ButtonText : Button

---@class UIMenuButtonStretchTemplate : Button,UIMenuButtonStretchMixin
---@field TopLeft Texture
---@field TopRight Texture
---@field BottomLeft Texture
---@field BottomRight Texture
---@field TopMiddle Texture
---@field MiddleLeft Texture
---@field MiddleRight Texture
---@field BottomMiddle Texture
---@field MiddleMiddle Texture
---@field Text ButtonText

---@class LFGListSearchEntryTemplate : Button
---@field resultID number
---@field Name FontString
---@field ResultBG Texture
---@field ApplicationBG Texture
---@field ActivityName FontString
---@field ExpirationTime FontString
---@field PendingLabel FontString
---@field Selected Texture
---@field Highlight Texture
---@field DataDisplay LFGListGroupDataDisplayTemplate
---@field VoiceChat LFGListVoiceChatIcon
---@field Spinner LoadingSpinnerTemplate
---@field CancelButton UIMenuButtonStretchTemplate

---@param resultID string
---@param index number|string
---@return string role
---@return string class
---@return string classLocalized
---@return string specLocalized
function C_LFGList.GetSearchResultMemberInfo(resultID, index) end
