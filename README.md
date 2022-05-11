# LFM+

LFM+ (Looking for Mythic Plus) enhances the default LFG UI for Mythic+ activies to make looking for, or creating, a group for keys in World of Warcraft.  

![](https://raw.githubusercontent.com/ChrisKader/LFMPlus/main/screenshots/3.png?raw=true "Addon Frame")  

**To open the options for LFM+ type "/lfm" into chat.**  

## Big Thanks
  * **[Tga123](https://github.com/Tga123/)** - Maintainer of https://github.com/Tga123/premade-filter  
  * **[WoWUIDev](https://discord.gg/t4YwvPDU)** Discord  
  * **[WoW Addons;](https://discord.gg/PztpxeAa)** Discord  
  * **[Ketho](https://github.com/Ketho)** Awesome VSCode [Plugin](https://github.com/Ketho/vscode-wow-api)!
## Addon Layout
* When multiple filters are selected, they are combined.  
* **Active Role Filter**  
    * Indicated with an icon of your current spec roll (DPS, Healer, or Tank).  
    * When enabled (**Yellow glow**), only listings with a spot open for your current role are shown.  
    * Updated when you change specs.  
* **Dungeon Dropdown**
    * Filter listings by dungeon.  
* **Class Dropdown**
    * Filter applicants by class.  
* **Minimum Score Slider**
    * Change the minimum score required for group listings or applicants.  
    * Set at intervals of 100 (100,200,300,2100,2400,3100, ect.)  
## Addon Features
All LFM+ functions apply ONLY to M+ dungeon listings.  

**"Find a Group" Frame**
  * Filter listings
    * With no open spot for your current role.  
    * By Mythic Plus Rating  
      * If you set the filter to a minimum of 100 rating, it will filter most LFG spam listings.
    * By Dungeon
  * Show Class icon/bar existing group members in listings.  

  
**Default UI Enhancements**
  * Always show groups or applicants who are friends. 
  * Add the M+ rating for the group leader to listing names.  
  * Add the server of the group leader to each listing.
  * Shorten dungeon names in listings.  
  * Double click on a listing to sign up.  
      * Auto focus the Sign Up window text box.  
      * Pressing enter after with the sign up box opened will finialize the sign up.
  * Double Click on activity categories to open the next frame.  
  * Shift-Click on activity categories to start a group.  
  * Persistant application note.
    * After your first sign up, the same note will be used for applications. Hold shift when double clicking a listing to edit the note.
  * Remove the shading overlay from the applicant viewer when you are not the leader.  

## WIP Enhancement/Features
  * Better localization support.  
  * More applicant filters
  * Ability to track players you have done keys with and record notes that can be referenced when you see that player again.  
  * Ability to add a realm and/or player to the addons internal flagging list.  
  * User specified short names for dungeons.  
  * Scaling  

**This addon does NOT use rating data from the RaiderIO addon and does NOT require the RaiderIO addon to be installed. Support for RaiderIO scoring/colors is possible if users would like it added.**
