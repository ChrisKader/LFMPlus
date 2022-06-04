--Rev/Hash: @file-revision@ - @file-hash@

---@type string
local addonName,
---@type ns
ns = ...

--Debugging messages
ns.d = true

---@param message string
---@param level? number
ns.p = function(message, level)
  if not level then
    level = 1
  end

  if level == 0 and not ns.d then
    return
  end

  local header = GREEN_FONT_COLOR:WrapTextInColorCode("LFM+")

  if level == 0 then
    header = string.format("%s %s", header, RED_FONT_COLOR:WrapTextInColorCode("!DEBUG!"))
  end

  local stringToPrint = string.format("%s: %s", header, message)

  DEFAULT_CHAT_FRAME:AddMessage(stringToPrint, nil, nil, nil, 1);
end

---@class LFMPlus_Frame : Frame
---@field Layout function Layout child in the frame.

ns.p("LFMPlus.lua Start", 0)
local LFMPlus = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local LFMPLUS_EVENTS_TO_REGISTER = {
  "LFG_LIST_SEARCH_RESULTS_RECEIVED"
}

---@param self LFMPlus_Frame
function LFMPlusFrame_OnLoad(self)
  ns.p("LFMPlusFrame_OnLoad Start", 0)

  for i=1, #LFMPLUS_EVENTS_TO_REGISTER do
    ns.p("Register Event " .. LFMPLUS_EVENTS_TO_REGISTER[i], 0)
		self:RegisterEvent(LFMPLUS_EVENTS_TO_REGISTER[i]);
	end

  -- LFMPlusSearchPanelScrollFrame Setup
  self.ScrollFrame.update = function() LFMPlusListSearchPanel_UpdateResults(self); end;
  self.ScrollFrame.scrollBar.doNotHide = true;
  HybridScrollFrame_CreateButtons(self.ScrollFrame, "LFMPlusSearchEntryTemplate");

  self:Layout()
  ns.p("LFMPlusFrame_OnLoad End", 0)
end

---@param self LFMPlus_Frame
---@param event WowEvent
---@vararg string
function LFMPlusFrame_OnEvent(self, event, ...)
  if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
    ns.p("Event: LFG_LIST_SEARCH_RESULTS_RECEIVED", 0)
  end
end

---@param self LFMPlus_Frame
function LFMPlusFrame_OnShow(self)

end

---@param self LFMPlus_Frame
function LFMPlusFrame_OnHide(self)

end

--LFMPlusFrameRatingSlider Functions

---@param self LFMPlusSliderTemplate
function LFMPlusFrameRatingSlider_OnLoad(self)
  self:SetMinMaxValues(ns.constants.ratingMin, ns.constants.ratingMax)
  self:SetValue(0)
end

---@param self LFMPlusSliderTemplate
---@param value number
function LFMPlusFrameRatingSlider_OnValueChanged(self, value)
  self.noclick = true
  --LFMPDB.global.ratingFilterMin = value or 0
  --LFMPDB.global.ratingFilter = (value or 0) > 0
  self:SetValue(value)
  self.Text:SetText(value)
  self.noclick = false
end

--LFMPlusSearchPanelScrollFrame functions

function LFMPlusListSearchPanel_UpdateResults(self)
end

---LFMPlusSearchEntry functions

function LFMPlusSearchEntry_OnLoad(self)
  self:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED");
	self:RegisterEvent("LFG_ROLE_CHECK_UPDATE");
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
end

function LFMPlusSearchEntry_OnEvent(self, event, ...)
  if ( event == "LFG_LIST_SEARCH_RESULT_UPDATED" ) then
		local id = ...;
		if ( id == self.resultID ) then
			LFMPlusSearchEntry_Update(self);
		end
	elseif ( event == "LFG_ROLE_CHECK_UPDATE" ) then
		if ( self.resultID ) then
			LFMPlusSearchEntry_Update(self);
		end
	end
end

function LFMPlusSearchEntry_OnClick(self, button)
  local scrollFrame = self:GetParent():GetParent();
	if ( button == "RightButton" ) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		EasyMenu(LFGListUtil_GetSearchEntryMenu(self.resultID), LFGListFrameDropDown, self, 290, -2, "MENU");
	elseif ( scrollFrame:GetParent().selectedResult ~= self.resultID and LFGListSearchPanelUtil_CanSelectResult(self.resultID) ) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		LFGListSearchPanel_SelectResult(scrollFrame:GetParent(), self.resultID);
	end
end

function LFMPlusSearchEntry_OnEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 25, 0);
	local resultID = self.resultID;
	LFGListUtil_SetSearchEntryTooltip(GameTooltip, resultID);
	local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID);
	if(searchResultInfo.crossFactionListing) then
		LFGListSearchPanel_EvaluateTutorial(LFGListFrame.SearchPanel, self);
	end
end

function LFMPlusSearchEntry_Update(self)
end
