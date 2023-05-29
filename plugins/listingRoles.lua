---@class LFMP
local LFMP = select(2,...)

---@class CustomLFGListSearchEntry : Button
---@field lfgListSearchEntry LFGListSearchEntryTemplate
---@field DataDisplay CustomDataDisplay
---@field ExpirationTime FontString
---@field UpdateExpiration fun()
---@class CustomDataDisplay : LFGListGroupDataDisplayTemplate
---@field LeaderIcon Texture

---@class CustomLFGListSearchEntries
local customLFGListSearchEntries = {}

---@param lfgListSearchEntry LFGListSearchEntryTemplate
---@return CustomDataDisplay
local function CreateCustomDataDisplay(lfgListSearchEntry)

  ---@class CustomDataDisplay
  local customDataDisplay = CreateFrame("Frame", nil, lfgListSearchEntry.DataDisplay, "LFGListGroupDataDisplayTemplate")
  customDataDisplay:SetPoint("TOPLEFT")
  customDataDisplay:SetPoint("BOTTOMRIGHT")

  local customDataDisplayEnumerate = customDataDisplay.Enumerate

  local leaderIcon = customDataDisplayEnumerate:CreateTexture(nil, "ARTWORK")
  leaderIcon:SetSize(10, 5)
  leaderIcon:SetAtlas("groupfinder-icon-leader", false, "LINEAR")
  leaderIcon:Hide()
  customDataDisplayEnumerate.LeaderIcon = leaderIcon

  return customDataDisplay
end

---@param lfgListSearchEntry LFGListSearchEntryTemplate
---@return CustomLFGListSearchEntry
local function GetCustomLFGListSearchEntryFrame(lfgListSearchEntry)
  if not customLFGListSearchEntries[lfgListSearchEntry] then
    local customLFGListSearchEntry = CreateFrame("Button",nil, lfgListSearchEntry)
    customLFGListSearchEntry:EnableMouse(true)
    customLFGListSearchEntry:SetAllPoints()
    customLFGListSearchEntry:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    customLFGListSearchEntry.lfgListSearchEntry = lfgListSearchEntry
    customLFGListSearchEntry.resultID= lfgListSearchEntry.resultID
    customLFGListSearchEntry.DataDisplay = CreateCustomDataDisplay(lfgListSearchEntry)

    local expirationTime = customLFGListSearchEntry:CreateFontString(nil, "ARTWORK", "GameFontGreenSmall")
    expirationTime:SetPoint("TOPRIGHT", -5, -5)

    customLFGListSearchEntry.ExpirationTime = expirationTime
    function customLFGListSearchEntry:UpdateExpiration()
      if not self.lfgListSearchEntry.isApplication then
        return
      end
      local duration = 0
      local now = GetTime()
      local expiration = self.lfgListSearchEntry.expiration
      if (expiration and expiration > now) then
        duration = expiration - now
      end

      local minutes = math.floor(duration / 60)
      local seconds = duration % 60
      self.ExpirationTime:SetFormattedText("%d:%.2d", minutes, seconds);
    end

    ---@param self CustomLFGListSearchEntry
    local function CustomLFGListSearchEntry_OnDoubleClick(self)
      if self.lfgListSearchEntry.isApplication then
        C_LFGList.CancelApplication(self.lfgListSearchEntry.resultID);
      else
        LFGListApplicationDialog_Show(LFGListApplicationDialog, self.lfgListSearchEntry.resultID)
      end
    end
    customLFGListSearchEntry:SetScript("OnDoubleClick", CustomLFGListSearchEntry_OnDoubleClick)

    customLFGListSearchEntries[lfgListSearchEntry] = customLFGListSearchEntry
  end

  return customLFGListSearchEntries[lfgListSearchEntry]
end

---@param lfgListSearchEntry LFGListSearchEntryTemplate
local function UpdateCustomLFGListSearchEntryFrame(lfgListSearchEntry)
  local customLFGListSearchEntry = GetCustomLFGListSearchEntryFrame(lfgListSearchEntry)
  customLFGListSearchEntry.lfgListSearchEntry = lfgListSearchEntry
  local resultID = lfgListSearchEntry.resultID

  if not C_LFGList.HasSearchResultInfo(resultID) then
    return
  end
  customLFGListSearchEntry.lfgListSearchEntry.DataDisplay:Hide()
  customLFGListSearchEntry.DataDisplay:Show()
  customLFGListSearchEntry:UpdateExpiration()
end

hooksecurefunc('LFGListSearchEntry_Update', UpdateCustomLFGListSearchEntryFrame)
