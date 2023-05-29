**[1.7.1](https://github.com/ChrisKader/LFMPlus/releases/tag/v1.7.1)**
  * Updates for DF Season 2
  * Code Cleanup

**[1.6.8](https://github.com/ChrisKader/LFMPlus/releases/tag/v1.6.7)**
  * Updates for 10.0

**[1.5.8](https://github.com/ChrisKader/LFMPlus/releases/tag/v1.5.5)**
  * Moved FixGetPlayStyleString to its own function.

**[1.5.7](https://github.com/ChrisKader/LFMPlus/releases/tag/v1.5.5)**
  * [Full Changelog](https://github.com/ChrisKader/LFMPlus/blob/main/CHANGELOG.md)
  * Added `not` to [core.lua](https://github.com/ChrisKader/LFMPlus/blob/main/core.lua#L2318)

**[1.5.6](https://github.com/ChrisKader/LFMPlus/releases/tag/v1.5.5)**
  * [Full Changelog](https://github.com/ChrisKader/LFMPlus/blob/main/CHANGELOG.md)
  * Removed old override for C_LFGList.GetPlaystyleString

**[1.5.5](https://github.com/ChrisKader/LFMPlus/releases/tag/v1.5.5)**
  * [Full Changelog](https://github.com/ChrisKader/LFMPlus/blob/main/CHANGELOG.md)
  * Updated [TOC](https://github.com/ChrisKader/LFMPlus/blob/main/LFMPlus.toc#L1) version to 9.2.0 (90200)
  * Applied a ["fix"](https://github.com/0xbs/premade-groups-filter/blob/master/FixGetPlaystyleString.lua) to allow players without an authenticator to still create groups. Thank you [0xbs](https://github.com/0xbs)
  * Removed unused TW logic
  * Clean up [core.lua](https://github.com/ChrisKader/LFMPlus/blob/main/core.lua) a bit.
  * Development
     * Removed Ketho libraries from [`settings.json`](https://github.com/ChrisKader/LFMPlus/blob/main/.vscode/settings.json) as they are applied globally.
     * Added [`extensions.json`](https://github.com/ChrisKader/LFMPlus/blob/main/.vscode/extensions.json) for recommended extensions.
     * Changed `DevReadme.md` to [`CONTRIBUTING.md`](https://github.com/ChrisKader/LFMPlus/blob/main/CONTRIBUTING.md)
        * Updated contents.

**1.5.3**
  * LFGListApplicationDialog_Show is replaced with a custom one that will not clear your application note when applying to different dungeons.
  * Double clicking on a listing with an active application will cancel your application (The same as clicking the 'Cancel' button).
  * When you have "Double-Click Sign Up" enabled, LFM+ will click the second sign up button for you (The dialog window tht shows roles).
    * This will only happen if you have a note set. Once you set a note, it will not be cleared (see the first entry of this versions change log.)
    * If you want to change your note, hold the SHIFT key will double clicking on a listing.
  * Tooltip is now anchored to the to right corner of the LFG Frame or the RaiderIO frame if shown.
  * Updated listing Data Display logic so that each Data Display under "Dungeons" is updated in the same manner.

**1.5.2**
  * Fixed [#20](https://github.com/ChrisKader/LFMPlus/issues/20): Added Streets and Gambit to selection dropdown.
  * Fixed [#17](https://github.com/ChrisKader/LFMPlus/issues/17): Updated code to check settings for double click applications.
  * Fixed [#14](https://github.com/ChrisKader/LFMPlus/issues/14): Check for showing RaiderIO frame to adjust tooltip anchor.

**1.5.1**
  * Added spec name to tooltip info.

**v1.5.0**
  * Disaled Legion TW M+ Dungeons
  * Merged [PR 13](https://github.com/ChrisKader/LFMPlus/pull/13). Thanks [WanderingFox](https://github.com/WanderingFox)

**v1.4.9**  
  * Added short names for Legion TW M+ Dungeons.

**v1.4.8**  
  * Update .pkgmeta to move the LibUIDropDownMenu library into the proper folder (up one directory).  
  * Renamed addon directory to LFMPlus.  
    * Settings may be reset as a result.  

**v1.4.7**
  * Updated dropdown menu into two sections  
    * One for Timewalking Mythic Plus  
    * One for Normal Mythic Plus  

**v1.4.6**  
  * Udates to support Timewalking Mythic Plus.  
    * Timewalking M+ dungeons are listed with * around the name and should be listed at the top.  
