--------------------------------------------------------
-- Blood Legion Raidcooldowns - Functions --
--------------------------------------------------------
if not BLCD then return end
local BLCD = BLCD
local CB = LibStub("LibCandyBar-3.0")
local Elv = IsAddOnLoaded("ElvUI")
local ACD = LibStub("AceConfigDialog-3.0") -- Also for options panel

if(Elv) then
	E, L, V, P, G =  unpack(ElvUI);
end

