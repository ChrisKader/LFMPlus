---@class LFMP
local LFMP = select(2,...)

LFMP.U = {
  ---@type fun(rating: number|string, short?: boolean, colored?: boolean): string
  formatMPlusRating = function(rating, short, colored)
    rating = type(rating) == "number" and rating or 0
    local returnString = tostring(rating) or "0"
    if rating == 0 then
      return "0"
    end

    if short then
      returnString = string.format(rating >= 1000 and "%.2f" or "%.0f", rating >= 1000 and rating / 1000 or rating) or returnString
      if rating >= 1000 then
        returnString = string.format("%s%s",returnString:sub(1,returnString:len()-1),"k")
      end
    end
    local scoreColor = C_ChallengeMode.GetDungeonScoreRarityColor(rating or 0)
    if scoreColor and colored and returnString then
      returnString = scoreColor:WrapTextInColorCode(returnString or "0")
    else
      return "0"
    end

    return returnString or "0"
  end
}
