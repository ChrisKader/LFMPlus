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
---@param region? string @Optional, will use players own region if ommited. Include to avoid ambiguity during debug mode.
---@return DataProviderCharacterProfile @Return value is nil if not found
---@overload fun(unit: UnitId):DataProviderCharacterProfile
---@overload fun(name: string, faction: number):DataProviderCharacterProfile
function RaiderIO:GetProfile(name, realm, faction, region) end

---@class EnumerateTemplate : Frame
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

---@class LFGListVoiceChatIcon : Button
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

---@class LFGListGroupDataDisplayTemplate : Frame
---@field RoleCount RoleCountNoScriptsTemplate
---@field Enumerate EnumerateTemplate
---@field PlayerCount PlayerCountTemplate

---@class ButtonText : Button

---@class UIMenuButtonStretchMixin : Button
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

---@class UIMenuButtonStretchTemplate : UIMenuButtonStretchMixin
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
---@field expiration number
---@field resultID number
---@field ActivityName FontString
---@field ApplicationBG Texture
---@field CancelButton UIMenuButtonStretchTemplate
---@field DataDisplay LFGListGroupDataDisplayTemplate
---@field ExpirationTime FontString
---@field Highlight Texture
---@field isApplication boolean
---@field Name FontString
---@field PendingLabel FontString
---@field ResultBG Texture
---@field Selected Texture
---@field Spinner LoadingSpinnerTemplate
---@field VoiceChat LFGListVoiceChatIcon

---@param resultID number
---@param index number|string
---@return string role
---@return string class
---@return string classLocalized
---@return string specLocalized
function C_LFGList.GetSearchResultMemberInfo(resultID, index)
  return "", "", "", ""
end

---@class ForbiddenFrame : Frame

---commented out because it's not used in the code
---@param frameType FrameType
---@param name? string
---@param parent? any
---@param template? TemplateType
---@param id? number
---@return ForbiddenFrame
function CreateForbiddenFrame(frameType, name, parent, template, id )
  return CreateFrame(frameType, name, parent, template, id)
end

---@class ObjectPoolMixin
---@field creationFunc fun(self):Frame
---@field resetterFunc fun(self, newObj: Frame):Frame
---@field activeObjects table<number, Frame>
---@field inactiveObjects table<number, Frame>
---@field numActiveObjects number
---@field OnLoad fun(creationFunction: fun():Frame, resetterFunction: fun():Frame)
---@field Acquire fun():Frame
---@field Release fun(obj: Frame)
---@field ReleaseAll fun(disallowed: boolean)
---@field disallowResetIfNew boolean
---@field SetResetDisallowedIfNew fun()
---@field EnumerateActive fun():table<number, Frame>
---@field GetNextActive fun(current: Frame):Frame
---@field GetNextInactive fun(current: Frame): Frame
---@field IsActive fun(object: Frame): boolean
---@field GetNumActive fun():number
---@field EnumerateInactive fun(): table<number, Frame>

---@param creationFunction fun():Frame
---@param resetterFunction fun(newObj: Frame):Frame
---@return ObjectPoolMixin
function CreateObjectPool(creationFunction, resetterFunction)
  return CreateFromMixins(ObjectPoolMixin);
end

---@class FramePoolMixin : ObjectPoolMixin
---@field frameType FrameType
---@field parent Frame|nil
---@field frameTemplate TemplateType
---@field OnLoad fun(frameType: FrameType, parent?: Frame|string, frameTemplate?: TemplateType, resetterFun: fun(newObj: Frame):Frame, forbidden: boolean, frameInitFunction: fun(frame: Frame))
---@field GetTemplate fun():TemplateType
---@class BaseLayoutFrameTemplate : Frame

---@param frameType FrameType
---@param parent Frame|nil
---@param frameTemplate TemplateType
---@param resetterFunc fun(newObj: Frame):Frame
---@param forbidden boolean
---@param frameInitFunc fun(frame: Frame)
---@return FramePoolMixin
function CreateFramePool(frameType, parent, frameTemplate, resetterFunc, forbidden, frameInitFunc)
  return CreateFromMixins(FramePoolMixin)
end

---@class BaseLayoutMixin
---@field IsLayoutFrame fun():boolean
---@field IgnoreLayoutIndex fun():boolean
---@field MarkIgnoreInLayout fun(region, ...)
---@field AddLayoutChildren fun(layoutChildren: BaseLayoutFrameTemplate, ...)
---@field GetLayoutChildren fun():table<number, BaseLayoutFrameTemplate>
---@field GetAdditionalRegions fun()
---@field Layout fun()
---@field OnUpdate fun()
---@field MarkDirty fun()
---@field MarkClean fun()
---@field IsDirty fun():boolean
---@field OnCleaned fun()

---@class LayoutMixin : BaseLayoutMixin
---@field GetPadding fun():leftPadding: number, rightPadding: number, topPadding: number, bottomPadding: number
---@field GetChildPadding fun(child):leftPadding: number, rightPadding: number, topPadding: number, bottomPadding: number
---@field CalculateFrameSize fun(childrenWidth: number, childrenHeight: number, width: number, height: number):width: number, height: number

---@class VerticalLayoutMixin
---@field LayoutChildren fun(children:BaseLayoutFrameTemplate, expandToWidth: number)

---@class VerticalLayoutFrame : LayoutMixin, VerticalLayoutMixin

---@class HorizontalLayoutMixin
---@field LayoutChildren fun(children:BaseLayoutFrameTemplate, ignored: boolean, expandToHeight: number)

---@class HorizontalLayoutFrame : BaseLayoutFrameTemplate, LayoutMixin, HorizontalLayoutMixin

---@class ResizeLayoutMixin : BaseLayoutMixin
---@field IgnoreLayoutIndex fun():boolean

---@class GridLayoutFrameSettings
---@field layoutChildren Frame[]
---@field childXPadding number
---@field childYPadding number
---@field isHorizontal boolean
---@field stride number
---@field layoutFramesGoingRight boolean
---@field layoutFramesGoingUp boolean

---@class GridLayoutFrameMixin
---@field Layout fun()
---@field oldGridSettings GridLayoutFrameSettings
---@field CacheLayoutSettings fun(layoutChildren:Frame[])
---@field ShouldUpdateLayout fun(layoutChildren:Frame[]):boolean
---@field IgnoreLayoutIndex fun():boolean

---@class ResizeLayoutFrame : BaseLayoutFrameTemplate, ResizeLayoutMixin
---@class GridLayoutFrame : ResizeLayoutFrame, GridLayoutFrameMixin

---@class ManagedLayoutFrameMixin
---@field templateType TemplateType
---@field contentFramePool FramePoolMixin
---@field OnLoad fun()
---@field SetTemplate fun(frameType: FrameType, template: TemplateType)
---@field SetContents fun(contents: Frame[])
---@field EnumerateActive fun():table<number, Frame>

---@class ContentFrameMixin
---@field SetContent fun(content:Frame)

---@class ManagedVerticalLayoutFrameTemplate : HorizontalLayoutFrame, ManagedLayoutFrameMixin
---@class ManagedHorizontalLayoutFrameTemplate : HorizontalLayoutFrame, ManagedLayoutFrameMixin

---@class NineSlicePanelTemplate


---@class TitleContainerTemplate
---@field TitleText FontString

---@class DefaultPanelBaseTemplate
---@field TitleContainer TitleContainerTemplate
---@field NineSlice NineSlicePanelTemplate

---@class ChallengesDungeonIconFrameTemplate : Frame
---@field Icon Texture
---@field HeighestLevel FontString


---@alias ScriptTypes ScriptFrame|ScriptType|ScriptButton|ScriptEditBox|ScriptScrollFrame|ScriptSlider|ScriptStatusBar

---@class AceHook-3.0
---@field Hook fun(self, object:table, method:string, handler:string|function, hookSecure: boolean)
---@field RawHook fun(self, object:table, method:string, handler:string|function, hookSecure: boolean)
---@field SecureHook fun(self, object:table, method:string, handler:string|function)\
---@field SecureRawHook fun(self, object:table, method:string, handler:string|function)
---@field HookScript fun(self, frame:Frame, script:ScriptTypes, handler:string|function)
---@field RawHookScript fun(self, frame:Frame, script:ScriptTypes, handler:string|function)
---@field SecureHookScript fun(self, frame:Frame, script:ScriptTypes, handler:string|function)
---@field Unhook fun(self, object:table, method:string|function|ScriptTypes)
---@field UnhookAll fun(self)
---@field IsHooked fun(self, object:table, method:string):boolean

---@alias RGBRange
---| 1
---| 2
---| 3
---| 4
---| 5
---| 6
---| 7
---| 8
---| 9
---| 10
---| 11
---| 12
---| 13
---| 14
---| 15
---| 16
---| 17
---| 18
---| 19
---| 20
---| 21
---| 22
---| 23
---| 24
---| 25
---| 26
---| 27
---| 28
---| 29
---| 30
---| 31
---| 32
---| 33
---| 34
---| 35
---| 36
---| 37
---| 38
---| 39
---| 40
---| 41
---| 42
---| 43
---| 44
---| 45
---| 46
---| 47
---| 48
---| 49
---| 50
---| 51
---| 52
---| 53
---| 54
---| 55
---| 56
---| 57
---| 58
---| 59
---| 60
---| 61
---| 62
---| 63
---| 64
---| 65
---| 66
---| 67
---| 68
---| 69
---| 70
---| 71
---| 72
---| 73
---| 74
---| 75
---| 76
---| 77
---| 78
---| 79
---| 80
---| 81
---| 82
---| 83
---| 84
---| 85
---| 86
---| 87
---| 88
---| 89
---| 90
---| 91
---| 92
---| 93
---| 94
---| 95
---| 96
---| 97
---| 98
---| 99
---| 100
---| 101
---| 102
---| 103
---| 104
---| 105
---| 106
---| 107
---| 108
---| 109
---| 110
---| 111
---| 112
---| 113
---| 114
---| 115
---| 116
---| 117
---| 118
---| 119
---| 120
---| 121
---| 122
---| 123
---| 124
---| 125
---| 126
---| 127
---| 128
---| 129
---| 130
---| 131
---| 132
---| 133
---| 134
---| 135
---| 136
---| 137
---| 138
---| 139
---| 140
---| 141
---| 142
---| 143
---| 144
---| 145
---| 146
---| 147
---| 148
---| 149
---| 150
---| 151
---| 152
---| 153
---| 154
---| 155
---| 156
---| 157
---| 158
---| 159
---| 160
---| 161
---| 162
---| 163
---| 164
---| 165
---| 166
---| 167
---| 168
---| 169
---| 170
---| 171
---| 172
---| 173
---| 174
---| 175
---| 176
---| 177
---| 178
---| 179
---| 180
---| 181
---| 182
---| 183
---| 184
---| 185
---| 186
---| 187
---| 188
---| 189
---| 190
---| 191
---| 192
---| 193
---| 194
---| 195
---| 196
---| 197
---| 198
---| 199
---| 200
---| 201
---| 202
---| 203
---| 204
---| 205
---| 206
---| 207
---| 208
---| 209
---| 210
---| 211
---| 212
---| 213
---| 214
---| 215
---| 216
---| 217
---| 218
---| 219
---| 220
---| 221
---| 222
---| 223
---| 224
---| 225
---| 226
---| 227
---| 228
---| 229
---| 230
---| 231
---| 232
---| 233
---| 234
---| 235
---| 236
---| 237
---| 238
---| 239
---| 240
---| 241
---| 242
---| 243
---| 244
---| 245
---| 246
---| 247
---| 248
---| 249
---| 250
---| 251
---| 252
---| 253
---| 254
---| 255

---@class NormalTexture : Texture
---@class PushedTexture : Texture
---@class DisabledTexture : Texture
---@class HighlightTexture : Texture

---@class ButtonStyle
---@field style string

---@class Button
---@field NormalTexture Texture
---@field PushedTexture Texture
---@field DisabledTexture Texture
---@field HighlightTexture Texture
---@field ButtonText FontString
---@field NormalFont Button
---@field HighlightFont ButtonStyle
---@field DisabledFont ButtonStyle
---@field NormalColor ColorInfo
---@field HighlightColor ColorInfo
---@field DisabledColor ColorInfo
---@field PushedTextOffset ColorInfo

---@class DropDownToggleButton : Button

---@class TooltipBackdropTemplate
---@field layoutType "TooltipDefaultLayout"
---@field NineSlice NineSlicePanelTemplate
---@field TooltipBackdropOnLoad fun()
---@field SetBackdropColor fun(r:RGBRange, g:RGBRange, b:RGBRange, a?:number)
---@field GetBackdropColor fun(): r:RGBRange,g:RGBRange,b:RGBRange, a:number
---@field SetBackdropBorderColor fun(r:RGBRange, g:RGBRange, b:RGBRange, a?:number)
---@field GetBackdropBorderColor fun(): r:RGBRange,g:RGBRange,b:RGBRange, a:number
---@field SetBorderBlendMode fun(blendMode: Enum.UIWidgetBlendModeType)

---@class ColorSwatchTemplate : Button
---@field SwitchBg Texture
---@field InnerBorder Texture
---@field Color Texture

---@class UIDropDownMenuButtonColorSwatch : BackdropTemplate, ColorSwatchTemplate

---@class L_UIDropDownMenuButtonTemplate : Button
---@field Hightlight Texture
---@field Check Texture
---@field UnCheck Texture
---@field Icon Texture
---@field ColorSwatch UIDropDownMenuButtonColorSwatch
---@field ExpandArrow Texture
---@field invisibleButton Button

---@class L_UIDropDownListTemplate
---@field Backdrop BackdropTemplate
---@field MenuBackdrop TooltipBackdropTemplate
---@field Button1 L_UIDropDownMenuButtonTemplate

---@class DropDownMenuButtonMixin
---@field OnEnter fun(...)
---@field OnLeave fun(...)
---@field OnMouseDown fun(button: DropDownToggleButton)

---@class UIDropDownMenuButtonScriptTemplate : DropDownToggleButton, DropDownMenuButtonMixin

---@class UIDropDownMenuTemplateButton : DropDownToggleButton, UIDropDownMenuButtonScriptTemplate

---@class L_UIDropDownMenuTemplate : Frame
---@field Left Texture
---@field Middle Texture
---@field Right Texture
---@field Text FontString
---@field Icon Texture
---@field Button UIDropDownMenuButtonScriptTemplate

---@class UIDropDownCustomMenuEntryMixin
---@field contextData table
---@field owningButton DropDownToggleButton
---@field GetPreferredEntryWidth fun():integer
---@field GetPreferredEntryHeight fun():integer
---@field OnSetOwningButton fun()
---@field SetOwningButton fun(button: DropDownToggleButton)
---@field GetOwningDropdown fun():L_UIDropDownMenuTemplate
---@field SetContextData fun(contextData: table)
---@field GetContextData fun():table

---@class UIDropDownCustomMenuEntryTemplate : Frame, UIDropDownCustomMenuEntryMixin


---@class UIDropDownMenuButtonTemplate
---@field text  string @The text of the button
---@field value any @The value that L_UIDROPDOWNMENU_MENU_VALUE is set to when the button is clicked
---@field func function @The function that is called when you click the button
---@field checked nil|boolean, function @Check the button if true or function returns true
---@field isNotRadio nil|boolean @Check the button uses radial image if false check box image if true
---@field isTitle nil|boolean @If it's a title the button is disabled and the font color is set to yellow
---@field disabled nil|boolean @Disable the button and show an invisible button that still traps the mouseover event so menu doesn't time out
---@field tooltipWhileDisabled nil, 1 @Show the tooltip, even when the button is disabled.
---@field hasArrow nil|boolean @Show the expand arrow for multilevel menus
---@field hasColorSwatch nil|boolean @Show color swatch or not, for color selection
---@field r RGBRange @Red color value of the color swatch (Between 1 and 255)
---@field g RGBRange @Green color value of the color swatch (Between 1 and 255)
---@field b RGBRange @Blue color value of the color swatch (Between 1 and 255)
---@field colorCode string @"|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
---@field swatchFunc function @function called by the color picker on color change
---@field hasOpacity nil|1 @Show the opacity slider on the colorpicker frame
---@field opacity number @Percentatge of the opacity, 1.0 is fully shown, 0 is transparent (0.0 - 1.0 )
---@field opacityFunc function @function called by the opacity slider when you change its value
---@field cancelFunc fun(previousValues) @function called by the colorpicker when you click the cancel button (it takes the previous values as its argument)
---@field notClickable nil|1 @Disable the button and color the font white
---@field notCheckable nil|1 @Shrink the size of the buttons and don't display a check box
---@field owner Frame @Dropdown frame that "owns" the current dropdownlist
---@field keepShownOnClick nil|1 @Don't hide the dropdownlist after a button is clicked
---@field tooltipTitle nil|string @Title of the tooltip shown on mouseover
---@field tooltipText nil|string @Text of the tooltip shown on mouseover
---@field tooltipWarning nil|string @Warning-style text of the tooltip shown on mouseover
---@field tooltipInstruction nil|string @Instruction-style text of the tooltip shown on mouseover
---@field tooltipOnButton nil|1 @Show the tooltip attached to the button instead of as a Newbie tooltip.
---@field tooltipBackdropStyle nil|table @Optional Backdrop style of the tooltip shown on mouseover
---@field justifyH nil|"CENTER" @Justify button text
---@field arg1 any @This is the first argument used by info.func
---@field arg2 any @This is the second argument used by info.func
---@field fontObject FontString @font object replacement for Normal and Highlight
---@field menuList table @This contains an array of info tables to be displayed as a child menu
---@field noClickSound nil|1 @Set to 1 to suppress the sound when clicking the button. The sound only plays if .func is set.
---@field padding nil|number @Number of pixels to pad the text on the right side
---@field topPadding nil|number @Extra spacing between buttons.
---@field leftPadding nil|number @Number of pixels to pad the button on the left side
---@field minWidth nil|number @Minimum width for this line
---@field customFrame UIDropDownCustomMenuEntryTemplate @Allows this button to be a completely custom frame, should inherit from UIDropDownCustomMenuEntryTemplate and override appropriate methods.
---@field icon Texture @An icon for the button.
---@field iconXOffset nil|number @Number of pixels to shift the button's icon to the left or right (positive numbers shift right, negative numbers shift left).
---@field iconTooltipTitle nil|string @Title of the tooltip shown on icon mouseover
---@field iconTooltipText nil|string @Text of the tooltip shown on icon mouseover
---@field iconTooltipBackdropStyle nil|table @Optional Backdrop style of the tooltip shown on icon mouseover
---@field mouseOverIcon Texture @An override icon when a button is moused over.
---@field ignoreAsMenuSelection nil|boolean @Never set the menu text/icon to this, even when this button is checked
---@field registerForRightClick nil|boolean @Register dropdown buttons for right clicks

---@class LibUIDropDownMenu-4.0
---@field UIDropDownMenu_InitializeHelper fun(self, frame:Frame)
---@field UIDropDownMenuButton_ShouldShowIconTooltip fun(self):boolean
---@field Create_UIDropDownMenu fun(self, name: Frame|string|nil, parent: Frame)
---@field UIDropDownMenu_Initialize fun(self, frame:Frame, initFunction: fun(self, level: number, menuList: table), displayMode: string, level: number, menuList: table)
---@field UIDropDownMenu_SetInitializeFunction fun(self, frame:Frame, initFunction: fun(self, level: number, menuList: table))
---@field UIDropDownMenu_SetDisplayMode fun(self, frame:Frame, displayMode: string)
---@field UIDropDownMenu_SetFrameStrata fun(self, frame:Frame, frameStrata: FrameStrata)
---@field UIDropDownMenu_RefreshDropDownSize fun(self)
---@field UIDropDownMenu_StartCounting fun(self, frame: Frame)
---@field UIDropDownMenu_StopCounting fun(self, frame: Frame)
---@field UIDropDownMenu_CreateInfo fun(self): {}
---@field UIDropDownMenu_CreateFrames fun(self, level: number, index: number)
---@field UIDropDownMenu_AddSeparator fun(self, level: number)
---@field UIDropDownMenu_AddSpace fun(self, level: number)
---@field UIDropDownMenu_AddButton fun(info:UIDropDownMenuButtonTemplate, level: number)
---@field UIDropDownMenu_CheckAddCustomFrame fun(self, button: UIDropDownCustomMenuEntryTemplate, info:UIDropDownMenuButtonTemplate)
---@field UIDropDownMenu_RegisterCustomFrame fun(self, customFrame: UIDropDownCustomMenuEntryTemplate)
---@field UIDropDownMenu_GetMaxButtonWidth fun(self):number
