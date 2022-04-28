local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2
---@class LibStub
---@field libs table<string,table>
---@field minor integer|nil
---@field minors table<string,integer>
local LibStub = _G[LIBSTUB_MAJOR]

if not LibStub or LibStub.minor < LIBSTUB_MINOR then
	LibStub = LibStub or {libs = {}, minors = {} }
  _G[LIBSTUB_MAJOR] = LibStub

  ---@param major string
  ---@param minor integer|string
  function LibStub:NewLibrary(major, minor)
    assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
		minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")

		local oldminor = self.minors[major]
		if oldminor and oldminor >= minor then return nil end
		self.minors[major], self.libs[major] = minor, self.libs[major] or {}
		return self.libs[major], oldminor
  end

  ---@param major string
  ---@param silent? boolean
  function LibStub:GetLibrary(major, silent)
    if not self.libs[major] and not silent then
			error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
		end
		return self.libs[major], self.minors[major]
  end

  function LibStub:IterateLibraries()
    return pairs(self.libs)
  end

  setmetatable(LibStub, { __call = LibStub.GetLibrary })
end

_G.LibStub = LibStub

---@class LFMPlus
local LFMPlus = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.LFMPlus = LFMPlus