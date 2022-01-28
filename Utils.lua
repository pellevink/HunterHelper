local this_version = "103"

-- if the global Utils object has already loaded
-- we will overwrite it if is outdated or doesn't exist
if Utils == nil or Utils.version == nil or Utils.version < this_version then	
-- overwrite / create the global Utils object
Utils = {
	version = this_version,
	ttscan = CreateFrame("GameTooltip", "utils_ttscan_", nil, "GameTooltipTemplate"), -- a scanning tooltip
	CHAT_COMBAT = {
		"CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS",
		"CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES",
		"CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS", 
		"CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES" ,
		"CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS" ,
		"CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES", 
		"CHAT_MSG_COMBAT_FRIENDLY_DEATH" ,
		"CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS" ,
		"CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES",
		"CHAT_MSG_COMBAT_HONOR_GAIN" ,
		"CHAT_MSG_COMBAT_HOSTILE_DEATH" ,
		"CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS" ,
		"CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES",
		"CHAT_MSG_COMBAT_MISC_INFO" ,
		"CHAT_MSG_COMBAT_PARTY_HITS" ,
		"CHAT_MSG_COMBAT_PARTY_MISSES",
		"CHAT_MSG_COMBAT_PET_HITS" ,
		"CHAT_MSG_COMBAT_PET_MISSES",
		"CHAT_MSG_COMBAT_SELF_HITS", 
		"CHAT_MSG_COMBAT_SELF_MISSES",
		"CHAT_MSG_COMBAT_XP_GAIN",
		"CHAT_MSG_SPELL_AURA_GONE_OTHER",
		"CHAT_MSG_SPELL_AURA_GONE_PARTY",
		"CHAT_MSG_SPELL_AURA_GONE_SELF",
		"CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF",
		"CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
		"CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF",
		"CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE",
		"CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF",
		"CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
		"CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
		"CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF",
		"CHAT_MSG_SPELL_FAILED_LOCALPLAYER",
		"CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
		"CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
		"CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
		"CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
		"CHAT_MSG_SPELL_ITEM_ENCHANTMENTS",
		"CHAT_MSG_SPELL_PARTY_BUFF",
		"CHAT_MSG_SPELL_PARTY_DAMAGE",
		"CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
		"CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
		"CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
		"CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE",
		"CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS",
		"CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
		"CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
		"CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
		"CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
		"CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
		"CHAT_MSG_SPELL_PET_BUFF",
		"CHAT_MSG_SPELL_PET_DAMAGE",
		"CHAT_MSG_SPELL_SELF_BUFF",
		"CHAT_MSG_SPELL_SELF_DAMAGE",
		"CHAT_MSG_SPELL_TRADESKILLS",
	}
}

Utils.ttscan.chatCombatCallbacks = {}
for k,v in pairs(Utils.CHAT_COMBAT) do
	Utils.ttscan:RegisterEvent(v)
end

Utils.ttscan:SetScript("OnEvent", function()
	-- the ttscan only listens for these old chat events
	for k,v in pairs(Utils.ttscan.chatCombatCallbacks) do
		Utils.ttscan.chatCombatCallbacks(event, arg1)
	end
end)

Utils.RegisterChatCombatEvent = function(fnCallback)
	table.insert(Utils.ttscan.chatCombatCallbacks, fnCallback)
end


Utils.SetDBVar = function(db, value, ...)
	if arg.n == 0 then
		return
	end

	if db == nil then
		db = {}
	end

	-- store and remove the last element in the chain
	local last = arg[arg.n]
	table.remove(arg, arg.n)
	local ptr = db
	for _,var in ipairs(arg) do
		if ptr[var] == nil then
			ptr[var] = {}
		end
		ptr = ptr[var]
	end
	ptr[last] = value
end

Utils.SetDBCharVar = function(db, value, ... )
	return Utils.SetDBVar(db, value, "Characters", GetRealmName().."-"..UnitName("player"), unpack(arg))
end

Utils.GetDBVar = function(db, ...)
	-- obtain a variable from the database without failing
	if db == nil then
		return nil
	end

	local ptr = db
	for _,var in ipairs(arg) do
		if ptr[var] == nil then
			return nil
		end
		ptr = ptr[var]
	end
	return ptr
end

Utils.GetDBCharVar = function(db, ... )
	return Utils.GetDBVar(db, "Characters", GetRealmName().."-"..UnitName("player"), unpack(arg))
end

Utils.TableToStr = function(tbl)
	local tabitems = {}				
	for key,val in pairs(tbl) do
		if type(val) == "table" then
			val = Utils.TableToStr(val)
		else
			val = tostring(val)
		end
		table.insert(tabitems, tostring(key).."="..val)
	end
	
	return "{"..table.concat(tabitems,",").."}"
end

Utils.ArgsToStr = function(...)
	-- convert a ... argument to a comma separated text list
	local text = nil
	if arg ~= nil then
		local items = {}
		local count = 0
		for i,v in ipairs(arg) do			
			if type(v) == "table" then
				table.insert(items, Utils.TableToStr(v) )
			else
				-- anything else and we just force it to string
				table.insert(items, tostring(v))
			end
			count = count + 1
		end
		if count > 0 then
			text = table.concat(items," ")
		end
	end
	return tostring(text)
end

Utils.GetFramePoint = function(frame, pointName)
	for i=0,frame:GetNumPoints() do
		local next = {frame:GetPoint(i)}
		if next ~= nil then
			if next[1] == pointName then
				return next
			end
		end
	end
	return nil
end

Utils.FrameCreator = function(cfArgs, fnInit )
	local newFrame = CreateFrame(unpack(cfArgs))
	fnInit(newFrame)
	return newFrame
end

Utils.NTable = function()
	return {
		_n=0,
		size = function(self)
			return self._n
		end,
		append = function(self, element)
			table.insert(self, element)
			self._n = self._n + 1
		end,
		back = function(self)
			return self._n > 0 and self[self._n] or nil
		end,
		front = function(self)
			return self._n > 0 and self[1] or nil
		end,
		popfront = function(self)
			if self._n > 0 then
				self._n = self._n - 1
				table.remove(self, 1)
			end
		end,
		erase = function(self, element)
			local function _erase(t, tgt)
				for i,e in ipairs(t) do
					if e == tgt then
						table.remove(t, i)
						t._n = t._n - 1
						return true
					end
				end
				return false
			end

			while _erase(self, element) == true do
			end

		end
	}
end

Utils.Set = function(...)
	if arg[1] == nil then
		return {}
	end
	local list = arg
	if type(arg[1]) == "table" then
		list = arg[1]
	end

	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

Utils.GetInventoryTooltip = function(slotId)
	Utils.ttscan:SetOwner(UIParent, "ANCHOR_NONE")
	Utils.ttscan:SetInventoryItem("player", slotId)
	local ttt =  Utils.GetToolTipTextTable(Utils.ttscan)
	return ttt and ttt["Left1"], ttt or nil
end

Utils.GetSpellTooltip = function(slotId, spellBookId)
	Utils.ttscan:SetOwner(UIParent, "ANCHOR_NONE")
	Utils.ttscan:SetSpell(slotId, spellBookId)		
	local ttt =  Utils.GetToolTipTextTable(Utils.ttscan)
	return ttt and ttt["Left1"], ttt or nil
end

Utils.GetActionTooltip = function(slotId)
	Utils.ttscan:SetOwner(UIParent, "ANCHOR_NONE")
	Utils.ttscan:SetAction(slotId, spellBookId)		
	local ttt =  Utils.GetToolTipTextTable(Utils.ttscan)
	return ttt and ttt["Left1"], ttt or nil
end

Utils.GetToolTipText = function(toolTip, side)
	-- helper to extract toolip text 
	local regions = {toolTip:GetRegions()}
	for k,v in ipairs(regions) do
		if  v:GetObjectType() == "FontString" then
			if string.find(v:GetName(), side.."$") then
				return v:GetText()
			end
		end
	end
	return nil
end

Utils.GetToolTipTextTable = function(toolTip)
	local tipTable = nil
	local regions = {toolTip:GetRegions()}
	for k,v in ipairs(regions) do
		if  v:GetObjectType() == "FontString" then
			local text = v:GetText() == nil and "" or v:GetText()
			local _,_,side,row = string.find(v:GetName(), "([LR].+)([0-9]+)$")
			row = tonumber(row)
			if (side == "Left" or side == "Right") and row <= toolTip:NumLines() then
				if tipTable == nil then tipTable = {} end
				tipTable[side..row] = text
			end
		end
	end
	return tipTable
end

Utils.GetToolTipTextString = function(toolTip)
	-- helper to extract the entire toolip text
	-- each row is separated by ; and each item in the row is separated by ,
	local tipTable = {}	
	local regions = {toolTip:GetRegions()}
	for k,v in ipairs(regions) do
		if  v:GetObjectType() == "FontString" then
			local text = v:GetText() == nil and "" or v:GetText()
			local _,_,side,row = string.find(v:GetName(), "([LR].+)([0-9]+)$")
			row = tonumber(row)
			if (side == "Left" or side == "Right") and row <= toolTip:NumLines() then
				if tipTable[row] == nil then
					tipTable[row] = {"",""}
				end
				tipTable[row][side=="Right" and 2 or 1] = text
			end
		end
	end
	local tipList = {}
	for i,row in ipairs(tipTable) do
		tipList[i] = row[1]..","..row[2]
	end
	return table.concat(tipList,";")
end

Utils.FindToolTipText = function(toolTip, text)
	local regions = {toolTip:GetRegions()}
	for k,v in ipairs(regions) do
		if  v:GetObjectType() == "FontString" then
			if text == v:GetText() then
				return v:GetName()
			end
		end
	end
	return nil
end

Utils.ScanAuras = function(toolTip, unit, buffs, currentBuffs)
	local activeBuffs = {}
	toolTip:SetOwner(UIParent,"ANCHOR_NONE")
	for i=1,100 do
		if buffs then
			toolTip:SetUnitBuff(unit, i)		
		else
			toolTip:SetUnitDebuff(unit, i)
		end

		local buffName = Utils.GetToolTipText(toolTip,"Left1")
		if buffName == nil then
			break
		end
		activeBuffs[buffName] = true
		
		if currentBuffs[buffName] == nil then
			-- brand new buff
			currentBuffs[buffName] = Utils.GetToolTipTextTable(toolTip)
			currentBuffs[buffName].started = GetTime()
		else
			-- this buff was had at some point, but was it ACTIVE last scan?
			if currentBuffs[buffName].ended ~= nil then
				-- NO this buff ended at some point, so it's a new application of a historic buff
				currentBuffs[buffName].started = GetTime()
				currentBuffs[buffName].ended = nil
			end
		end		
	end

	-- go through all the buffs the player has and see if it was currently active
	-- if it ISN'T currently active, and NOT ALREADY flagged as ended, do so.
	for buffName,buff in pairs(currentBuffs) do
		if activeBuffs[buffName] == nil and buff.ended == nil then
			buff.ended = GetTime()
		end
	end
	
end

Utils.CreateTimer = function(parentObject, timerName, interval)
	parentObject[timerName] = {
		interval = interval,
		next = GetTime() + interval
	}
end

Utils.UpdateReady = function(parentObject, timerName)
	if parentObject == nil or parentObject[timerName] ==  nil then		
		return false
	end
	
	if GetTime() >= parentObject[timerName].next then
		parentObject[timerName].next = GetTime() + parentObject[timerName].interval
		return true
	else
		return false
	end
end

end -- end check to overwrite