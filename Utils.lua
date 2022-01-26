local version = "100"

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