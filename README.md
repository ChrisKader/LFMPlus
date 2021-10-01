This addon enhances the default LFG UI for Mythic+ listings with more details and provides a few quality-of-life improvements.

Items marked with ❗ a WIP.

**Added UI Elements**
* Filter applicants to your group while also being able to view filtered applicants and declining each one with one button.
* Filter out listings with no open spot for your current role.
* Filter group listings by Mythic Plus Rating (Useful for hiding LFG spam listings).
* ❗Filter group applicants by class and/or Mythic Plus Rating.
* Filter results by dungeon while also being able to use the normal search box for key level.

**Default UI Enhancements**

* Groups with friends and guild members will always show, regardless of filter settings.
* The dungeon for the key currently present in your bag will be automatically selected from the dropped down when creating a group.
* The class of each role currently in the listings group is represented as a bar below the respective icon.
* The dungeon rating of the group leader added to the listing.
* Server name added to the listing.
* ❗Specify players/realms to be flagged or filtered out.
* Dungeon names shortened to save space.
* Double-Click on listings to apply.

**Bug List**
- Scaling
- Element placement (mainly in the upper left corner of the LFGListFrame window.)


**Release Automation**
------
**Requirements**
- Configured GitHub CLI (gh auth login)
- PowerShell
- Updated notes in RELEASE.MD

**Command**: ```$tag = "vX.Y.Z"; $notes="Testing Release"; .\createZip.ps1```

**Notes**
- Replace "vX.Y.Z" with whatever tag you would like.
- `-d` and `-p` flags can be added to the commands in the script to create a draft or prerelease
    - TODO: Update script to support passing from script paramaters.

**Results**:
- A zip will be created in the `.\releases\` directory with the name `LFM+_vX.Y.Z.zip`
- If configured, a release will be created on GitHub with the same `vX.Y.Z` tag using the notes from `RELEASE.MD` and the ZIP file that was created will be attached to the created release.

**This addon does NOT use rating data from the RaiderIO addon and does NOT require the RaiderIO addon to be installed. Support for RaiderIO scoring/colors is possible option if the demand is high enough.**

**Screenshots** (These where taken with ElvUI enabled. Will update in the future to show more vanilla examples.)
![ss1](/screenshots/1.PNG?raw=true "Search Results")
![ss2](/screenshots/2.PNG?raw=true "Options")
![ss3](/screenshots/3.PNG?raw=true "Options")
![ss4](/screenshots/4.PNG?raw=true "Options")