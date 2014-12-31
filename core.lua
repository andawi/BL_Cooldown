--------------------------------------------------------
-- Blood Legion Raidcooldowns - Core --
--------------------------------------------------------
if not BLCD then return end
local BLCD = BLCD
local CB = LibStub("LibCandyBar-3.0")
local LGIST = LibStub:GetLibrary("LibGroupInSpecT-1.1")
local AceConfig = LibStub("AceConfig-3.0") -- For the options panel
local AceDB = LibStub("AceDB-3.0") -- Makes saving things really easy
local AceDBOptions = LibStub("AceDBOptions-3.0") -- More database options

local Elv = IsAddOnLoaded("ElvUI")
local commPrefix = "BLCD"
local BLCD_VERSION = tonumber(GetAddOnMetadata("BL_Cooldown", "Version")) or 0

local E, L, V, P, G
if(Elv) then
	E, L, V, P, G = unpack(ElvUI);
end

local UnitInRaid, UnitInParty, IsInRaid, IsInGroup, UnitIsDeadOrGhost, UnitIsConnected, GetPlayerInfoByGUID, GetNumGroupMembers, GetRaidRosterInfo, UnitGUID, UnitName, UnitIsUnit, GetSpellCharges =
      UnitInRaid, UnitInParty, IsInRaid, IsInGroup, UnitIsDeadOrGhost, UnitIsConnected, GetPlayerInfoByGUID, GetNumGroupMembers, GetRaidRosterInfo, UnitGUID, UnitName, UnitIsUnit, GetSpellCharges
local ipairs, pairs, unpack, print, type =
      ipairs, pairs, unpack, print, type
local cooldownFrameicons = {}
local cooldownFrames = {}
local cooldownIndex = {}
local LList = {}
local usersRelease = {}
local bResIDs = {20484, 20707, 61999}
local redemption, feign = (GetSpellInfo(27827)), (GetSpellInfo(5384))
BLCD.resCount = 0

--------------------------------------------------------
-- Raid Roster Functions --
--------------------------------------------------------
function BLCD:OnLGIST(event, guid, unit, info)
	if event == "GroupInSpecT_Update" then
		local baseclass = info.class
		local name = info.name
		local spec_id = info.global_spec_id
		local talents = info.talents
		if not baseclass or not guid or not spec_id or not talents or not guid then return end
		local  _,classFilename = GetPlayerInfoByGUID(guid)

		BLCD['raidRoster'][guid] = BLCD['raidRoster'][guid] or {}
		BLCD['raidRoster'][guid]['name'] = name
		BLCD['raidRoster'][guid]['class'] = classFilename
		if spec_id ~= 0 then BLCD['raidRoster'][guid]['spec'] = spec_id end
		if next(talents) ~= nil then BLCD['raidRoster'][guid]['talents'] = talents end
	elseif event == "GroupInSpecT_Remove" then
		if (guid) then
			BLCD['raidRoster'][guid] = nil
		else
			BLCD['raidRoster'] = {}
		end
	end
end

local function hasHoTW(guid)
	local char = BLCD['raidRoster'][guid]
	if char['talents'][18584] or char['talents'][21714] or char['talents'][21715] or char['talents'][21716] then
		return true
	else
		return false
	end
end

function BLCD:UpdateRoster(cooldown)
	if IsInGroup() then
		local rosterCount = 0
		for guid, char in pairs(BLCD['raidRoster']) do
			if (UnitInRaid(char['name']) or UnitInParty(char['name'])) and not char['extra'] then
				if(char["class"] and string.lower(char["class"]:gsub(" ", ""))==string.lower(cooldown["class"]):gsub(" ", "")) then
					local unitalive = (not UnitIsDeadOrGhost(char['name'])) and UnitIsConnected(char['name'])
					if((cooldown["spec"] or cooldown["notspec"]) and char["spec"]) then
						if(cooldown["spec"] and char["spec"]==cooldown["spec"]) or (cooldown["notspec"] and char["spec"]~=cooldown["notspec"]) then
							BLCD.cooldownRoster[cooldown['spellID']][guid] = char['name']
							rosterCount = rosterCount + 1
						else
							BLCD.cooldownRoster[cooldown['spellID']][guid] = nil 
						end
					elseif(cooldown["talent"] and char["talents"]) then
						if(char["talents"][cooldown["talentidx"]]) then
							BLCD.cooldownRoster[cooldown['spellID']][guid] = char['name']
							rosterCount = rosterCount + 1
						else
							BLCD.cooldownRoster[cooldown['spellID']][guid] = nil 
						end
						if cooldown['name'] == "DRU_HEOFTHWI" then
							if hasHoTW(guid) then
								BLCD.cooldownRoster[108291][guid] = char['name']
								rosterCount = rosterCount + 1
							else
								BLCD.cooldownRoster[cooldown['spellID']][guid] = nil
							end
						end
					elseif(not cooldown["spec"] and not cooldown["notspec"] and not cooldown["talent"] and cooldown["class"] == char["class"]) then
						BLCD.cooldownRoster[cooldown['spellID']][guid] = char['name']
						rosterCount = rosterCount + 1
					end
					if BLCD.db.profile.availablebars and BLCD.db.profile.cooldown[cooldown.name] then
						if unitalive and BLCD.cooldownRoster[cooldown['spellID']][guid] then
							--((cooldown["spec"] and char["spec"] and char["spec"] == cooldown["spec"] or (cooldown["notspec"] and char["spec"] and char["spec"] ~= cooldown["notspec"])) or 
							--(cooldown["talent"] and char["talents"] and (char["talents"][cooldown["talentidx"]] or hasHoTW(guid))) or
							--(not cooldown["spec"] and not cooldown["notspec"] and not cooldown["talent"] and cooldown["class"] == char["class"])) then
							BLCD:CreatePausedBar(cooldown,guid)
						elseif(unitalive) then
							BLCD.cooldownRoster[cooldown['spellID']][guid] = nil
							BLCD:StopPausedBar(cooldown,guid)
						end
					end
				end
			else
				if not char['extra'] then
					BLCD.raidRoster[guid] = nil
				end
				if(BLCD.cooldownRoster[cooldown['spellID']][guid]) then
					BLCD.cooldownRoster[cooldown['spellID']][guid] = nil
					BLCD:StopPausedBar(cooldown,guid)
				end
			end
		end

		if BLCD.db.profile.hideempty then
			local i = cooldown.index
			if BLCD.db.profile.cooldown[cooldown.name] then
				if rosterCount < 1 and cooldownIndex[i] ~= nil then
					--BLCD:HandleEvents(cooldownFrames[i],false)
					BLCD:RemoveFrame(cooldownFrames[i],cooldownIndex[i]['previous'],cooldownIndex[i]['next'], cooldownFrames)
					BLCD:RemoveNode(cooldownIndex[i])
					cooldownIndex[i] = nil
				end

				if rosterCount > 0 and cooldownIndex[i] == nil then
					cooldownIndex[i] = {}
					if LList.head == nil then
						BLCD:InsertBeginning(cooldownIndex[i],i)
					else
						BLCD:InsertNode(cooldownIndex[i],i)
					end
					BLCD:InsertFrame(cooldownFrames[i],cooldownIndex[i]['previous'],cooldownIndex[i]['next'], cooldownFrames)
					--BLCD:HandleEvents(cooldownFrames[i],true)
				end
			end
		end
	else
		BLCD.cooldownRoster[cooldown['spellID']] = {}
		BLCD:StopAllBars()
		BLCD.curr[cooldown['spellID']] = {}
		BLCD.dead = {}
		BLCD.raidRoster = {}
	end
	BLCD:RearrangeBars(cooldownFrameicons[cooldown['spellID']])
end

function BLCD:DebugFunc()
	--[[for id,tabl in pairs(BLCD.cooldownRoster) do
		for guid,name in pairs(tabl) do
			print('check ', name)
			self:CheckPausedBars(BLCD.cooldowns[id],name)
		end
	end]]
	for spellid, stuff in pairs(BLCD.curr) do
		for guid, bars in pairs(stuff) do
			if bars then
				bars:Stop()
			end
		end
	end
end

local function print(...)
	DEFAULT_CHAT_FRAME:AddMessage("|cffc41f3bBLCD|r: " .. table.concat({...}, " "))
end

function BLCD:SetExtras(set)
	if set then
		local inInstance,_ = IsInInstance()
		local _,_,_,_,_,_,_,_,maxPlayers = GetInstanceInfo()
		local maxSubgroup = 8

		if maxPlayers < 40 then
			maxSubgroup = math.ceil(maxPlayers/5)
		end

		if IsInRaid() and inInstance then
			local i, cooldown
			for i=1, GetNumGroupMembers(), 1 do
				local _,_,subgroup,_,_,_,_,_,_,_,_ = GetRaidRosterInfo(i)
				local guid = UnitGUID("raid"..tostring(i))
				if BLCD["raidRoster"] and BLCD["raidRoster"][guid] then
					if subgroup > maxSubgroup then
						BLCD["raidRoster"][guid]["extra"] = true
					else
						BLCD["raidRoster"][guid]["extra"] = nil
					end
				end
			end
			for spellID,cooldown in pairs(BLCD.cooldowns) do
				if (BLCD.db.profile.cooldown[cooldown.name]) then
					BLCD:UpdateRoster(cooldown)
					local frameicon = cooldownFrameicons[spellID]
					if frameicon then frameicon.text:SetText(BLCD:GetTotalCooldown(spellID)) end
				end
			end
		end
	else
		local k, v, i, cooldown
		for k,v in pairs(BLCD["raidRoster"]) do
			if BLCD["raidRoster"][k]["extra"] then
				BLCD["raidRoster"][k]["extra"] = nil
			end
		end
		for spellID,cooldown in pairs(BLCD.cooldowns) do
			if (BLCD.db.profile.cooldown[cooldown.name] == true) then
				BLCD:UpdateRoster(cooldown)
				local frameicon = cooldownFrameicons[spellID]
				if frameicon then frameicon.text:SetText(BLCD:GetTotalCooldown(spellID)) end
			end
		end
	end
end

local grouped = nil
function BLCD:GROUP_ROSTER_UPDATE()
	BLCD:CheckVisibility()
	local groupType = (IsInGroup(2) and 3) or (IsInRaid() and 2) or (IsInGroup() and 1) -- LE_PARTY_CATEGORY_INSTANCE = 2
	if (not grouped and groupType) or (grouped and groupType and grouped ~= groupType) then
		grouped = groupType
		SendAddonMessage("BLCD", ("VQ:%.2f"):format(BLCD_VERSION), groupType == 3 and "INSTANCE_CHAT" or "RAID")
	elseif grouped and not groupType then
		grouped = nil
		wipe(usersRelease)
	end
end

function BLCD:UpdateExtras()
	if not BLCD.db.profile.autocheckextra
		or not IsInRaid()
		 then return end

	BLCD:SetExtras(true)
end
--------------------------------------------------------

-------------------------------------------------------
-- Frame Management --
-------------------------------------------------------
function BLCD:CreateBase()
	local raidcdbasemover = CreateFrame("Frame", 'BLCooldownBaseMover_Frame', UIParent)
	raidcdbasemover:SetClampedToScreen(true)
	raidcdbasemover:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                                            edgeFile = nil,
                                            tile = true, tileSize = 16, edgeSize = 16,
                                            insets = { left = 4, right = 4, top = 4, bottom = 4 }});
	raidcdbasemover:SetBackdropColor(0,0,0,1)
	BLCD:BLPoint(raidcdbasemover,BLCD.db.profile.framePoint,UIParent,BLCD.db.profile.relativePoint,BLCD.db.profile.xOffset,BLCD.db.profile.yOffset)
	BLCD:BLSize(raidcdbasemover,32*BLCD.db.profile.scale,(96)*BLCD.db.profile.scale)
	if(Elv) then
		raidcdbasemover:SetTemplate()
	end
	raidcdbasemover:SetMovable(true)
	raidcdbasemover:SetFrameStrata("HIGH")
	raidcdbasemover:SetScript("OnDragStart", function(self) self:StartMoving() end)
	raidcdbasemover:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	raidcdbasemover:Hide()

	local raidcdbase = CreateFrame("Frame", 'BLCooldownBase_Frame', UIParent)
	BLCD:BLSize(raidcdbase,32*BLCD.db.profile.scale,(96)*BLCD.db.profile.scale)
	BLCD:BLPoint(raidcdbase,'TOPLEFT', raidcdbasemover, 'TOPLEFT')
	raidcdbase:SetClampedToScreen(true)

	BLCD:RegisterBucketEvent("GROUP_ROSTER_UPDATE", 3, "UpdateExtras")

	BLCD.baseFrame = raidcdbase
	BLCD.locked = true
	BLCD:CheckVisibility()
end

function BLCD:CreateCooldown(index, cooldown)
	local frame = CreateFrame("Frame", 'BLCooldown'..index, BLCooldownBase_Frame);
	BLCD:BLHeight(frame,28*BLCD.db.profile.scale);
	BLCD:BLWidth(frame,145*BLCD.db.profile.scale);
	frame:SetClampedToScreen(true);
	frame.index = index

	local frameicon = CreateFrame("Button", 'BLCooldownIcon'..index, BLCooldownBase_Frame);

	if(Elv) then
		frameicon:SetTemplate()
	else
		frameicon:SetBackdrop({nil, edgeFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0}})
	end
	local classcolor = RAID_CLASS_COLORS[string.upper(cooldown.class):gsub(" ", "")]
	frameicon:SetBackdropBorderColor(classcolor.r,classcolor.g,classcolor.b)
	frameicon:SetParent(frame)
	frameicon.bars = {}
	BLCD:BLSize(frameicon,28*BLCD.db.profile.scale,28*BLCD.db.profile.scale)
	frameicon:SetClampedToScreen(true);

	local previousIndex = cooldownIndex[index].previous
	BLCD:SetBarGrowthDirection(frame, frameicon, previousIndex)

	frameicon.icon = frameicon:CreateTexture(nil, "OVERLAY");
	frameicon.icon:SetTexCoord(unpack(BLCD.TexCoords));
	frameicon.icon:SetTexture(select(3, GetSpellInfo(cooldown['spellID'])));
	BLCD:BLPoint(frameicon.icon,'TOPLEFT', 2, -2)
	BLCD:BLPoint(frameicon.icon,'BOTTOMRIGHT', -2, 2)

	frameicon.text = frameicon:CreateFontString(nil, 'OVERLAY')
	BLCD:BLFontTemplate(frameicon.text, 20*BLCD.db.profile.scale, 'OUTLINE')
	BLCD:BLPoint(frameicon.text, "CENTER", frameicon, "CENTER", 1, 0)
	
	local id = cooldown['spellID']
	if id == 20484 or id == 20707 or id == 61999 then
		frameicon.cooldown = CreateFrame("Cooldown", "BLCooldownIcon"..index.."Cooldown", frameicon, "CooldownFrameTemplate")
		frameicon.cooldown:SetAllPoints()
		frameicon.cooldown:SetSwipeTexture("Interface\\Garrison\\Garr_TimerFill-Upgrade")
	end
	cooldownFrameicons[cooldown['spellID']] = frameicon
	--BLCD.cooldownFrameicons[cooldown['spellID']] = frameicon
	--BLCD:UpdateCooldown(frame,event,cooldown,frameicon.text,frameicon)
 	
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PARTY_MEMBER_ENABLE")
	frame:RegisterEvent("PARTY_MEMBER_DISABLE")
	frame:RegisterEvent("UNIT_CONNECTION")

	LGIST.RegisterCallback (frame, "GroupInSpecT_Update", function(event, ...)
		-- Delay these as it's creating a race condition with the callback set up in OnInitialization()
		BLCD:ScheduleTimer("UpdateRoster", .4, cooldown)
		BLCD:ScheduleTimer("UpdateCooldown", .5, frame,event,cooldown,frameicon.text,frameicon, ...)
		--BLCD:UpdateRoster(cooldown)
		--BLCD:UpdateCooldown(frame,event,cooldown,frameicon.text,frameicon, ...)
	end)

	LGIST.RegisterCallback (frame, "GroupInSpecT_Remove", function(event, ...)
		BLCD:ScheduleTimer("UpdateRoster", .4, cooldown)
		BLCD:ScheduleTimer("UpdateCooldown", .5, frame,event,cooldown,frameicon.text,frameicon, ...)
		--BLCD:UpdateRoster(cooldown)
		--BLCD:UpdateCooldown(frame,event,cooldown,frameicon.text,frameicon, ...)
	end)

	local function CleanBar(callback, bar)
	local a = bar:Get("raidcooldowns:anchor") --'a' is frameicon
	if a and a.bars and a.bars[bar] then
		a.bars[bar] = nil

		local bd = bar.candyBarBackdrop
		bd:Hide()
		if bd.iborder then
			bd.iborder:Hide()
			bd.oborder:Hide()
		end
		--bar:SetTexture(nil)
		local guid = bar:Get("raidcooldowns:key")
		local spell = bar:Get("raidcooldowns:spell")
		local cooldown = bar:Get("raidcooldowns:cooldown")
		local caster = bar:Get("raidcooldowns:caster")
		--[[if BLCD['handles'] and BLCD["handles"][guid] and BLCD["handles"][guid][spell] then
			BLCD['handles'][guid][spell] = nil
		end]]
		BLCD.curr[cooldown['spellID']][guid] = nil;

		if(BLCD.db.profile.cdannounce and BLCD.dead[caster] == 0) then
			local name = select(1, GetSpellInfo(cooldown['spellID']))
			local message = caster.."'s ".. GetSpellLink(cooldown['spellID']).. " is ready!"
			if BLCD.db.profile.announcechannel then
				local list = {GetChannelList()}
				local channel = BLCD.db.profile.customchan
				for i = 1,#list/2 do
					if list[i*2] == channel then
						SendChatMessage(message ,"CHANNEL", nil, list[(i*2)-1]);
					end
				end
			elseif IsInRaid() or IsInGroup(2) then
				SendChatMessage(message ,IsInGroup(2) and "INSTANCE_CHAT" or "RAID");
			elseif IsInGroup() then
				SendChatMessage(message ,"PARTY");
			else
				SendChatMessage(message ,"SAY");
			end
		end

		if BLCD.db.profile.availablebars and BLCD.db.profile.cooldown[cooldown.name] and a:IsVisible() then
			local unitalive = (not UnitIsDeadOrGhost(caster) and UnitIsConnected(caster))
			if BLCD.cooldownRoster[cooldown['spellID']][guid] and unitalive then
				BLCD:CreatePausedBar(cooldown,guid)
			end
		end
		BLCD:RearrangeBars(a)
		a.text:SetText(BLCD:GetTotalCooldown(cooldown['spellID']))
	end
	end

	CB.RegisterCallback(self, "LibCandyBar_Stop", CleanBar)

	frameicon:SetScript("OnEnter", function(self,event, ...)
		BLCD:OnEnter(self, cooldown, BLCD.cooldownRoster[cooldown['spellID']], BLCD.curr[cooldown['spellID']])
   	end);

	frameicon:SetScript("PostClick", function(self,event, ...)
		BLCD:PostClick(self, cooldown, BLCD.cooldownRoster[cooldown['spellID']], BLCD.curr[cooldown['spellID']])
	end);

 	frameicon:SetScript("OnLeave", function(self,event, ...)
		BLCD:OnLeave(self)
   	end);

	frame:SetScript("OnEvent", function(self,event, ...)
		BLCD:UpdateCooldown(frame,event,cooldown,frameicon.text,frameicon, ...)
 	end);

	frame:Show()

	return frame
end

function BLCD:CreateResFrame()
	local frame = CreateFrame("Frame", 'BLCooldownBattleRes', BLCooldownBase_Frame);
	BLCD:BLSize(frame,35*BLCD.db.profile.scale,30*BLCD.db.profile.scale);
	frame:SetClampedToScreen(true);
	BLCD:BLPoint(frame,'BOTTOM', 'BLCooldownBase_Frame', 'TOP', 0, 3);

	local frameicon = CreateFrame("Button", 'BLCooldownIconBattleRes', BLCooldownBase_Frame);

	if(Elv) then
		frameicon:SetTemplate()
	else
		frameicon:SetBackdrop({nil, edgeFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0}})
	end
	frameicon:SetBackdropBorderColor(1,1,1)
	frameicon:SetParent(frame)
	BLCD:BLSize(frameicon,35*BLCD.db.profile.scale,30*BLCD.db.profile.scale)
	frameicon:SetClampedToScreen(true);
	BLCD:BLPoint(frameicon,'TOPRIGHT', frame, 'TOPRIGHT');

	frameicon.icon = frameicon:CreateTexture(nil, "OVERLAY");
	frameicon.icon:SetTexCoord(unpack(BLCD.TexCoords));
	BLCD:BLPoint(frameicon.icon,'TOPLEFT', 2, -2)
	BLCD:BLPoint(frameicon.icon,'BOTTOMRIGHT', -2, 2)

	frameicon.text = frameicon:CreateFontString(nil, 'OVERLAY')
	BLCD:BLFontTemplate(frameicon.text, 14*BLCD.db.profile.scale, 'OUTLINE')
	BLCD:BLPoint(frameicon.text, "CENTER", frameicon, "CENTER", 2, 0)
	frameicon.text:SetFormattedText("%d\n%d:%02d", 0, 0, 0)
	--frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");]]


	BLCD.resFrame = frame
	BLCD.resFrameIcon = frameicon
	-- frameicon:SetScript("OnEnter", function(self,event, ...)
		-- BLCD:OnEnter(self, cooldown, BLCD.cooldownRoster[cooldown['spellID']], BLCD.curr[cooldown['spellID']])
   	-- end);

	-- frameicon:SetScript("PostClick", function(self,event, ...)
		-- BLCD:PostClick(self, cooldown, BLCD.cooldownRoster[cooldown['spellID']], BLCD.curr[cooldown['spellID']])
	-- end);

 	-- frameicon:SetScript("OnLeave", function(self,event, ...)
		-- BLCD:OnLeave(self)
   	-- end);

	-- frame:SetScript("OnEvent", function(self,event, ...)
		-- BLCD:UpdateCooldown(frame,event,cooldown,frameicon.text,frameicon, ...)
 	-- end);
	frame:Hide()
end

function BLCD:HandleEvents(frame,register)
	--[[if register then
		if not frame:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED") then
			frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
			frame:RegisterEvent("GROUP_ROSTER_UPDATE")
			frame:RegisterEvent("ENCOUNTER_END")
			frame:RegisterEvent("PARTY_MEMBER_ENABLE")
			frame:RegisterEvent("PARTY_MEMBER_DISABLE")
			frame:RegisterEvent("UNIT_CONNECTION")
			frame:RegisterEvent("UNIT_HEALTH")
		end
	else
		frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
		frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
		frame:UnregisterEvent("ENCOUNTER_END")
		frame:UnregisterEvent("PARTY_MEMBER_ENABLE")
		frame:UnregisterEvent("PARTY_MEMBER_DISABLE")
		frame:UnregisterEvent("UNIT_CONNECTION")
		frame:UnregisterEvent("UNIT_HEALTH")
	end]]
end

function BLCD:CreatePausedBar(cooldown,guid)
	if BLCD.curr[cooldown['spellID']][guid] then
		local bar = BLCD.curr[cooldown['spellID']][guid] 
		bar:Show()
	else 
		local duration = cooldown['CD']
		local spellID = cooldown['spellID']
		local spellName = GetSpellInfo(spellID)
		local caster = select(6,GetPlayerInfoByGUID(guid))
		local bar = BLCD:CreateBar(nil, cooldown, caster, cooldownFrameicons[spellID], guid, duration - 1, spellName)
		BLCD.curr[spellID][guid] = bar
		bar:SetTimeVisibility(false)
		bar.candyBarBar:SetMinMaxValues(0, bar.remaining)
		bar.candyBarBar:SetValue(bar.remaining)
		bar:Start()
		bar.updater:Pause()
		bar:EnableMouse(true)
		bar:SetScript("OnMouseDown", function(self,event, ...) SendChatMessage("Use "..GetSpellLink(self:Get("raidcooldowns:spell")).." please!", "WHISPER", "Common", GetUnitName(self:Get("raidcooldowns:caster"),1)) end)
	end
end

function BLCD:StopAllBars()
	for spellId, guid in pairs(BLCD.curr) do
		for guid, bar in pairs(guid) do
			bar:Stop()
		end
	end
end

function BLCD:StopAllPausedBars()
	local spellId,bar,frame
	for spellId, guid in pairs(BLCD.curr) do
		for i, bar in pairs(guid) do
			if not bar.updater:IsPlaying() then bar:Stop() end
		end
	end
end

function BLCD:UpdateBarGrowthDirection()
	local i, cooldown
	for i, cooldown in pairs(BLCD.cooldowns) do
		if (BLCD.db.profile.cooldown[cooldown.name] == true) then
			local frameicon = cooldownFrameicons[cooldown['spellID']]
			BLCD:RearrangeBars(frameicon)
		end
	end
end

function BLCD:RedrawCDList()
	local spellID, frame
	for spellID, frame in pairs(cooldownFrames) do
		if frame then
			frame:Hide()
			frame:ClearAllPoints()
		end
	end

	local IsTail = LList['head']
	while IsTail ~= nil do
		BLCD:RepositionFrames(cooldownFrames[IsTail],cooldownIndex[IsTail]['previous'])
		cooldownFrames[IsTail]:Show()
		IsTail = cooldownIndex[IsTail]['next']
	end
end

function BLCD:AvailableBars(value)
	if value then --create bars
		for spell, tabled in pairs(BLCD.cooldownRoster) do
			for sourceGUID, sourceName in pairs(tabled) do
				local unitalive = not (UnitIsDeadOrGhost(sourceName) or not UnitIsConnected(sourceName) or false)
				if unitalive then
					if not(BLCD.curr[spell][sourceGUID]) then
						local cooldown = BLCD.cooldowns[spell]
						if cooldown['spellID'] == spell then
							BLCD:CreatePausedBar(cooldown,sourceGUID)
							BLCD:RearrangeBars(cooldownFrameicons[spell])
						end
					end
				end
			end
		end
	elseif not value then --stop and recycle paused bars
		BLCD:StopAllPausedBars()
	end
end

function BLCD:RecolorBars(value)
	local spellId,bar,frame,cooldown
	for spellId, frame in pairs(cooldownFrameicons) do
		for bar in pairs(frame.bars) do
			if value then
				cooldown = bar:Get("raidcooldowns:cooldown")
				local color = RAID_CLASS_COLORS[cooldown['class']] or {r=0.5; g=0.5; b=0.5}
				bar:SetColor(color.r,color.g,color.b,1)
			else
				bar:SetColor(.5,.5,.5,1)
			end
		end
	end
end

function BLCD:DynamicCooldownFrame()--key,value)
	local wasVisible = BLCD.baseFrame:IsVisible()
	BLCD.baseFrame:Show()
	local i
	for ID, cooldown in pairs(BLCD.cooldowns) do
		i = cooldown.index
		if ((not BLCD.db.profile.cooldown[cooldown.name]) and cooldownIndex[i] ~= nil) then  -- cooldown removed
			BLCD.active = BLCD.active - 1
			--index = index + 1;
			--BLCD.curr[cooldown['spellID']] = {}
			--BLCD.cooldownRoster[cooldown['spellID']] = {}
			--BLCD:HandleEvents(cooldownFrames[i],false)
			-- Linked List management
			BLCD:RemoveFrame(cooldownFrames[i],cooldownIndex[i]['previous'],cooldownIndex[i]['next'], cooldownFrames)
			BLCD:RemoveNode(cooldownIndex[i])
			cooldownIndex[i] = nil
		end

		if (BLCD.db.profile.cooldown[cooldown.name] and cooldownIndex[i] == nil) then  -- cooldown added
			BLCD.active = BLCD.active + 1
			if not BLCD.curr[cooldown['spellID']] then BLCD.curr[cooldown['spellID']] = {} end
			if not BLCD.cooldownRoster[cooldown['spellID']] then BLCD.cooldownRoster[cooldown['spellID']] = {} end

			-- Linked List management
			cooldownIndex[i] = {}
			if LList.head == nil then
				BLCD:InsertBeginning(cooldownIndex[i],i)
			else
				BLCD:InsertNode(cooldownIndex[i],i)
			end
			--
			if cooldownFrames[i] == nil then
				cooldownFrames[i] = BLCD:CreateCooldown(i, cooldown);
			end
			BLCD:InsertFrame(cooldownFrames[i],cooldownIndex[i]['previous'],cooldownIndex[i]['next'], cooldownFrames)
			--BLCD:HandleEvents(cooldownFrames[i],false)

		end
		if (BLCD.db.profile.cooldown[cooldown.name]) then
			BLCD:UpdateRoster(cooldown)
			local frameicon = cooldownFrameicons[cooldown['spellID']]
			if frameicon then frameicon.text:SetText(BLCD:GetTotalCooldown(cooldown['spellID'])) end
		end
	end
	if not wasVisible then BLCD.baseFrame:Hide() end
end

--------------------------------------------------------

--------------------------------------------------------
-- Cooldown Management --
--------------------------------------------------------
function BLCD:UpdateCooldown(frame,event,cooldown,text,frameicon, ...)
	if(event == "COMBAT_LOG_EVENT_UNFILTERED") then
		local timestamp, eventType , _, soureGUID, sourceName, srcFlags, _, destGUID, destName, dstFlags, _, spellId, spellName = select(1, ...)
		if (spellId == 108292 or spellId == 108293 or spellId == 108294) and cooldown['spellID'] == 108291 then -- Stupid Heart of the Wild with it's 4 ID's
			spellId = 108291
		elseif spellId == 106898 and cooldown['spellID'] == 77761 then
			spellId = 77761
		end
		local group = bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE, COMBATLOG_OBJECT_AFFILIATION_PARTY, COMBATLOG_OBJECT_AFFILIATION_RAID)
		if(eventType == cooldown['succ'] and spellId == cooldown['spellID']) and bit.band(srcFlags, group) ~= 0 then
			if (BLCD['raidRoster'][soureGUID]  and not BLCD['raidRoster'][soureGUID]['extra']) then
				local duration = cooldown['CD']
				local index = frame.index
				BLCD:StartCD(frame,cooldown,text,soureGUID,sourceName,frameicon, spellName,duration,false,destName)
				local data = {{spellID = cooldown['spellID'], name = cooldown['name']},soureGUID,sourceName,spellName,duration,index}
				BLCD:SendCommand(data)
	            text:SetText(BLCD:GetTotalCooldown(spellId))
			end
		elseif (eventType == "UNIT_DIED") then
			if bit.band(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 and bit.band(dstFlags, group) ~= 0 and not UnitIsFeignDeath(destName) and not UnitBuff(destName, redemption) and not UnitBuff(destName, feign) then
				destName = UnitName(destName)
				BLCD.dead[destName] = 1
				BLCD:CheckPausedBars(cooldown, destName)
				text:SetText(BLCD:GetTotalCooldown(cooldown['spellID']))
			end
		end
	elseif(event == "PARTY_MEMBER_ENABLE" or event == "PARTY_MEMBER_DISABLE" or event == "UNIT_CONNECTION") then
		local unit = ...
		BLCD:CheckPausedBars(cooldown,unit)
		text:SetText(BLCD:GetTotalCooldown(cooldown['spellID']))
	elseif(event =="GROUP_ROSTER_UPDATE") then
	    local partyType = BLCD:GetPartyType()
	    if(partyType=="none") then
	        BLCD:CancelBars(cooldown['spellID'])
	        BLCD.curr[cooldown['spellID']]={}
	        BLCD.cooldownRoster[cooldown['spellID']] = {}
	        BLCD:CheckVisibility()
	    end
	    text:SetText(BLCD:GetTotalCooldown(cooldown['spellID']))
    elseif(event =="GroupInSpecT_Update") then
	    text:SetText(BLCD:GetTotalCooldown(cooldown['spellID']))
	end
end

function BLCD:StartCD(frame,cooldown,text,guid,caster,frameicon,spellName,duration,fromComms,destName)
	if(BLCD.db.profile.castannounce) then
		local name = select(1, GetSpellInfo(cooldown['spellID']))
		local message = caster.." casts ".. GetSpellLink(cooldown['spellID'])
		if destName then message = message .. " on " .. destName end
		if BLCD.db.profile.announcechannel then
			local list = {GetChannelList()}
			local channel = BLCD.db.profile.customchan
			for i = 1,#list/2 do
				if list[i*2] == channel then
					SendChatMessage(message ,"CHANNEL", nil, list[(i*2)-1]);
				end
			end
		elseif IsInRaid() or IsInGroup(2) then
			SendChatMessage(message ,IsInGroup(2) and "INSTANCE_CHAT" or "RAID");
		elseif IsInGroup() then
			SendChatMessage(message ,"PARTY");
		else
			SendChatMessage(message ,"SAY");
		end
	end
	local adjust = .75
	if fromComms then
		adjust = 1
	end

	local bar
	if BLCD.db.profile.availablebars then
		bar = BLCD.curr[cooldown['spellID']][guid]
		--print('already made: ', bar, bar['running'], bar['remaining'])
	else
		bar = BLCD:CreateBar(frame,cooldown,caster,frameicon,guid,duration-adjust,spellName)
	end
	if bar then 
		bar:SetTimeVisibility(true)
		bar:EnableMouse(false)
		bar:SetFill(true)
		bar:Start()
	else
		if(cooldown["spec"]) then
			BLCD['raidRoster'][guid]["spec"] = cooldown["spec"]
			BLCD.cooldownRoster[cooldown['spellID']][guid] = BLCD['raidRoster'][guid]['name']
		elseif(cooldown["talent"]) then
			if not BLCD['raidRoster'][guid]["talents"] then
				BLCD['raidRoster'][guid]["talents"] = {}
				BLCD['raidRoster'][guid]["talents"][cooldown["talentidx"]] = {}
			end
			BLCD.cooldownRoster[cooldown['spellID']][guid] = BLCD['raidRoster'][guid]['name']
		elseif(not cooldown["spec"] and not cooldown["talent"] and cooldown["class"]) then -- we should never miss a class ability
			BLCD.cooldownRoster[cooldown['spellID']][guid] = BLCD['raidRoster'][guid]['name']
		end
		BLCD:UpdateRoster(cooldown)
		--bar = BLCD:CreateBar(frame,cooldown,caster,frameicon,guid,duration-adjust,spellName)
		if not bar then
			return --error('still couldnt get bar for '.. caster .. " " .. spellName)
		end
		bar = BLCD.curr[cooldown['spellID']][guid]
		bar:SetTimeVisibility(true)
		bar:EnableMouse(false)
		bar:Start()
	end
	BLCD:RearrangeBars(frameicon)

	if not(BLCD.curr[cooldown['spellID']][guid]) then
	    BLCD.curr[cooldown['spellID']][guid] = bar
    end
	if cooldown['charges'] and BLCD['raidRoster'][guid]['talents'][105622] then --Pally Clemency, could be useful later
		if BLCD['charges'][guid] == nil then
			BLCD['charges'][guid] = {}
		end
		BLCD['charges'][guid][cooldown['spellID']] = (BLCD['charges'][guid][cooldown['spellID']] or cooldown['charges']) - 1
	end
end

function BLCD:GetTotalCooldown(spellID)
	local cd = 0
	local cdTotal = 0
	
	if GetSpellCharges(20484) and (spellID == 20484 or spellID == 20707 or spellID == 61999) then
		return BLCD.resCount
	end
	
	for i,v in pairs(BLCD.cooldownRoster[spellID]) do
		local unitalive = not (UnitIsDeadOrGhost(v) or not UnitIsConnected(v) or false)
		if unitalive then
			cdTotal=cdTotal+1
		end
 	end

	for i,v in pairs(BLCD.curr[spellID]) do
		if v.updater:IsPlaying() then
			local _,_,_,_,_,name = GetPlayerInfoByGUID(i)
			local unitalive = not (UnitIsDeadOrGhost(name) or not UnitIsConnected(name) or false)
			if unitalive then
				cd=cd+1
			end
		end
	end
	
	local total = (cdTotal-cd)
	if(total < 0) then
		total = 0
	end

	return total
end

function BLCD:ResetAll()
	for spellId,guids in pairs(BLCD.curr) do
		for guid,bar in pairs(BLCD.curr[spellId]) do
			bar:Stop()
		end
	end
end

function BLCD:ResetWipe()
	for spellId,guids in pairs(BLCD.curr) do
		if BLCD.cooldowns[spellId]['CD'] >= 300 or spellId == 115310 or spellId == 740 then
			for guid,bar in pairs(BLCD.curr[spellId]) do
				bar:Stop()
			end
		end
	end
	for _, spellId in pairs(bResIDs) do
		local frameicon = cooldownFrameicons[spellId]
		if frameicon then
			frameicon.cooldown:SetCooldown(0, 0)
		end
	end
end
--------------------------------------------------------


--------------------------------------------------------
-- Battle Res and Wipe Functions --
--------------------------------------------------------
function BLCD:PLAYER_ENTERING_WORLD()
	local _, type = GetInstanceInfo()
	if type == "raid" then
		self:ScheduleRepeatingTimer("updateStatus", 0.5)
	end
end

function BLCD:DecrementBRes()
	BLCD.resCount = BLCD.resCount - 1
	for _, spellID in pairs(bResIDs) do
		local frameicon = cooldownFrameicons[spellID]
		if frameicon then frameicon.text:SetText(max(0,(BLCD.resCount))) end
	end
end

local function updateBRes()
	local charges, maxCharges, started, duration = GetSpellCharges(20484)
	if started then
		local time = duration - (GetTime() - started)
		local m = floor(time/60)
		local s = mod(time, 60)
		BLCD.resFrameIcon.text:SetFormattedText("%d\n%d:%02d", charges, m, s)
	end
end

local timeUpdater, inCombat = nil, false
function BLCD:updateStatus()
	local charges, maxCharges, started, duration = GetSpellCharges(20484)
	if charges then
		if not inCombat then
			inCombat = true
			BLCD.resFrame:Show()
			updateBRes()
			BLCD.resTimer = BLCD:ScheduleRepeatingTimer(updateBRes, 1)
		end
		if BLCD.resCount ~= charges then
			BLCD.resCount = charges
			for _, spellID in pairs(bResIDs) do
				BLCD:CancelBars(spellID)
			end
		end
	elseif inCombat and not charges then
		inCombat = false
		BLCD.resFrame:Hide()
		BLCD:ResetWipe() 
		BLCD:CancelTimer(BLCD.resTimer)
	end
end

function BLCD:UNIT_HEALTH(unit)
	if UnitInRaid(unit) or UnitInParty(unit) then
		local name = UnitName(unit)
		local connected = UnitIsConnected(unit)
		local deadorghost = UnitIsDeadOrGhost(unit)
		if BLCD.dead[name] == 1 and connected and not deadorghost then
			for spellID, cooldown in pairs(BLCD.cooldowns) do
				BLCD:CheckPausedBars(cooldown, unit)
				local frameicon = cooldownFrameicons[spellID]
				if frameicon then 
					frameicon.text:SetText(BLCD:GetTotalCooldown(spellID))
					BLCD:RearrangeBars(frameicon)
				end
			end
			BLCD.dead[name] = nil
		elseif not connected or deadorghost then
			BLCD.dead[name] = 1
		end
	end
end


function BLCD:shallowcopy(orig)
    local orig_type = type(orig)
    local copy, orig_key, orig_value
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
--------------------------------------------------------

--------------------------------------------------------
-- Initialization --
--------------------------------------------------------

local count = 0
function BLCD:OnInitialize()
	if count == 1 then return end
	BLCD:RegisterChatCommand("BLCD", "SlashProcessor_BLCD")
	
	-- DB
	BLCD.db = AceDB:New("BLCDDB", BLCD.defaults, true)
	
	self.db.RegisterCallback(self, "OnProfileChanged", "onProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "onProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "onProfileChanged")
	
	BLCD.db.profile = BLCD.db.profile
	BLCD:SetupOptions()
	BLCD:initMiniMap()
	LGIST.RegisterCallback (BLCD, "GroupInSpecT_Update", "OnLGIST")

	LGIST.RegisterCallback (BLCD, "GroupInSpecT_Remove", "OnLGIST")
	
	
	BLCD:CreateRaidTables()
	BLCD:CreateBase()
	LList['head'] = nil
	LList['tail'] = nil
	local active = 0
	local index
	for i, cooldown in pairs(BLCD.cooldowns) do
		index = cooldown.index
		if (BLCD.db.profile.cooldown[cooldown.name]) then
			active = active + 1;
			BLCD.curr[cooldown['spellID']] = {}
			BLCD.cooldownRoster[cooldown['spellID']] = {}
			cooldownIndex[index] = {}
			if LList.head == nil then 
				BLCD:InsertBeginning(cooldownIndex[index], index)
			else
				BLCD:InsertNode(cooldownIndex[index],index)
			end
			cooldownFrames[index] = BLCD:CreateCooldown(index, cooldown);
			BLCD:InsertFrame(cooldownFrames[index],cooldownIndex[index]['previous'],cooldownIndex[index]['next'], cooldownFrames)
		end
	end
	BLCD:CreateResFrame()
	BLCD:DynamicCooldownFrame()
	
	BLCD.active = active
	BLCD:CheckVisibility()

	count = 1
end

function BLCD:onProfileChanged()
	BLCD:DynamicCooldownFrame();
	BLCD:UpdateBarGrowthDirection()
	if BLCD.db.profile.minimap then BLCD.minimapButton:Show("BLCD") else BLCD.minimapButton:Hide("BLCD") end
	BLCD:Scale()
	BLCD:UpdateExtras()
	BLCD:CheckVisibility()
end
-----------------------------------

-----------------------------------
-- Linked List Management --
-----------------------------------

function BLCD:RemoveNode(node)
	if node['previous'] == nil then
		LList.head = node['next']
	else
		cooldownIndex[node['previous']]['next'] = node['next']
	end
	if node['next'] == nil then
		LList.tail = node['previous']
	else
		cooldownIndex[node['next']]['previous'] = node['previous']
	end
end

function BLCD:InsertNode(newNode, index)
	local key, node
	for key, node in pairs(cooldownIndex) do
		if index ~= key then  -- Node already created in LList but next,prev == nil. Like a floating node.
			if (node['previous'] or 0) < index and key > index then
				BLCD:InsertBefore(cooldownIndex[key], key, newNode, index)
				break
			elseif (node['next'] or 100) > index and key < index then
				BLCD:InsertAfter(cooldownIndex[key], key, newNode, index)
				break
			end
		end
	end
end

function BLCD:InsertAfter(node, index, newNode, index2)
    newNode['previous'] = index
    newNode['next']  = node['next']
	 
    if node['next'] == nil then
		LList.tail = index2
    else
		cooldownIndex[node['next']]['previous'] = index2
	end
	node['next'] = index2
end

function BLCD:InsertBefore(node, index, newNode, index2)
    newNode['previous'] = node['previous']
    newNode['next'] = index
	 
    if node['previous'] == nil then
        LList.head = index2
    else
        cooldownIndex[node['previous']]['next'] = index2
	end	
	node['previous'] = index2
end

function BLCD:InsertBeginning(newNode, index)
    if LList.head == nil then
         LList.head = index
         LList.tail = index
         newNode['previous']  = nil
         newNode['next']  = nil
    else	
         BLCD:InsertBefore(cooldownIndex[LList.head], LList.head, newNode, index)
	end
end
----------------------------------------------

----------------------------------------------
-- Version Control --
----------------------------------------------

do
	local timer = BLCD.frame:CreateAnimationGroup()
	timer:SetScript("OnFinished", function()
		if IsInGroup() then
			SendAddonMessage("BLCD", ("VR:%2f"):format(BLCD_VERSION), IsInGroup(2) and "INSTANCE_CHAT" or "RAID") -- LE_PARTY_CATEGORY_INSTANCE = 2
		end
	end)
	local anim = timer:CreateAnimation()
	anim:SetDuration(3)
	
	
	local hasWarned, hasCritWarned = nil, nil
	local function printOutOfDate(tbl)
		if hasCritWarned then return end
		local warnedOutOfDate, warnedExtremelyOutOfDate = 0, 0
		for k,v in next(tbl) do
			if (v) > BLCD_VERSION then
				warnedOutOfDate = warnedOutOfDate + 1
				if warnedOutOfDate > 1 and not hasWarned then
					hasWarned = true
					print("Your BL_Cooldown is out of date. Update to the latest version on curse.")
				end
			end
		end
	end

	function BLCD:VersionCheck(prefix, message, sender)
		if prefix == "VQ" or prefix == "VR" then
			if prefix == "VQ" then
				timer:Stop()
				timer:Play()
			end
			message = tonumber(message)
			if not message or message == 0 then return end 
			usersRelease[sender] = message
			
			if message > BLCD_VERSION then BLCD_VERSION = message end
			if BLCD_VERSION ~= -1 and message > BLCD_VERSION then
				printOutOfDate(usersRelease)
			end
			
		end
	end
end

function BLCD:PrintVersions()
	if not IsInGroup() then return end

	local function coloredNameVersion(name, version)
		if version == -1 then
			version = "|cFFCCCCCC(SVN)|r"
		elseif not version then
			version = ""
		else
			version = ("|cFFCCCCCC(%s%s)|r"):format(version, alpha and "-alpha" or "")
		end

		local _, class = UnitClass(name)
		local tbl = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class] or GRAY_FONT_COLOR
		name = name:gsub("%-.+", "*") -- Replace server names with *
		return ("|cFF%02x%02x%02x%s|r%s"):format(tbl.r*255, tbl.g*255, tbl.b*255, name, version)
	end

	local m = {}
	local unit
	if not IsInRaid() then
		m[1] = UnitName("player")
		unit = "party%d"
	else
		unit = "raid%d"
	end
	local i, player
	for i = 1, GetNumGroupMembers() do
		local n, s = UnitName((unit):format(i))
		if n and s and s ~= "" then n = n.."-"..s end
		if n then m[#m+1] = n end
	end

	local good = {} -- highest release users
	local ugly = {} -- old version users

	for i, player in next, m do
		if usersRelease[player] then
			if usersRelease[player] < BLCD_VERSION then
				ugly[#ugly + 1] = coloredNameVersion(player, usersRelease[player])
			else
				good[#good + 1] = coloredNameVersion(player, usersRelease[player])
			end
		end
	end

	if #good > 0 then print("Up to date: ", unpack(good)) end
	if #ugly > 0 then print("Out of date: ", unpack(ugly)) end
end
------------------------------------------------

------------------------------------------------
-- Addon Communication --
------------------------------------------------

function BLCD:ReceiveMessage(prefix, message, distribution, sender)
	if UnitIsUnit(sender, "player") then return end
	if prefix == commPrefix then
		local blPrefix, blMsg = message:match("^(%u-):(.+)")
		sender = Ambiguate(sender, "none")
		if blPrefix == "VQ" or blPrefix == "VR" then
			self:VersionCheck(blPrefix, blMsg, sender)
		end
		local success, DATA = self:Deserialize(message)
		if not success then 
			return -- Failure
		elseif type(DATA) == "table" then 
			local index = DATA[6]
			--print('recieved@ ', GetTime(), 'from: ', sender)--, 'message: ', BLCD:print_r(DATA))
			--local data = {{cooldown['spellID'], cooldown['name']},soureGUID,sourceName,spellName,duration,index}
			--local DATA = {cooldown,sourceGUID,sourceName,spellName,duration,index}
			--	DATA			1		 2		   3		  4		   5	   6
			if BLCD.db.profile.cooldown[DATA[1]['name']] then -- The player might not be tracking the cooldown that is received from comms
				if not(BLCD.curr[DATA[1]['spellID']][DATA[2]]) then
					local frameicon = cooldownFrameicons[DATA[1]['spellID']]
					local text = frameicon.text
					--BLCD:StartCD(frame                , cooldown,text,soureGUID,sourceName,frameicon, spellName,duration, true)
					BLCD:StartCD(cooldownFrames[index], DATA[1], text,DATA[2],  DATA[3],   frameicon, DATA[4],  DATA[5],  true )
					text:SetText(BLCD:GetTotalCooldown(DATA[1]['spellID']))
				elseif BLCD.db.profile.availablebars then
					if BLCD.curr[DATA[1]['spellID']][DATA[2]] and not BLCD.curr[DATA[1]['spellID']][DATA[2]]['updater']:IsPlaying()  then
						local bar = BLCD.curr[DATA[1]['spellID']][DATA[2]]
							if bar then
								bar:SetTimeVisibility(true)
								bar:EnableMouse(false)
								bar:Start()
							end
						local frameicon = cooldownFrameicons[DATA[1]['spellID']]
						local text = frameicon.text	
						BLCD:RearrangeBars(frameicon)
						text:SetText(BLCD:GetTotalCooldown(DATA[1]['spellID']))
					end
				end
			end
		end
	end
end

function BLCD:SendCommand(data)
	local s = self:Serialize(data)
	if IsInGroup() then
		self:SendCommMessage(commPrefix, s, IsInGroup(2) and "INSTANCE_CHAT" or "RAID", "", "ALERT")
	end
end

function BLCD:OnEnable()
	self:RegisterComm(commPrefix, "ReceiveMessage")
end

function BLCD:OnDisable()

end

function BLCD:PLAYER_LOGOUT()
	BLCDrosterReload = BLCD['raidRoster']
end
--------------------------------------------------------
-- XXXXX

local GameFontHighlightSmallOutline = GameFontHighlightSmallOutline
local _fontName, _fontSize = GameFontHighlightSmallOutline:GetFont()
local _fontShadowX, _fontShadowY = GameFontHighlightSmallOutline:GetShadowOffset()
local _fontShadowR, _fontShadowG, _fontShadowB, _fontShadowA = GameFontHighlightSmallOutline:GetShadowColor()
local bResIDs = {20484, 20707, 61999}
local ACD = LibStub("AceConfigDialog-3.0") -- Also for options panel

--------------------------------------------------------

--------------------------------------------------------
-- Helper Functions --
--------------------------------------------------------
function BLCD:GetPartyType()
	local grouptype = (IsInGroup(2) and 3) or (IsInRaid() and 2) or (IsInGroup() and 1)
	if grouptype == 3 then
		return "instance"
	elseif grouptype == 2 then
		return "raid"
	elseif grouptype == 1 then
		return "party"
	else
		return "none"
	end
end

--[[
0 - None; not in an Instance.
1 - 5-player Instance.
2 - 5-player Heroic Instance.
3 - 10-player Raid Instance.
4 - 25-player Raid Instance.
5 - 10-player Heroic Raid Instance.
6 - 25-player Heroic Raid Instance.
7 - Raid Finder Instance.
8 - Challenge Mode Instance.
9 - 40-player Raid Instance.
10 - Not used.
11 - Heroic Scenario Instance.
12 - Scenario Instance.
13 - Not used.
14 - Flexible Raid.
]]

function BLCD:print_r ( t )
	local print_r_cache={}
	local function sub_print_r(t,indent)
		if (print_r_cache[tostring(t)]) then
			print(indent.."*"..tostring(t))
		else
			print_r_cache[tostring(t)]=true
			if (type(t)=="table") then
				for pos,val in pairs(t) do
					if (type(val)=="table") then
						print(indent.."["..pos.."] => "..tostring(t).." {")
						sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
						print(indent..string.rep(" ",string.len(pos)+6).."}")
					elseif (type(pos)=="table") then
						print(indent.."["..tostring(pos).."] => "..tostring(t).." {")
						sub_print_r(pos,indent..string.rep(" ",string.len(tostring(pos))+8))
						print(indent..string.rep(" ",string.len(tostring(pos))+6).."}")
					else
						print(indent.."["..tostring(pos).."] => "..tostring(val))
					end
				end
			else
				print(indent..tostring(t))
			end
		end
	end
	sub_print_r(t," ")
end

function BLCD:ClassColorString (class)
	return string.format ("|cFF%02x%02x%02x",
		RAID_CLASS_COLORS[class].r * 255,
		RAID_CLASS_COLORS[class].g * 255,
		RAID_CLASS_COLORS[class].b * 255)
end

function BLCD:print_raid()
	return BLCD:print_r(BLCD['raidRoster'])
end

function BLCD:sec2Min(secs)
	return secs
end

local function print(...)
	DEFAULT_CHAT_FRAME:AddMessage("|cffc41f3bBLCD|r: " .. table.concat({...}, " "))
end
--------------------------------------------------------

--------------------------------------------------------
-- Display Bar Functions --
--------------------------------------------------------

--[[
local rearrangeBars
do
	local function barSorter(a, b)
		return a.remaining < b.remaining and true or false
	end
	local tmp = {}
	rearrangeBars = function(anchor)
		if not anchor then return end
		if anchor == normalAnchor then -- only show the empupdater when there are bars on the normal anchor running
			if next(anchor.bars) and db.emphasize then
				empUpdate:Play()
			else
				empUpdate:Stop()
			end
		end
		if not next(anchor.bars) then return end

		wipe(tmp)
		for bar in next, anchor.bars do
			tmp[#tmp + 1] = bar
		end
		table.sort(tmp, barSorter)
		local lastDownBar, lastUpBar = nil, nil
		local up = nil
		if anchor == normalAnchor then up = db.growup else up = db.emphasizeGrowup end
		for i, bar in next, tmp do
			local spacing = currentBarStyler.GetSpacing(bar) or 0
			bar:ClearAllPoints()
			if up or (db.emphasizeGrowup and bar:Get("bigwigs:emphasized")) then
				if lastUpBar then -- Growing from a bar
					bar:SetPoint("BOTTOMLEFT", lastUpBar, "TOPLEFT", 0, spacing)
					bar:SetPoint("BOTTOMRIGHT", lastUpBar, "TOPRIGHT", 0, spacing)
				else -- Growing from the anchor
					bar:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
					bar:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
				end
				lastUpBar = bar
			else
				if lastDownBar then -- Growing from a bar
					bar:SetPoint("TOPLEFT", lastDownBar, "BOTTOMLEFT", 0, -spacing)
					bar:SetPoint("TOPRIGHT", lastDownBar, "BOTTOMRIGHT", 0, -spacing)
				else -- Growing from the anchor
					bar:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
					bar:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
				end
				lastDownBar = bar
			end
		end
	end
end
]]
local function barSorter(a, b)
		local caster1 = a:Get("raidcooldowns:caster")
		local caster2 = b:Get("raidcooldowns:caster")	
	if a.remaining == b.remaining then
		return caster1 < caster2
	else
		return a.remaining < b.remaining
	end
end

function BLCD:RearrangeBars(anchor) -- frameicon
	if not anchor then return end
	if not next(anchor.bars) then
		if anchor:IsVisible() then
			BLCD:BLHeight(anchor:GetParent(), 28*BLCD.db.profile.scale)
		end
	return end
	local frame = anchor:GetParent()
	local scale = BLCD.db.profile.scale
	local growth = BLCD.db.profile.growth
	local currBars = {}
	
	for bar in pairs(anchor.bars) do
		if bar:IsVisible() then
			currBars[#currBars + 1] = bar
		else
			--print('hidden', bar:Get("raidcooldowns:caster"), bar:Get("raidcooldowns:spell"))
			bar:Show()
			anchor.bars[bar] = nil
			bar:Stop()
		end
	end
	
	if(#currBars > 2)then
		BLCD:BLHeight(frame, (14*#currBars)*scale);
	else
		BLCD:BLHeight(frame, 28*scale);
	end

	table.sort(currBars, barSorter)
	
	for i, bar in ipairs(currBars) do
		local spacing = (((-14)*(i-1))-2)
		bar:ClearAllPoints()
		if(growth  == "right") then
			BLCD:BLPoint(bar, "TOPLEFT", anchor, "TOPRIGHT", 5, spacing)
		elseif(growth  == "left") then
			BLCD:BLPoint(bar, "TOPRIGHT", anchor, "TOPLEFT", -5, spacing)
		end
	end
end

local backdropBorder = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	tile = false, tileSize = 0, edgeSize = 1,
	insets = {left = 0, right = 0, top = 0, bottom = 0}
}

local function styleBar(bar)
	local bd = bar.candyBarBackdrop

	if Elv and false then
		bd:SetTemplate("Transparent")
		bd:SetOutside(bar)
		if not E.PixelMode and bd.iborder then
			bd.iborder:Show()
			bd.oborder:Show()
		end
	else
		bd:SetBackdrop(backdropBorder)
		bd:SetBackdropColor(0.06, 0.06, 0.06, 0.25)
		bd:SetBackdropBorderColor(0.06, 0.06, 0.06, 0.25)

		bd:ClearAllPoints()
		bd:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
		bd:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
		
		bar.candyBarLabel:SetTextColor(1,1,1,1)
		bar.candyBarLabel:SetJustifyH("CENTER")
		bar.candyBarLabel:SetJustifyV("MIDDLE")
		bar.candyBarLabel:SetFont("Interface\\AddOns\\BL_Cooldown\\media\\Pixel8.ttf", 8)
		bar.candyBarLabel:SetShadowOffset(_fontShadowX, _fontShadowY)
		bar.candyBarLabel:SetShadowColor(_fontShadowR, _fontShadowG, _fontShadowB, _fontShadowA)

		bar.candyBarDuration:SetTextColor(1,1,1,1)
		bar.candyBarDuration:SetJustifyH("CENTER")
		bar.candyBarDuration:SetJustifyV("MIDDLE")
		bar.candyBarDuration:SetFont("Interface\\AddOns\\BL_Cooldown\\media\\Pixel8.ttf", 8)
		bar.candyBarDuration:SetShadowOffset(_fontShadowX, _fontShadowY)
		bar.candyBarDuration:SetShadowColor(_fontShadowR, _fontShadowG, _fontShadowB, _fontShadowA)
	end
	bd:Show()
end

function BLCD:CreateBar(frame,cooldown,caster,frameicon,guid,duration,spell)
	local bar = CB:New(BLCD:BLTexture(), 100, 9)
	styleBar(bar)
	frameicon.bars[bar] = true
	bar:Set("raidcooldowns:module", "raidcooldowns")
	bar:Set("raidcooldowns:anchor", frameicon)
	bar:Set("raidcooldowns:key", guid)
	bar:Set("raidcooldowns:spell", spell)
	bar:Set("raidcooldowns:caster", caster)
	bar:Set("raidcooldowns:cooldown", cooldown)
	bar:SetParent(frameicon)
	bar:SetFrameStrata("MEDIUM")
	if BLCD.db.profile.classcolorbars then
		local color = RAID_CLASS_COLORS[cooldown['class']] or {r=0.5; g=0.5; b=0.5}
		bar:SetColor(color.r,color.g,color.b,1)
	else
		bar:SetColor(.5,.5,.5,1)
	end	
	bar:SetDuration(duration)
	bar:SetFill(false)
	bar:SetScale(BLCD.db.profile.scale)
	bar:SetClampedToScreen(true)
	
	local caster = strsplit("-",caster)
	bar:SetLabel(caster)
	
	bar.candyBarLabel:SetJustifyH("LEFT")
	return bar
end	

function BLCD:CancelBars(spellID)
	if BLCD.db.profile.cooldown[BLCD.cooldowns[spellID].name] then
		for guid, bar in pairs(BLCD.curr[spellID]) do
			bar:Stop()
		end
	end
end

function BLCD:restyleBar(self)
	self.candyBarBar:SetPoint("TOPLEFT", self)
	self.candyBarBar:SetPoint("BOTTOMLEFT", self)
	self.candyBarIconFrame:Hide()
	if self.candyBarLabel:GetText() then self.candyBarLabel:Show()
	else self.candyBarLabel:Hide() end
	self.candyBarDuration:Hide()
end

function BLCD:StopPausedBar(cooldown,guid)
	if BLCD.curr[cooldown['spellID']] and BLCD.curr[cooldown['spellID']][guid] then
		local bar = BLCD.curr[cooldown['spellID']][guid]
		if not bar.updater:IsPlaying() then
			bar:Stop()
		end
	end
end

function BLCD:CheckPausedBars(cooldown,unit)
	if BLCD.db.profile.availablebars then
		local unitDead = UnitIsDeadOrGhost(unit) and true
		local unitOnline = (UnitIsConnected(unit) or false)
		local name = UnitName(unit)
		local guid = UnitGUID(unit)
		if BLCD.curr[cooldown['spellID']] and BLCD.curr[cooldown['spellID']][guid] then
			local bar = BLCD.curr[cooldown['spellID']][guid]
			if unitDead or not unitOnline then
				if not bar.updater:IsPlaying() then
					bar:Stop()
				end
			end
		end
		if BLCD.db.profile.cooldown[cooldown.name] and BLCD.cooldownRoster[cooldown['spellID']][guid] and not (BLCD.curr[cooldown['spellID']] and BLCD.curr[cooldown['spellID']][guid]) then
			if not unitDead and unitOnline then
				BLCD:CreatePausedBar(cooldown, guid)
			end
		end
	end
end


--------------------------------------------------------
-- Visibility Functions --
--------------------------------------------------------
function BLCD:CheckVisibility()
	local frame = BLCooldownBase_Frame
	local grouptype = BLCD:GetPartyType()
	if(BLCD.db.profile.show == "never") then
		frame:Hide()
		BLCD.show = nil
	elseif(BLCD.db.profile.show == "raid" and (grouptype =="raid" or grouptype == "instance")) then
		frame:Show()
		BLCD.show = true
	elseif(BLCD.db.profile.show == "raid" and not (grouptype =="raid" or grouptype == "instance")) then
		frame:Hide()
		BLCD.show = nil
	elseif(BLCD.db.profile.show == "raidorparty" and (grouptype =="raid" or grouptype == "instance" or grouptype=="party")) then
		frame:Show()
		BLCD.show = true
	elseif(BLCD.db.profile.show == "raidorparty" and not (grouptype =="raid" or grouptype == "instance" or grouptype=="party")) then
		frame:Hide()
		BLCD.show = nil	
	elseif(BLCD.db.profile.show == "party" and grouptype =="party") then
		frame:Show()
		BLCD.show = true
	elseif(BLCD.db.profile.show == "party" and grouptype ~="party") then
		frame:Hide()
		BLCD.show = nil
	end
end

function BLCD:ToggleVisibility()
	local frame = BLCooldownBase_Frame
	if(BLCD.show) then
		frame:Hide()
		BLCD.show = nil
	else
		frame:Show()
		BLCD.show = true
	end
end

function BLCD:ToggleMoversLock()
	local raidcdbasemover = BLCooldownBaseMover_Frame
	if(BLCD.locked) then
		raidcdbasemover:EnableMouse(true)
		raidcdbasemover:RegisterForDrag("LeftButton")
		raidcdbasemover:Show()
		BLCD.locked = nil
		print("unlocked")
	else
		raidcdbasemover:EnableMouse(false)
		raidcdbasemover:RegisterForDrag(nil)
		raidcdbasemover:Hide()
		BLCD.locked = true
		print("locked")
		local point,_,relPoint,xOfs,yOfs = raidcdbasemover:GetPoint(1)
		BLCD.db.profile.framePoint = point
		BLCD.db.profile.relativePoint = relPoint
		BLCD.db.profile.xOffset = xOfs
		BLCD.db.profile.yOffset = yOfs
	end
end
--------------------------------------------------------
--------------------------------------------------------
-- Minimap Button

function BLCD:initMiniMap()
	button = CreateFrame("Button", "BLCD_MinimapButton", Minimap)
	button.db = BLCD.db.profile.minimapPos or 0
	button:SetFrameStrata("MEDIUM")
	button:SetSize(31, 31)
	button:SetFrameLevel(8)
	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture("Interface\\Addons\\BL_Cooldown\\media\\BLCD")
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon
	button.isMouseDown = false

	--button:SetScript("OnEnter", onEnter)
	--button:SetScript("OnLeave", onLeave)

	local onClick, onMouseUp, onMouseDown, onDragStart, onDragStop, onDragEnd, updatePosition

	local minimapShapes = {
		["ROUND"] = {true, true, true, true},
		["SQUARE"] = {false, false, false, false},
		["CORNER-TOPLEFT"] = {false, false, false, true},
		["CORNER-TOPRIGHT"] = {false, false, true, false},
		["CORNER-BOTTOMLEFT"] = {false, true, false, false},
		["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
		["SIDE-LEFT"] = {false, true, false, true},
		["SIDE-RIGHT"] = {true, false, true, false},
		["SIDE-TOP"] = {false, false, true, true},
		["SIDE-BOTTOM"] = {true, true, false, false},
		["TRICORNER-TOPLEFT"] = {false, true, true, true},
		["TRICORNER-TOPRIGHT"] = {true, false, true, true},
		["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
		["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
	}

	function updatePosition(button)
		local angle = math.rad(BLCD.db.profile.minimapPos or 225)
		local x, y, q = math.cos(angle), math.sin(angle), 1
		if x < 0 then q = q + 1 end
		if y > 0 then q = q + 2 end
		local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
		local quadTable = minimapShapes[minimapShape]
		if quadTable[q] then
			x, y = x*80, y*80
		else
			local diagRadius = 103.13708498985 --math.sqrt(2*(80)^2)-10
			x = math.max(-80, math.min(x*diagRadius, 80))
			y = math.max(-80, math.min(y*diagRadius, 80))
		end
		button:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end

	local function onUpdate(self)
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		BLCD.db.profile.minimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
		updatePosition(self)
	end

	function onDragStart(self)
		self:LockHighlight()
		self.isMouseDown = true
		self:SetScript("OnUpdate", onUpdate)
		self.isMoving = true
		GameTooltip:Hide()
	end

	function onDragStop(self)
		self:SetScript("OnUpdate", nil)
		self.isMouseDown = false
		self:UnlockHighlight()
		self.isMoving = nil
	end

	button:SetScript("OnClick", function() if ACD.OpenFrames["BLCD"] then ACD:Close("BLCD") else ACD:Open("BLCD") end end)
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnDragStop", onDragStop)
	updatePosition(button)
	if BLCD.db.profile.minimap then
		button:Show()
	else
		button:Hide()
	end
	BLCD.minimapButton = button
end

---------------------------------------------------------------------------------------

--------------------------------------------------------
-- Frame Functions --
--------------------------------------------------------
function BLCD:OnEnter(self, cooldown, rosterCD, onCD)
	--local parent = self:GetParent()
	--local allCD = BLCD:shallowcopy(rosterCD)
	GameTooltip:Hide()
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT",3, 14)
	GameTooltip:ClearLines()
	GameTooltip:AddSpellByID(cooldown['spellID'])

	local guid,bar,i,v
	--for guid,bar in pairs(onCD) do
		--print('on: ', guid,bar)
		--allCD[guid] = 0
	--end
	if next(rosterCD) ~= nil then
		GameTooltip:AddLine(' ')
		for i,v in pairs(rosterCD) do
		-- guid, name
		--print(i,v)
			if not (onCD[i] and onCD[i]['updater']:IsPlaying()) then
				local unitAlive = not (UnitIsDeadOrGhost(v) or false)
				local unitOnline = (UnitIsConnected(v) or false)
				if unitAlive and unitOnline then
					GameTooltip:AddLine(v .. ' Ready!', 0, 1, 0)
				elseif not unitOnline then
					GameTooltip:AddLine(v .. ' OFFLINE but ready!', 1, 0, 0)
				else
					GameTooltip:AddLine(v .. ' DEAD but Ready!', 1, 0, 0)
				end
			end
		end
	end
	GameTooltip:Show()
end

function BLCD:OnLeave(self)
   GameTooltip:Hide()
end

function BLCD:PostClick(self, cooldown, rosterCD, onCD)
	if(BLCD.db.profile.clickannounce) then
		--local allCD = BLCD:shallowcopy(rosterCD)
		--local grouptype = BLCD:GetPartyType()
		--for i,v in pairs(onCD) do
			--allCD[i] = 0
		--end
		
		if next(rosterCD) ~= nil then
			local name = GetSpellInfo(cooldown['spellID'])
			if IsInRaid() or IsInGroup(2) then
				SendChatMessage('----- '..name..' -----',IsInGroup(2) and "INSTANCE_CHAT" or "RAID")
			elseif IsInGroup() then
				SendChatMessage('----- '..name..' -----','PARTY')
			end
			
			for i,v in pairs(rosterCD) do
				if not (onCD[i] and onCD[i]['updater']:IsPlaying()) then
					local unitalive = not (UnitIsDeadOrGhost(v) or false)
					local unitOnline = (UnitIsConnected(v) or false)
					if IsInRaid() or IsInGroup(2) then
						if unitalive then
							SendChatMessage(v..' ready!',IsInGroup(2) and "INSTANCE_CHAT" or "RAID")
						elseif not unitOnline then
							SendChatMessage(v..' OFFLINE but ready!',IsInGroup(2) and "INSTANCE_CHAT" or "RAID")
						else
							SendChatMessage(v..' DEAD but ready!',IsInGroup(2) and "INSTANCE_CHAT" or "RAID")
						end
					elseif IsInGroup() then
						if unitalive then
							SendChatMessage(v..' ready!','PARTY')
						elseif not unitOnline then
							SendChatMessage(v..' OFFLINE but ready!', 'PARTY')
						else
							SendChatMessage(v..' DEAD but ready!','PARTY')
						end	
					end
				end
			end
		end
	end
end
--------------------------------------------------------

--------------------------------------------------------
-- Frame Appearance Functions --
--------------------------------------------------------
function BLCD:Scale()
	local raidcdbase = BLCooldownBase_Frame
	local raidcdbasemover = BLCooldownBaseMover_Frame
	BLCD:BLSize(raidcdbase,32*BLCD.db.profile.scale,32*BLCD.db.profile.scale)
	BLCD:BLSize(raidcdbasemover,32*BLCD.db.profile.scale,96*BLCD.db.profile.scale)
	local i,cooldown
	for i,cooldown in pairs(BLCD.cooldowns) do
		i = cooldown.index
		if (BLCD.db.profile.cooldown[cooldown.name]) then
		BLCD:BLHeight(_G['BLCooldown'..i],28*BLCD.db.profile.scale);
		BLCD:BLWidth(_G['BLCooldown'..i],145*BLCD.db.profile.scale);	
		BLCD:BLSize(_G['BLCooldownIcon'..i],28*BLCD.db.profile.scale,28*BLCD.db.profile.scale);
		BLCD:BLFontTemplate(_G['BLCooldownIcon'..i].text, 20*BLCD.db.profile.scale, 'OUTLINE')
		end
	end
	BLCD:BLSize(BLCD.resFrame,35*BLCD.db.profile.scale,30*BLCD.db.profile.scale);
	BLCD:BLSize(BLCD.resFrameIcon,35*BLCD.db.profile.scale,30*BLCD.db.profile.scale);
	BLCD:BLFontTemplate(BLCD.resFrameIcon.text, 14*BLCD.db.profile.scale, 'OUTLINE')
end

function BLCD:SetBarGrowthDirection(frame, frameicon, index)
	if(BLCD.db.profile.growth == "left") then
		if index == nil then
			BLCD:BLPoint(frame,'TOPRIGHT', 'BLCooldownBase_Frame', 'TOPRIGHT', 2, -2);
		else
			BLCD:BLPoint(frame,'TOPRIGHT', 'BLCooldown'..(index), 'BOTTOMRIGHT', 0, -2);
		end
		BLCD:BLPoint(frameicon,'TOPRIGHT', frame, 'TOPRIGHT');
	elseif(BLCD.db.profile.growth  == "right") then
		--[[if index == nil then
			BLCD:BLPoint(frame,'TOPLEFT', 'BLCooldownBase_Frame', 'TOPLEFT', 2, -2);
		else
			BLCD:BLPoint(frame,'TOPLEFT', 'BLCooldown'..(index), 'BOTTOMLEFT', 0, -2);
		end]]
		BLCD:BLPoint(frameicon,'TOPLEFT', frame, 'TOPLEFT');
	end
end

function BLCD:RepositionFrames(frame, index, cooldownFrames)
	if(BLCD.db.profile.growth == "left") then
		if index == nil then
			BLCD:BLPoint(frame,'TOPRIGHT', 'BLCooldownBase_Frame', 'TOPRIGHT', 2, -2);
		else
			BLCD:BLPoint(frame,'TOPRIGHT', 'BLCooldown'..(index), 'BOTTOMRIGHT', 0, -2);
		end
	elseif(BLCD.db.profile.growth  == "right") then
		if index == nil then
			BLCD:BLPoint(frame,'TOPLEFT', 'BLCooldownBase_Frame', 'TOPLEFT', 2, -2);
		else
			BLCD:BLPoint(frame,'TOPLEFT', 'BLCooldown'..(index), 'BOTTOMLEFT', 0, -2);
		end
	end
end

function BLCD:InsertFrame(frame, prevIndex, nextIndex, cooldownFrames)
	if prevIndex == nil then
		BLCD:BLPoint(frame,'TOPLEFT', 'BLCooldownBase_Frame', 'TOPLEFT', 2, -2); 
		frame:Show()
		if nextIndex ~= nil then BLCD:BLPoint(cooldownFrames[nextIndex],'TOPLEFT', frame, 'BOTTOMLEFT', 0, -2); end
	else
		BLCD:BLPoint(frame,'TOPLEFT', cooldownFrames[prevIndex], 'BOTTOMLEFT', 0, -2);
		frame:Show()
		if nextIndex ~= nil then BLCD:BLPoint(cooldownFrames[nextIndex],'TOPLEFT', frame, 'BOTTOMLEFT', 0, -2); end
	end
end

function BLCD:RemoveFrame(frame, prevIndex, nextIndex, cooldownFrames)
	if prevIndex == nil then
		frame:Hide()
		if nextIndex ~= nil then BLCD:BLPoint(cooldownFrames[nextIndex],'TOPLEFT', 'BLCooldownBase_Frame', 'TOPLEFT', 2, -2); end
	else
		frame:Hide()
		if nextIndex ~= nil then BLCD:BLPoint(cooldownFrames[nextIndex],'TOPLEFT', cooldownFrames[prevIndex], 'BOTTOMLEFT', 0, -2); end
	end
end
	
function BLCD:BLHeight(frame, height)
	if(Elv) then
		frame:Height(height)
	else
		frame:SetHeight(height)
	end
end

function BLCD:BLWidth(frame, width)
	if(Elv) then
		frame:Width(width)
	else
		frame:SetWidth(width)
	end
end

function BLCD:BLSize(frame, width, height)
	if(Elv) then
		frame:Size(width, height)
	else
		frame:SetSize(width, height)
	end
end

function BLCD:BLPoint(obj, arg1, arg2, arg3, arg4, arg5)
	if(Elv) then
		obj:Point(arg1, arg2, arg3, arg4, arg5)
	else
		obj:SetPoint(arg1, arg2, arg3, arg4, arg5)
	end
end

function BLCD:BLTexture()
	if(Elv and false) then
		return E["media"].normTex
	else
		return "Interface\\AddOns\\BL_Cooldown\\media\\statusbar.tga"
	end
end

function BLCD:BLFontTemplate(frame, x, y)
	if(Elv) then
		frame:FontTemplate(nil, x, y)
	else
		frame:SetFont("Interface\\AddOns\\BL_Cooldown\\media\\PT_Sans_Narrow.ttf", x, y)
		frame:SetShadowColor(0, 0, 0, 0.2)
		frame:SetShadowOffset(1, -1)
	end
end
--------------------------------------------------------