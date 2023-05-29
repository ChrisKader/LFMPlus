---@class LFMP
local LFMP = select(2,...)

local U = LFMP.U

---@class SeasonDetailsFrame : Frame, ManagedVerticalLayoutFrameTemplate, DefaultPanelBaseTemplate, BackdropTemplate

---@param self SeasonDetailsFrame
---@param array table<integer, ChallengesDungeonIconFrameTemplate>
---@param num integer
---@param template string
local function CreateFrames(self, array, num, template)
  while (#array < num) do
    local frame = CreateFrame("Frame", nil, self, template)
  end

  for i = num + 1, #array do
    array[i]:Hide();
  end
end

---@param self SeasonDetailsFrame
---@param frames table<integer, ChallengesDungeonIconFrameTemplate>
---@param height integer
local function LineUpFrames(self, frames, height)
  local num = #frames;

  local distanceBetween = 5;
  local spacingHeight = distanceBetween * (num + 1)
  local heightRemaining = height - spacingHeight

  local calculateHeight = heightRemaining / (num);

  if frames[1] then
    frames[1].topPadding = 5
  end

  if frames[#frames + 1] then
    frames[#frames + 1].bottomPadding = 5
  end

  for i=1, #frames do
    frames[i].layoutIndex = i
    if (frames[i].Icon) then
      frames[i].Icon:SetSize(calculateHeight, calculateHeight)
    end
    frames[i]:SetSize(calculateHeight, calculateHeight)
  end

  self:Layout()
end

local function CreateUi()
  ---@class SeasonDetailsFrame
  local f = CreateFrame("Frame", nil, LFMPlusFrame,"ManagedVerticalLayoutFrameTemplate, DefaultPanelBaseTemplate, BackdropTemplate")

  f.fixedWidth = 80
  local backdropInfo = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    tileEdge = true,
    tileSize = 1,
    edgeSize = 1,
    insets = { left = 5, right = 3, top = 20, bottom = 3 },
  }
  f:SetBackdrop(backdropInfo)
  f:SetBackdropColor(0,0,0,.75)
  f.maximumHeight = GroupFinderFrame:GetHeight()
  f:SetPoint("TOPLEFT", GroupFinderFrame, "TOPRIGHT")
  f:SetPoint("BOTTOMLEFT", GroupFinderFrame, "BOTTOMRIGHT")
  f.topPadding = 20
  f.rightPadding = 0
  f.leftPadding = 20
  f.bottomPadding = 5
  f.spacing = 5
  f.expand = false
  f.DungeonIcons = {}
  f.maps = {}

  f:SetScript("OnShow",function(self)
      self:RegisterEvent("BAG_UPDATE");
      self:RegisterEvent("WEEKLY_REWARDS_UPDATE");
      self:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE");
      C_MythicPlus.RequestCurrentAffixes();
      C_MythicPlus.RequestMapInfo();
      for i = 1, #self.maps do
        C_ChallengeMode.RequestLeaders(self.maps[i]);
      end
      self:UpdateSeasonDetails()
  end)

  function f:OnHide()
    self:UnregisterEvent("BAG_UPDATE");
    self:UnregisterEvent("WEEKLY_REWARDS_UPDATE");
    self:UnregisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE");
  end

  function f:SetupSeasonDetails()
    self:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE");
    self:RegisterEvent("CHALLENGE_MODE_MEMBER_INFO_UPDATED");
    self:RegisterEvent("CHALLENGE_MODE_LEADERS_UPDATE");
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED");
    self:RegisterEvent("CHALLENGE_MODE_RESET");
    self.leadersAvailable = false;
    self.maps = C_ChallengeMode.GetMapTable();
  end

  function f:UpdateSeasonDetails()
    local sortedMaps = {}
    for i = 1, #self.maps do
      local a = C_MythicPlus.GetCurrentAffixes()
      local weeklyAffix = C_ChallengeMode.GetAffixInfo(a[1].id);
      local affixBest = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(self.maps[i]) or {}
      local inTimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(self.maps[i]);
      local level = 0;
      local dungeonScore = 0;
      for k,v in pairs(affixBest) do
        if v.name == weeklyAffix then
          level = v.level
          dungeonScore = v.score
        end
      end
      local name = C_ChallengeMode.GetMapUIInfo(self.maps[i]);
      tinsert(sortedMaps, { id = self.maps[i], level = level, dungeonScore = dungeonScore, name = name});
    end

    table.sort(sortedMaps,function(a, b)
      if(b.dungeonScore ~= a.dungeonScore) then
        return a.dungeonScore > b.dungeonScore;
      else
        return strcmputf8i(a.name, b.name) > 0;
      end
    end);

    local hasWeeklyRun = false;
	  local weeklySortedMaps = {};
    for i = 1, #self.maps do
      local _, weeklyLevel = C_MythicPlus.GetWeeklyBestForMap(self.maps[i])
      if (not weeklyLevel) then
          weeklyLevel = 0;
      else
          hasWeeklyRun = true;
      end
      tinsert(weeklySortedMaps, { id = self.maps[i], weeklyLevel = weeklyLevel});
    end

    table.sort(weeklySortedMaps, function(a, b)
      return a.weeklyLevel > b.weeklyLevel
    end);

    local frameHeight = GroupFinderFrame:GetHeight() - self.topPadding - self.bottomPadding
    local num = #sortedMaps;

    CreateFrames(self, self.DungeonIcons, num, "ChallengesDungeonIconFrameTemplate");
    LineUpFrames(self, self.DungeonIcons,frameHeight);

    for i = 1, #sortedMaps do
      local frame = self.DungeonIcons[i];
      frame:SetUp(sortedMaps[i], i == 1);
      frame:SetScript("OnEnter",function(self)
        local name = C_ChallengeMode.GetMapUIInfo(frame.mapID);
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
        GameTooltip:SetText(name, 1, 1, 1);
        local inTimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(self.mapID);
        local affixScores, overAllScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(self.mapID);
	      local isOverTimeRun = false;
        local seasonBestDurationSec, seasonBestLevel, members;

        if(overAllScore and inTimeInfo or overtimeInfo) then
          local color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(overAllScore);
          if(not color) then
            color = HIGHLIGHT_FONT_COLOR;
          end
          GameTooltip_AddNormalLine(GameTooltip, DUNGEON_SCORE_TOTAL_SCORE:format(color:WrapTextInColorCode(overAllScore)), GREEN_FONT_COLOR);
        end

        if(affixScores and #affixScores > 0) then
          for _, affixInfo in ipairs(affixScores) do
            GameTooltip_AddBlankLineToTooltip(GameTooltip);
            GameTooltip_AddNormalLine(GameTooltip, DUNGEON_SCORE_BEST_AFFIX:format(affixInfo.name));
            GameTooltip_AddColoredLine(GameTooltip, MYTHIC_PLUS_POWER_LEVEL:format(affixInfo.level), HIGHLIGHT_FONT_COLOR);
            if(affixInfo.overTime) then
              if(affixInfo.durationSec >= SECONDS_PER_HOUR) then
                GameTooltip_AddColoredLine(GameTooltip, DUNGEON_SCORE_OVERTIME_TIME:format(SecondsToClock(affixInfo.durationSec, true)), LIGHTGRAY_FONT_COLOR);
              else
                GameTooltip_AddColoredLine(GameTooltip, DUNGEON_SCORE_OVERTIME_TIME:format(SecondsToClock(affixInfo.durationSec, false)), LIGHTGRAY_FONT_COLOR);
              end
            else
              if(affixInfo.durationSec >= SECONDS_PER_HOUR) then
                GameTooltip_AddColoredLine(GameTooltip, SecondsToClock(affixInfo.durationSec, true), HIGHLIGHT_FONT_COLOR);
              else
                GameTooltip_AddColoredLine(GameTooltip, SecondsToClock(affixInfo.durationSec, false), HIGHLIGHT_FONT_COLOR);
              end
            end
          end
        end
        GameTooltip:Show();
      end)
      frame:Show();
    end
    self.TitleContainer.TitleText:SetText(U.formatMPlusRating(C_ChallengeMode.GetOverallDungeonScore() or 0,false,true))
    self:Layout()
  end

  function f:OnEvent(event)
    if (event == "CHALLENGE_MODE_RESET") then

    else
      if (event == "CHALLENGE_MODE_LEADERS_UPDATE") then
        self.leadersAvailable = true;
      end
      self:UpdateSeasonDetails();
    end
  end

  f:SetupSeasonDetails()
  f:UpdateSeasonDetails()
  f:Layout()
  f:Hide()

  LFMPlusFrame.seasonDetailsFrame = f

  LFMPlusFrame.frames.search["seasonDetailsFrame"] = true
  LFMPlusFrame.frames.app["seasonDetailsFrame"] = false
  LFMP.S.seasonDetails.uiCreated = true
end

LFMP.loadSeasonDetails = function()
  if not LFMP.S.seasonDetails.uiCreated then
    CreateUi()
  end
end
