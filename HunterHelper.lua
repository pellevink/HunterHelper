local _G = getfenv(0)
local HH_SLASH_COMMAND		= "/huh"
local RANGED_OUTOFRANGE 	= {1.0, 0.0, 0.0, 0.3}
local RANGED_INRANGE		= {0.0, 1.0, 0.0, 0.0}
local RANGED_UNATTACKABLE	= {0.0, 1.0, 0.0, 0.0}
local RANGED_HIDDEN			= {0.0, 0.0, 0.0, 0.0}
local PET_HAPPINESS			= {"Unhappy >:(", "Content :)", "Happy :D"}
local SPELL_AUTO_SHOT		= "Auto Shot"
local AUTO_SHOT_TIP			= {Left1=SPELL_AUTO_SHOT}--, Left4="Requires Ranged Weapon"} -- allows macros to be used on action bar
local STR_ADDON_NAME		= "HunterHelper"
local HH_AUTO_ACTIVATE		= "ACTIVATE"
local HH_AUTO_STOP			= "STOP"
local HH_AUTO_IGNORE		= "IGNORE"
local INVENTORY_SLOT_AMMO	= 0
local HH_UPDATE_INTERVAL	= 0.05
local HH_PETCHECK_INTERVAL	= 1.0
local nextRangeCheck 		= GetTime()
local nextPetCheck 			= GetTime()
local petHappiness			= 3 -- initialize to happy
local autoShotSlot 			= nil
local ttscan 				= CreateFrame("GameTooltip", "ttscan_", nil, "GameTooltipTemplate")
local BLIZZ_CastSpellByName = CastSpellByName
local BLIZZ_CastSpell		= CastSpell
local BLIZZ_UseAction		= UseAction
local HH_ERROR_AUTO_SHOT 	= "HunterHelper could not locate Auto Shot on your action bar. Drag Auto Shot from your spellbook into an open action bar slot, or a macro named Auto Shot."
local debugEnabled 			= false

local function debug(...)
	-- local helper function to print to system console OR the global ScriptEditor addon ScriptEditor:Log function
	if debugEnabled == false then return end
	
	if ScriptEditor ~= nil then
		ScriptEditor:Log(unpack(arg))
	else
		local text = ArgsToStr(unpack(arg))
		cfout(text)
	end
end

local function SetDBVar(value, ...)
	if arg.n == 0 then
		return
	end

	if HunterHelperDB == nil then
		HunterHelperDB = {}
	end

	-- store and remove the last element in the chain
	local last = arg[arg.n]
	table.remove(arg, arg.n)
	local ptr = HunterHelperDB
	for _,var in ipairs(arg) do
		if ptr[var] == nil then
			ptr[var] = {}
		end
		ptr = ptr[var]
	end
	ptr[last] = value
end

local function GetDBVar(...)
	-- obtain a variable from the database without failing
	if HunterHelperDB == nil then
		return nil
	end

	local ptr = HunterHelperDB
	for _,var in ipairs(arg) do
		if ptr[var] == nil then
			return nil
		end
		ptr = ptr[var]
	end
	return ptr
end

local function TableToStr(tbl)
	local tabitems = {}				
	for key,val in pairs(tbl) do
		if type(val) == "table" then
			val = TableToStr(val)
		else
			val = tostring(val)
		end
		table.insert(tabitems, tostring(key).."="..val)
	end
	
	return "{"..table.concat(tabitems,",").."}"
end

local function ArgsToStr(...)
	-- convert a ... argument to a comma separated text list
	local text = nil
	if arg ~= nil then
		local items = {}
		local count = 0
		for i,v in ipairs(arg) do			
			if type(v) == "table" then
				table.insert(items, TableToStr(v) )
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

local function print(...)
	-- local helper function to print to system console
	local text = ArgsToStr(unpack(arg))
	_G["ChatFrame1"]:AddMessage(text)
end


local function GetToolTipText(toolTip, side)
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

local function GetToolTipTextTable(toolTip)
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

local function GetToolTipTextString(toolTip)
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

local function FindToolTipText(toolTip, text)
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


local function ShowToast(title, text)
	-- if the toastmaster was loaded in, we use it. if not, just dump the text to chat frame
	if ToastMaster ~= nil then
		ToastMaster:AddToast(title, text)
	else 
		print(title..": "..text)
	end	
end

-- "HunterHelper could not locate Auto Shot on your action bar. Drag Auto Shot from your spellbook into an open action bar slot, or a macro named Auto Shot.\n|cFF00FF00click to close|r"

local fammo = CreateFrame("Frame", nil, WorldFrame)
fammo.strType = fammo:CreateFontString("FontString")
fammo.strType:SetFont("Interface\\Addons\\HunterHelper\\fonts\\KozmikVibez.ttf", 10, "OUTLINE")
fammo.strType:SetPoint("CENTER",0,12)
fammo.strType:SetAlpha(0.7)
fammo.strType:SetText("Ammunition Type Name")
fammo.strCount = fammo:CreateFontString("FontString")
fammo.strCount:SetFont("Interface\\Addons\\HunterHelper\\fonts\\KozmikVibez.ttf", 22, "OUTLINE")
fammo.strCount:SetPoint("CENTER",0,0)
fammo.strCount:SetText("0000")
fammo.strCount:SetAlpha(0.7)
fammo:SetBackdrop({bgFile = "Interface/ChatFrame/ChatFrameBackground"})
fammo:SetBackdropColor(0,0,0,0)
fammo:SetWidth(100)
fammo:SetHeight(100)
fammo:SetFrameStrata("DIALOG")
fammo:SetPoint("CENTER", 0, 0)
fammo:RegisterEvent("UNIT_INVENTORY_CHANGED")
fammo:RegisterEvent("PLAYER_ENTERING_WORLD")
fammo:RegisterForDrag("LeftButton")
fammo:SetMovable()
fammo:Show()

fammo:SetScript("OnDragStart",function()	
	this:StartMoving()
end)
fammo:SetScript("OnDragStop",function()
	this:StopMovingOrSizing()
end)

fammo:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		local ammoframePos = GetDBVar("AmmoFrame","pos")
		if ammoframePos ~= nil then
			this:ClearAllPoints()
			this:SetPoint(unpack(ammoframePos))
		end
		ShowToast("HunterHelper", "Addon Loaded. Access menu with "..HH_SLASH_COMMAND)
	end

	if event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
		ttscan:SetOwner(UIParent,"ANCHOR_NONE")
		ttscan:SetInventoryItem("player",0)
		local ammoName = GetToolTipText(ttscan,"Left1")
		local ammoCount = "----"
		if ammoName == nil then
			ammoName = "No Ammo Equipped"
		else			
			ammoCount = GetInventoryItemCount("player", INVENTORY_SLOT_AMMO) or "0"			
		end
		fammo.strType:SetText(ammoName)
		fammo.strCount:SetText(ammoCount)
	end
end)

local fhh = CreateFrame("Frame", nil, WorldFrame)
fhh:SetBackdrop({bgFile = "Interface/ChatFrame/ChatFrameBackground"})
fhh:SetBackdropColor(0,0,0,0)
fhh:SetWidth(fhh:GetParent():GetWidth()/2)
fhh:SetHeight(fhh:GetParent():GetHeight()/2)
fhh:SetFrameStrata("DIALOG")
fhh:SetPoint("CENTER",0,0)
for _,evt in pairs({"ADDON_LOADED","SPELLS_CHANGED","ACTIONBAR_SLOT_CHANGED","PLAYER_ENTERING_WORLD"}) do
	fhh:RegisterEvent(evt)	
end
fhh:Hide()

local function cfout(text)
	_G["ChatFrame1"]:AddMessage( "|cFF00FF00[ash]|r "..tostring(text) )
end




local function VerifyToolTip(toolTip, verify)
	-- verify is a table containg members named according to regions in the tooltip to verify
	-- these are usually (always?) Left<n> or Right<n>
	-- e.g. verify = {Left1 = "Auto Shot", Left4 = "Requires Ranged Weapon"}
	
	if verify ~= nil and type(verify) == "table" then
		for k,v in pairs(verify) do
			local tipText = GetToolTipText(toolTip, k)
			if tipText ~= v then
				return false
			end
		end		
	end
	return true
end

local function CheckActionSlot(toolTip, slotId, verify)
	-- this function will verify that the actionslot (by slotId) in the player's action bars
	-- contains the tootlip text expected according to the verify table
	-- the function will ensure that the slotId actually has an action first
	-- then verify its contents, and lastly return the "title" of the tooltip (Left1)
	-- NOTE: 'verify' can be nil, in which case this function simply returns the title
	-- RETURNS
	-- if verification fails, or there is no action in slotId, the function returns false
	-- if the tooltip doesn't have a string in the FontString region "...Left1" it returns the empty string
	--
	
	if HasAction(slotId) == 1 then
		toolTip:SetAction(slotId)
				
		if VerifyToolTip(toolTip, verify) == false then
			return false -- failed verification
		end		
		local tipTitle = GetToolTipText(toolTip, "Left1")
		if tipTitle == nil then
			return ""
		else 
			return tostring(tipTitle)
		end
	end
	return false
end

local function CheckAutoShotInRange()
	
	-- verify that the current autoShotSlot is indeed that of auto shot
	if CheckActionSlot(ttscan, autoShotSlot, AUTO_SHOT_TIP) == false then
		autoShotSlot = nil
		debug("Auto Shot couldn't be found in action bar(s)")	
		ShowToast("Alert!" , HH_ERROR_AUTO_SHOT)
		fhh:SetBackdropColor(unpack(RANGED_HIDDEN))
		return
	end
	
	if UnitCanAttack("player","target") ~= 1 then
		fhh:SetBackdropColor(unpack(RANGED_UNATTACKABLE))
		return
	end
	
	if IsActionInRange(autoShotSlot) ~= 1 then
		fhh:SetBackdropColor(unpack(RANGED_OUTOFRANGE))
	else
		fhh:SetBackdropColor(unpack(RANGED_INRANGE))
	end
		
end

local function CheckPet()
	if GetUnitName("pet") ~= nil and GetPetHappiness() ~= nil then
		local oldHappiness = petHappiness
		petHappiness = GetPetHappiness()
		if petHappiness < oldHappiness then
			ShowToast("Pet Happiness!","Your pet is now "..tostring(PET_HAPPINESS[petHappiness]))
		end
	end
end

local function ScanForAutoShot()		
	debug("Scanning for Auto Shot action button ... ")
	ttscan:SetOwner(UIParent,"ANCHOR_NONE")
	for slotId=0,1000 do
		ttscan:SetAction(slotId)
		if CheckActionSlot(ttscan, slotId, AUTO_SHOT_TIP) ~= false then
			debug("Located autoshot in slot "..slotId)
			autoShotSlot = slotId			
			return true
		end
	end
	
	debug("Unable to locate auto shot, will try again on next ACTIONBAR_SLOT_CHANGED")
	fhh:SetBackdropColor(unpack(RANGED_HIDDEN))	
end

--[[

register the event SPELLS_CHANGED to scan through the player's spells
each spell will have an auto-shot activation rule associated with it

/cast could  be invoked by macros
CastSpell, CastSpellByName may be called by addons or /script macros
clicked actionbuttons call UseAction

basically, if UseAction is invoked, we need to check if the action used was a ranged ability
and if it was then we will engage auto shot

]]
  
function Set(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

local function EngageRegisteredSpell(spellName)
	if spellName == SPELL_AUTO_SHOT or HunterHelperDB.EnabledSpells[spellName] == HH_AUTO_ACTIVATE then
		if autoShotSlot ~= nil then
			if not IsAutoRepeatAction(autoShotSlot) then
				BLIZZ_CastSpellByName(SPELL_AUTO_SHOT)
			end
		end
	elseif HunterHelperDB.EnabledSpells[spellName] == HH_AUTO_STOP then		
		print("[HH] Stopping Auto Shot since "..spellName.." is flagged DISABLED")
		local w = GetTime() + 0.1
		-- not happy about this timing wise
		while GetTime() < w do
		end		
		SpellStopCasting()

	end
end

CastSpellByName = function(...)
	debug("CastSpellByName",unpack(arg))
	
	-- if not auto shot, cast it
	if arg[1] ~= SPELL_AUTO_SHOT then		
		BLIZZ_CastSpellByName(unpack(arg))
	end
	
	-- if the name corresponds to a spell that has been flagged to engage auto shot, we do so		
	EngageRegisteredSpell(arg[1])
end



CastSpell = function(...)
	debug("CastSpell",unpack(arg))
	if arg[2] == "spell" then
		-- check the spellbook, if this corresponds to a spell that engages auto shot, we do so
		ttscan:SetOwner(UIParent,"ANCHOR_NONE")
		ttscan:SetSpell(arg[1],"spell")
		
		local spellName = GetToolTipText(ttscan, "Left1")
		if spellName ~= SPELL_AUTO_SHOT then
			BLIZZ_CastSpell(unpack(arg))
		end		
		EngageRegisteredSpell(spellName)
	else
		BLIZZ_CastSpell(unpack(arg))
	end
end


UseAction = function(...)
	debug("UseAction",unpack(arg))
	ttscan:SetOwner(UIParent,"ANCHOR_NONE")
	ttscan:SetAction(arg[1])
	
	-- does this action engage auto shot?
	local spellName = GetToolTipText(ttscan, "Left1")
	if spellName ~= SPELL_AUTO_SHOT then
		BLIZZ_UseAction(unpack(arg))
	end	
	EngageRegisteredSpell(spellName)			
end


local function IterateHunterSpells(toolTip, fnCallback)
	toolTip:SetOwner(UIParent,"ANCHOR_NONE")
	local spellSlotNumber = 1
	for bookTabIndex=1, GetNumSpellTabs() do
		local tabName, _, _, numSpells = GetSpellTabInfo(bookTabIndex)
		debug("  scanning tab "..bookTabIndex.." ("..tabName..") with "..numSpells.." spell(s)")
		for spellIndex=1,numSpells do
			toolTip:SetSpell(spellSlotNumber, "spell")
			fnCallback(spellSlotNumber)
			spellSlotNumber = spellSlotNumber + 1
		end
	end
end

local function ScanHunterSpells()
	-- this function will go through the hunter's spellbook and every spell that "Requires Ranged Weapon"
	-- will be added to HunterHelperDB.EnabledSpells as HH_AUTO_ACTIVATE unless already in the list
	
	ttscan:SetOwner(UIParent,"ANCHOR_NONE")
	local spellSlotNumber = 1
	for bookTabIndex=1, GetNumSpellTabs() do
		local tabName, _, _, numSpells = GetSpellTabInfo(bookTabIndex)
		debug("  scanning tab "..bookTabIndex.." ("..tabName..") with "..numSpells.." spell(s)")
		for spellIndex=1,numSpells do
			ttscan:SetSpell(spellSlotNumber,"spell")
			local ranged = FindToolTipText(ttscan, "Requires Ranged Weapon") ~= nil
			
			spellName = GetSpellName(spellSlotNumber,"spell")
			isSpellPassive = IsSpellPassive(spellSlotNumber,"spell")
			debug("    ",{
				spellSlotNumber=tostring(spellSlotNumber),
				bookTabIndex=tostring(bookTabIndex),
				spellIndex=tostring(spellIndex),
				spellName=tostring(spellName),
				isSpellPassive=tostring(isSpellPassive),
				ranged=ranged,
				InSpellDB=tostring(HunterHelperDB.EnabledSpells[spellName])
			})
			
			if ranged == true and HunterHelperDB.EnabledSpells[spellName] == nil then
				HunterHelperDB.EnabledSpells[spellName] = HH_AUTO_ACTIVATE
				debug("    ", "Added "..spellName.." to activate Auto Shot")
			end
			
			spellSlotNumber = spellSlotNumber + 1
		end
	end
end

fhh:SetScript("OnEvent", function()
	debug("OnEvent "..event)
	if event == "ADDON_LOADED" and arg1 == STR_ADDON_NAME then
		if HunterHelperDB == nil then
			HunterHelperDB = {}
		end
		
		if HunterHelperDB.EnabledSpells == nil then
			HunterHelperDB.EnabledSpells = {
				["Scatter Shot"] = HH_AUTO_IGNORE -- flag as explicitly ignored
			}
		end

		if HunterHelperDB.AmmoFrame == nil then
			HunterHelperDB.AmmoFrame = {
				pos = {"CENTER", 0, 0}
			}
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- initial spell book scan and auto shot action location
		ScanHunterSpells()
		if ScanForAutoShot() ~= true then
			ShowToast("Can't Find Auto Shot", HH_ERROR_AUTO_SHOT)
		end
		fhh:Show()
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		-- whenever the action bar changes, scan it for auto shot
		ScanForAutoShot()
	elseif event == "SPELLS_CHANGED" then
		-- maybe something new was added
		ScanHunterSpells()
	end
end)

fhh:SetScript("OnUpdate", function()
	if autoShotSlot ~= nil then		
		if GetTime() >= nextRangeCheck then
			CheckAutoShotInRange()
			nextRangeCheck = GetTime() + HH_UPDATE_INTERVAL -- a pause before we check range again
		end
	end

	if GetTime() >= nextPetCheck then
		CheckPet()
		nextPetCheck = GetTime() + HH_PETCHECK_INTERVAL -- a pause
	end

end)

GameTooltip.overSpell = nil

local function AddToolTipInfo()
	local spellName = GetToolTipText(GameTooltip,"Left1")
	GameTooltip.overSpell = spellName
	local tipText = "IGNORED"
	local tipColor = {1,1,1}
	if HunterHelperDB.EnabledSpells[spellName] == HH_AUTO_ACTIVATE then
		tipText = "ENABLED"
		tipColor = {0,1,0}
	elseif HunterHelperDB.EnabledSpells[spellName] == HH_AUTO_STOP then
		tipText = "DISABLED"
		tipColor = {1,0.2,0.2}
	elseif HunterHelperDB.EnabledSpells[spellName] == HH_AUTO_IGNORE then
		tipText = "IGNORED"
		tipColor = {1,1,1}
	else
		-- if the spell isn't in the database per se, we simply don't add anything to the tooltip
		return
	end
	GameTooltip:AddDoubleLine("Auto Shot will be activated", tipText, 1, 1, 1, unpack(tipColor))
	GameTooltip:Show() -- ensure frame update
end


local BLIZZ_GameTooltip_SetAction = GameTooltip.SetAction
GameTooltip.SetAction = function(...)
	debug("GameTooltip.SetAction",unpack(arg))
	BLIZZ_GameTooltip_SetAction(unpack(arg))
	AddToolTipInfo()	
end

local BLIZZ_GameTooltip_SetSpell = GameTooltip.SetSpell
GameTooltip.SetSpell = function(...)
	debug("GameTooltip.SetSpell",unpack(arg))
	BLIZZ_GameTooltip_SetSpell(unpack(arg))
	AddToolTipInfo()
end
	
local BLIZZ_GameTooltip_OnHide = GameTooltip:GetScript("OnHide")
GameTooltip:SetScript("OnHide", function(...)
	-- clear our selected spell
	debug("GameTooltip:OnHide:",GameTooltip.overSpell)
	GameTooltip.overSpell = nil
	if BLIZZ_GameTooltip_OnHide ~= nil then
		BLIZZ_GameTooltip_OnHide(unpack(arg))
	end
end)


SLASH_HUNTERHELPER_SLASH1 = HH_SLASH_COMMAND
SlashCmdList["HUNTERHELPER_SLASH"] = function(input)	
	local params = {}
	for k in string.gfind(input, "%S+") do
		table.insert(params, k)
	end
	
	if input == "" or input == "help" then 
		print([[
		|cF9999FF0== Hunter Helper ==|r
		Adds a large overlay indicating in-range or out of range and allows spammable Auto Shot macros.
		In order to measure distance appropriately the Auto Shot spell must be dragged on to one of the player hotbars.
		By default, ALL hunter spells that require ranged weapons will be enabled, |cFF00FF00EXCEPT Scatter Shot|r.
		Any newly learned ranged spells will have the auto shot activation enabled.
		|cFF00FF00]]..HH_SLASH_COMMAND..[[ e[nable]||d[isable]||i[gnore] [Spell Name]|r
		If specified with |cFF00FF00Spell Name|r, will enable/disable that spell from forcefully activating auto shot.
		If not specified, the addon will enable/disable the current spell (in spellbook) or action (in action bar).
		|cFF00FF00e[nable]|r When using this spell, forced auto shot will be attempted, regardless of mana status, etc.
		|cFF00FF00d[isable]|r Spells flagged as disabled when used will cause the addon to force stopping of auto shot. 
		|cFF00FF00i[gnore]|r Spells used will follow the normal game reaction.
		|cFF00FF00]]..HH_SLASH_COMMAND..[[ resetspells||rs|r
		Reset all spell configurations to default. All ranged spells will have Auto Shot enforce enabled, except Scatter Shot.		
		|cFF00FF00]]..HH_SLASH_COMMAND..[[ resetframes||rf|r
		Reset all frame configurations in case something disappeared.
		|cFF00FF00]]..HH_SLASH_COMMAND..[[ alpha [in|out|err] <alpha value 0.0 to 1.0>|r
		Set the alpha of the in-range, or out-of-range pane. if pane isn't specified, will set for all panes.
		|cFF00FF00]]..HH_SLASH_COMMAND..[[ unlock|lock|r
		Unlock or lock frames and make them draggable across the screen, or lock them in place
		]])
	elseif input == "resetframes" or input == "rf" then
		SetDBVar({"CENTER",0,0}, "AmmoFrame", "pos")
		fammo:ClearAllPoints()
		fammo:SetPoint("CENTER",0,0)
	elseif input == "resetspells" or input == "rs" then
		-- force reset the enabled spells, then rescan all spells
		SetDBVar({["Scatter Shot"] = HH_AUTO_IGNORE}, "EnabledSpells")
		ScanHunterSpells()
		print("Reset all spell settings to default")
	elseif input == "unlock" then
		fammo:SetBackdropColor(0,0,0,0.5)
		fammo:EnableMouse(true)
		if ToastMaster ~= nil then
			ToastMaster:UnlockFrame()
		end
	elseif input == "lock" then
		fammo:SetBackdropColor(0,0,0,0.0)
		fammo:EnableMouse(false)
		local _,_,anchor,xpos,ypos = fammo:GetPoint("CENTER")
		SetDBVar({anchor,xpos,ypos}, "AmmoFrame", "pos")
		if ToastMaster ~= nil then
			ToastMaster:LockFrame()
		end		
	elseif params[1] == "alpha"	then
		
		local alphaValue = tonumber(params[2])
		local pane = "all"
		if alphaValue == nil then
			pane = params[2]
			alphaValue = tonumber(params[3])			
		end				
		
		if  pane == "all" or pane == "out" then
			RANGED_OUTOFRANGE[4] = alphaValue
		end
		if  pane == "all" or pane == "in" then
			RANGED_INRANGE[4] = alphaValue
		end
				
	else
		local spellName = params[2]
		if spellName == nil then
			if GameTooltip.overSpell ~= nil then
				spellName = GetToolTipText(GameTooltip,"Left1")
			else
				print("ERROR: Mouse over a spell in your spellbook or on the action bar")
				return
			end	
		end
		
		
		if string.find("enable","^"..params[1]) == 1 then
			HunterHelperDB.EnabledSpells[spellName] = HH_AUTO_ACTIVATE
		elseif string.find("disable","^"..params[1]) == 1 then
			HunterHelperDB.EnabledSpells[spellName] = HH_AUTO_STOP
		elseif string.find("ignore","^"..params[1]) == 1 then
			HunterHelperDB.EnabledSpells[spellName] = HH_AUTO_IGNORE
		else
			print("ERROR: Invalid syntax. /ash help for help")
			return
		end
		
		if HunterHelperDB.EnabledSpells[spellName] == HH_AUTO_ACTIVATE then
			print("Casting "..spellName.." will now attempt to engage Auto Shot ")
		elseif HunterHelperDB.EnabledSpells[spellName] == HH_AUTO_STOP then
			print("Casting "..spellName.." will now attempt to disable Auto Shot ")
		else
			print("Casting "..spellName.." will use game default actions")
		end
		GameTooltip:Hide()
		GameTooltip:Show()
	end	
end