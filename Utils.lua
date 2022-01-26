local version = "101"

Utils = {}

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
	local tipTable = {}	
	local regions = {toolTip:GetRegions()}
	for k,v in ipairs(regions) do
		if  v:GetObjectType() == "FontString" then
			local text = v:GetText() == nil and "" or v:GetText()
			local _,_,side,row = string.find(v:GetName(), "([LR].+)([0-9]+)$")
			row = tonumber(row)
			if (side == "Left" or side == "Right") and row <= toolTip:NumLines() then
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

Utils.ScanBuffs = function(toolTip, unit)
	local buffList = {}
	toolTip:SetOwner(UIParent,"ANCHOR_NONE")
	for i=1,100 do
		toolTip:SetUnitBuff(unit, i)		
		local buffName = Utils.GetToolTipText(toolTip,"Left1")
		if buffName == nil then
			break
		end
		buffList[buffName] = Utils.GetToolTipTextTable(toolTip)
	end
	return buffList
end