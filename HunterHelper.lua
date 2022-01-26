local _G = getfenv(0)
local HH_SLASH_COMMAND		= "/huh"
local HH_DB_VERSION			= 2
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
local HUNTER_ASPECT_SPELLS	= Utils.Set("Aspect of the Monkey","Aspect of the Cheetah","Aspect of the Hawk","Aspect of the Beast","Aspect of the Wild")
local HUNTER_ASPECTS		= {monkey="Aspect of the Monkey",cheetah="Aspect of the Cheetah",hawk="Aspect of the Hawk",beast="Aspect of the Beast",wild="Aspect of the Wild"}
local MOD_KEYS				= {alt=1,shift=1,ctrl=3}
local HH_ERROR_AUTO_SHOT 	= "HunterHelper could not locate Auto Shot on your action bar. Drag Auto Shot from your spellbook into an open action bar slot, or a macro named Auto Shot."
local debugEnabled 			= true

local function debug(...)
	-- local helper function to print to system console OR the global ScriptEditor addon ScriptEditor:Log function
	if debugEnabled == false then return end
	
	if ScriptEditor ~= nil then
		ScriptEditor:Log(unpack(arg))
	else
		local text = Utils.ArgsToStr(unpack(arg))
		cfout(text)
	end
end


local function print(...)
	-- local helper function to print to system console
	local text = Utils.ArgsToStr(unpack(arg))
	_G["ChatFrame1"]:AddMessage(text)
end




local function ShowToast(title, text, settings)
	-- if the toastmaster was loaded in, we use it. if not, just dump the text to chat frame
	if ToastMaster ~= nil then
		ToastMaster:AddToast(title, text, settings)
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
		local ammoframePos = Utils.GetDBCharVar(HunterHelperDB, "AmmoFrame", "pos")
		if ammoframePos ~= nil then
			this:ClearAllPoints()
			this:SetPoint(unpack(ammoframePos))
		end		
	end

	if event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
		ttscan:SetOwner(UIParent,"ANCHOR_NONE")
		ttscan:SetInventoryItem("player",0)
		local ammoName = Utils.GetToolTipText(ttscan,"Left1")
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
for _,evt in pairs({"ADDON_LOADED","SPELLS_CHANGED","ACTIONBAR_SLOT_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_AURAS_CHANGED"}) do
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
			local tipText = Utils.GetToolTipText(toolTip, k)
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
		local tipTitle = Utils.GetToolTipText(toolTip, "Left1")
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

local function EngageAutoShot(spellName)
	local enabledStatus = Utils.GetDBCharVar(HunterHelperDB, "EnabledSpells", spellName)
	if spellName == SPELL_AUTO_SHOT or enabledStatus == HH_AUTO_ACTIVATE then
		if autoShotSlot ~= nil then
			if not IsAutoRepeatAction(autoShotSlot) then
				-- this is a spell that activates auto shot, so we do so now!
				BLIZZ_CastSpellByName(SPELL_AUTO_SHOT)
			end
		end
	elseif enabledStatus == HH_AUTO_STOP then		
		-- this is a spell that DISABLES auto shot so we do so now
		print("[HH] Stopping Auto Shot since "..spellName.." is flagged DISABLED")
		local w = GetTime() + 0.1
		-- not happy about this timing wise
		while GetTime() < w do
		end		
		SpellStopCasting()
	end
end

function CheckAspectCast(spellName)
	if HUNTER_ASPECT_SPELLS[spellName] == nil then
		return true -- this is not an aspect
	end	
	debug("CheckAspectCast:", spellName, "has", fhh.currentBuffs)
	return fhh.currentBuffs[spellName] == nil	
end

CastSpellByName = function(...)
	debug("CastSpellByName",unpack(arg))
	
	if CheckAspectCast(arg[1]) == false then
		-- casting an aspect we already have, bail out
		return
	end

	-- if not auto shot, cast it
	if arg[1] ~= SPELL_AUTO_SHOT then		
		BLIZZ_CastSpellByName(unpack(arg))
	end
	
	-- if the name corresponds to a spell that has been flagged to engage auto shot, we do so		
	EngageAutoShot(arg[1])
end



CastSpell = function(...)
	debug("CastSpell",unpack(arg))
	if arg[2] == "spell" then
		-- check the spellbook, if this corresponds to a spell that engages auto shot, we do so
		ttscan:SetOwner(UIParent,"ANCHOR_NONE")
		ttscan:SetSpell(arg[1],"spell")
		
		local spellName = Utils.GetToolTipText(ttscan, "Left1")

		if CheckAspectCast(spellName) == false then
			-- casting an aspect we already have, bail out
			return
		end

		if spellName ~= SPELL_AUTO_SHOT then
			BLIZZ_CastSpell(unpack(arg))
		end		
		EngageAutoShot(spellName)
			
	else
		BLIZZ_CastSpell(unpack(arg))
	end
end


UseAction = function(...)
	debug("UseAction",unpack(arg))
	ttscan:SetOwner(UIParent,"ANCHOR_NONE")
	ttscan:SetAction(arg[1])
	
	-- does this action engage auto shot?
	local spellName = Utils.GetToolTipText(ttscan, "Left1")

	if CheckAspectCast(spellName) == false then
		-- casting an aspect we already have, bail out
		return
	end
	
	if spellName ~= SPELL_AUTO_SHOT then
		BLIZZ_UseAction(unpack(arg))
	end	
	EngageAutoShot(spellName)			
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
			local enabledStatus = Utils.GetDBCharVar(HunterHelperDB, "EnabledSpells", spellName)
			debug("    ",{
				spellSlotNumber=tostring(spellSlotNumber),
				bookTabIndex=tostring(bookTabIndex),
				spellIndex=tostring(spellIndex),
				spellName=tostring(spellName),
				isSpellPassive=tostring(isSpellPassive),
				ranged=ranged,
				InSpellDB=tostring(enabledStatus)
			})
			
			if ranged == true and enabledStatus == nil then
				Utils.SetDBCharVar(HunterHelperDB, HH_AUTO_ACTIVATE, "EnabledSpells", spellName)
				debug("    ", "Added "..spellName.." to activate Auto Shot")
			end
			
			spellSlotNumber = spellSlotNumber + 1
		end
	end
end

fhh:SetScript("OnEvent", function()
	debug("OnEvent "..event)
	if event == "ADDON_LOADED" and arg1 == STR_ADDON_NAME then
		
		if HunterHelperDB == nil or HunterHelperDB.version ~= HH_DB_VERSION then			
			HunterHelperDB = {version = HH_DB_VERSION}
		end

		playerVars = Utils.GetDBCharVar(HunterHelperDB)
		if playerVars == nil then
			Utils.SetDBCharVar(HunterHelperDB, {})
		end

		if Utils.GetDBCharVar(HunterHelperDB, "EnabledSpells") == nil then
			Utils.SetDBCharVar(HunterHelperDB, {["Scatter Shot"] = HH_AUTO_IGNORE}, "EnabledSpells")
		end

		if Utils.GetDBCharVar(HunterHelperDB, "AmmoFrame", "pos") == nil then
			Utils.SetDBCharVar(HunterHelperDB, {pos={"CENTER",0,0}}, "AmmoFrame")
		end
		ShowToast("HunterHelper", "Addon Loaded. Access menu with "..HH_SLASH_COMMAND,{persistent=false})
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- initial spell book scan and auto shot action location
		ScanHunterSpells()
		if ScanForAutoShot() ~= true then
			ShowToast("Can't Find Auto Shot", HH_ERROR_AUTO_SHOT)
		end
		fhh.currentBuffs = Utils.ScanBuffs(ttscan, "player")
		debug("current_buffs_start", fhh.currentBuffs)
		fhh:Show()
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		-- whenever the action bar changes, scan it for auto shot
		ScanForAutoShot()
	elseif event == "SPELLS_CHANGED" then
		-- maybe something new was added
		ScanHunterSpells()
	elseif event == "PLAYER_AURAS_CHANGED" then
		fhh.currentBuffs = Utils.ScanBuffs(ttscan, "player")
		debug("current_buffs", fhh.currentBuffs)
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
	local spellName = Utils.GetToolTipText(GameTooltip,"Left1")
	GameTooltip.overSpell = spellName
	local tipText = "IGNORED"
	local tipColor = {1,1,1}
	
	local enabledStatus = Utils.GetDBCharVar(HunterHelperDB, "EnabledSpells", spellName)
	if enabledStatus == HH_AUTO_ACTIVATE then
		tipText = "ENABLED"
		tipColor = {0,1,0}
	elseif enabledStatus == HH_AUTO_STOP then
		tipText = "DISABLED"
		tipColor = {1,0.2,0.2}
	elseif enabledStatus == HH_AUTO_IGNORE then
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
		|cFF00FF00]]..HH_SLASH_COMMAND..[[ aspect <aspect> {<aspect>} {<mod> {<mod>} <aspect> {<aspect>}}
		Implements an aspect-sequence macro. any list of aspects will be rotated through following the modifier key
		combination presented. e.g.
		|c0000ff00aspect beast hawk monkey|r will rotate through these aspects left-to-right, starting with beast. 
		|c0000ff00aspect beast hawk alt monkey|r will rotate through beast,hawk aspects, but with alt pressed, will cast monkey.
		]])
	elseif params[1] == "aspect" and params[2] ~= nil then
		-- aspect <aspect> {<aspect>} {'['<mod>']' <aspect> {<aspect>}
		

		-- brackets are just decorative, the parser can work without separation characters
		-- e.g. you could write /huh aspect cheetah monkey alt hawk shift beast

		function MatchAspect(text)
			text = string.lower(text)
			for aspect,spell in pairs(HUNTER_ASPECTS) do
				if string.find(aspect, "^"..text) then
					return aspect
				end
			end
			return nil
		end
		
		-- go through parameters looking for aspects until we find a modifier
		local aspectMacro = {
			[""] = {}
		}
		local modKeyBuilder = {}
		local currentMod = ""
		
		local pos = 2
		table.remove(params, 1)
		for i,token in pairs(params) do
			token = string.lower(token)
			token = string.gsub(token, "[^a-z]", "")
			local nextAspect = MatchAspect(token)
			if nextAspect ~= nil then
				-- this was an aspect name
				if modKeyBuilder ~= nil then
					-- a new modifier list is started
					currentMod = (modKeyBuilder.alt and "alt" or "")..(modKeyBuilder.ctrl and "ctrl" or "")..(modKeyBuilder.shift and "shift" or "")
					if currentMod ~= "" and aspectMacro[currentMod] ~= nil then
						print("ERROR: The macro duplicates the '"..currentMod.."' state")
						return
					end
					aspectMacro[currentMod] = {}
					modKeyBuilder = nil
				end
				table.insert(aspectMacro[currentMod], nextAspect)
			elseif MOD_KEYS[token] ~= nil then
				-- a valid mod key, build the mod key identifier: [alt][ctrl][shift]
				if modKeyBuilder == nil then
					modKeyBuilder = {}
				end
				modKeyBuilder[token] = true
			else
				print("ERROR: Unrecognized aspect/modifier key '"..token.."'")
				return
			end
		end

		local keyState = (IsAltKeyDown() and "alt" or "")..(IsControlKeyDown() and "ctrl" or "")..(IsShiftKeyDown() and "shift" or "")
		 
		debug(aspectMacro)		
		debug("keystate", tostring(keyState))

		if aspectMacro[keyState] == nil then
			print("WARNING: This macro has no state for "..keyState..", falling back on normal")
			keyState = ""
		end

		-- identify the player aspect state
		-- if we have an aspect present in the sequence, we switch to the next (or roll over)
		for i,aspect in ipairs(aspectMacro[keyState]) do
			if fhh.currentBuffs[HUNTER_ASPECTS[aspect]] ~= nil then
				-- we found an active buff in this sequence, cast the next one (or first)
				local castAspect = aspectMacro[keyState][i+1] or aspectMacro[keyState][1]
				CastSpellByName(HUNTER_ASPECTS[castAspect])
				return
			end
		end

		-- if we reach this point, the player did not have an aspect that of in the sequence, so we cast the first in the sequence
		CastSpellByName(HUNTER_ASPECTS[aspectMacro[keyState][1]])

	elseif input == "resetframes" or input == "rf" then
		Utils.SetDBCharVar(HunterHelperDB, {pos={"CENTER",0,0}}, "AmmoFrame")
		fammo:ClearAllPoints()
		fammo:SetPoint("CENTER",0,0)
	elseif input == "resetspells" or input == "rs" then
		-- force reset the enabled spells, then rescan all spells
		Utils.SetDBCharVar(HunterHelperDB, {["Scatter Shot"] = HH_AUTO_IGNORE}, "EnabledSpells")
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
		Utils.SetDBCharVar(HunterHelperDB,  {anchor,xpos,ypos}, "AmmoFrame", "pos")
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
				spellName = Utils.GetToolTipText(GameTooltip,"Left1")
			else
				print("ERROR: Mouse over a spell in your spellbook or on the action bar")
				return
			end	
		end
		
		local enabledStatus = 0
		if string.find("enable","^"..params[1]) == 1 then
			enabledStatus = HH_AUTO_ACTIVATE
		elseif string.find("disable","^"..params[1]) == 1 then
			enabledStatus = HH_AUTO_STOP
		elseif string.find("ignore","^"..params[1]) == 1 then
			enabledStatus = HH_AUTO_IGNORE
		else
			print("ERROR: Invalid syntax. /ash help for help")
			return
		end

		Utils.SetDBCharVar(HunterHelperDB, enabledStatus, "EnabledSpells", spellName)
		
		if enabledStatus == HH_AUTO_ACTIVATE then
			print("Casting "..spellName.." will now attempt to engage Auto Shot ")
		elseif enabledStatus == HH_AUTO_STOP then
			print("Casting "..spellName.." will now attempt to disable Auto Shot ")
		else
			print("Casting "..spellName.." will use game default actions")
		end
		GameTooltip:Hide()
		GameTooltip:Show()
	end	
end