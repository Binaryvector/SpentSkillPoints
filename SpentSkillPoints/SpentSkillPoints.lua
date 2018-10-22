-- in this file we calculate the number of spent skill points
-- the UI stuff (displaying the number) is done in SpentSkillPoiuntsUI.lua

SSP = {}
local SpentSkillPoints = SSP -- local reference for performance
-- iterating over the entire skill structure is pretty cost intensive
-- so we cache the result
SpentSkillPoints.cache = {}
-- the order of skill lines is different for each language (alphabetically)
-- so we need to know the game's language
SpentSkillPoints.language = (GetCVar("language.2") or "en")

-- global functions we are going to use
local getNumSkillTypes = GetNumSkillTypes
local getNumSkillLines = GetNumSkillLines
local getNumSkillAbilities = GetNumSkillAbilities
local getSkillAbilityInfo = GetSkillAbilityInfo
local getAbilityProgressionInfo = GetAbilityProgressionInfo
local getSkillAbilityUpgradeInfo = GetSkillAbilityUpgradeInfo
local getSkillLineInfo = GetSkillLineInfo

-- skills are ordered by:
-- skill type (weapon, class, world etc) -> skill line (bow, dual wield etc) -> skill index (the skill itself)
-- we simply iterate recursively over this strucutre to calculate the number of spent/possible skill points
-- in each skill type, skill line and skill 

-- each funciton has a Get and Set version
-- the get function returns the number of skill points
-- it will try to return a cached value, if the value doesn't exist
-- the Set version is called, which will calculate the value

function SpentSkillPoints.GetTotalSpentPoints()
	if not SpentSkillPoints.cache.total then
		SpentSkillPoints.SetTotalSpentPoints()
	end
	return SpentSkillPoints.cache.total
end

function SpentSkillPoints.SetTotalSpentPoints()
	SpentSkillPoints.cache.skillTypes = {}
	SpentSkillPoints.cache.total = 0
	local num = getNumSkillTypes()
	
	for i=1,num do
		SpentSkillPoints.cache.total = SpentSkillPoints.cache.total + SpentSkillPoints.SetTypeSpentPoints( i )
	end
	
	return SpentSkillPoints.cache.total
end

function SpentSkillPoints.GetTypeSpentPoints( skillType )
	if not SpentSkillPoints.cache.skillTypes then
		SpentSkillPoints.GetTotalSpentPoints()
	end
	
	if not SpentSkillPoints.cache.skillTypes[ skillType ] then
		SpentSkillPoints.SetTypeSpentPoints( skillType )
	end
	return SpentSkillPoints.cache.skillTypes[ skillType ].total
end

function SpentSkillPoints.SetTypeSpentPoints( skillTypeId )
	SpentSkillPoints.cache.skillTypes[ skillTypeId ] = {}
	local skillType = SpentSkillPoints.cache.skillTypes[ skillTypeId ]
	skillType.lines = {}
	skillType.total = 0
	local num = getNumSkillLines( skillTypeId )
	
	for i=1,num do
		skillType.total = skillType.total + SpentSkillPoints.SetLineSpentPoints( skillTypeId, i )
	end
	
	return skillType.total
end

function SpentSkillPoints.GetLineSpentPoints( skillType, skillLine )
	if not SpentSkillPoints.cache.skillTypes then
		SpentSkillPoints.GetTotalSpentPoints()
	end
	
	if not SpentSkillPoints.cache.skillTypes[ skillType ] then
		SpentSkillPoints.SetTypeSpentPoints( skillType )
	end
	
	if not SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine] then
		SpentSkillPoints.SetLineSpentPoints( skillType, skillLine )
	end
	
	return SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine].total
end

SpentSkillPoints.racialLines = {
	--RaceId    SkillLine   Race
	[1]  = 60,       --Breton
	[2]  = 62,       --Redguard
	[3]  = 52,       --Orc
	[4]  = 64,       --Dark Elf
	[5]  = 65,       --Nord
	[6]  = 63,       --Argonian
	[7]  = 56,       --High Elf
	[8]  = 57,      --Wood Elf
	[9]  = 58,       --Khajiit
	[10] = 59,       --Imperial
}

function SpentSkillPoints.SetLineSpentPoints( skillType, skillLine )
	local name, _, _, skillLineId = GetSkillLineInfo( skillType, skillLine )
	--d(name, skillLineId)
	if skillType ~= SKILL_TYPE_RACIAL or (skillType == SKILL_TYPE_RACIAL and skillLineId == SpentSkillPoints.racialLines[GetUnitRaceId("player")]) then
		SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine] = {}
		local line = SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine]
		line.skills = {}
		line.total = 0
		line.possible = 0
		local num = getNumSkillAbilities(skillType, skillLine )
		local spent
		for i=1,num do
			spent = SpentSkillPoints.SetSkillSpentPoints( skillType, skillLine, i )
			line.total = line.total + spent[1]
			line.possible = line.possible + spent[2]
		end
		
		return line.total
	end
	return 0
end

function SpentSkillPoints.GetLinePossiblePoints( skillType, skillLine )
	-- this is only called to refresh the values and load them into the cache,
	-- if they aren't cached already
	local total = SpentSkillPoints.GetLineSpentPoints( skillType, skillLine )
	-- now that everything was calculated and cached, we can savely access the cached results
	return SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine].possible
end

function SpentSkillPoints.GetSkillSpentPoints( skillType, skillLine, skillIndex )
	if not SpentSkillPoints.cache.skillTypes then
		SpentSkillPoints.GetTotalSpentPoints()
	end
	
	if not SpentSkillPoints.cache.skillTypes[ skillType ] then
		SpentSkillPoints.SetTypeSpentPoints( skillType )
	end
	
	if not SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine] then
		SpentSkillPoints.SetLineSpentPoints( skillType, skillLine )
	end
	
	if not SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine].skills[skillIndex] then
		SpentSkillPoints.SetSkillSpentPoints( skillType, skillLine, skillIndex )
	end
	
	return SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine].skills[skillIndex]
end

function SpentSkillPoints.SetSkillSpentPoints( skillType, skillLine, skillIndex )
	local skills = SpentSkillPoints.cache.skillTypes[ skillType ].lines[skillLine].skills
	local _, _, _, _, _, purchased, progressionIndex = getSkillAbilityInfo( skillType, skillLine, skillIndex )
	local spent, possible, reduction
	
	-- if the skill wasn't purchased, then there was obviously no skill point spent
	-- though we won't return, as we also need to calculate the number of skill points
	-- that can be spent for this skill
	if not purchased then
		spent = 0
	end
	-- some abilities start with rank 1, in such a case we musn't count rank 1 as a spent skill point
	-- that's why we will later substract the value returned by SpentSkillPoints.ReduceAbility
	reduction = SpentSkillPoints.ReduceAbility( skillType, skillLine, skillIndex )
	-- is this a morphable ability?
	if progressionIndex then
		local _, morph = getAbilityProgressionInfo( progressionIndex )
		-- if we spent at least one skill point in this ability...
		if not spent then
			-- ...and we morphed the ability, then we have spent 2 skill points...
			if morph > 0 then
				spent = 2 - reduction
			else
				-- ...otherwise we have spent only one skill point
				spent = 1 - reduction
			end
		end
		possible = 2 - reduction
	else
		-- for unmorphable abilities, we can simply use the rank to get the number of spent skill points
		local currentLevel, maxLevel = getSkillAbilityUpgradeInfo( skillType, skillLine, skillIndex )
		if currentLevel then
			if not spent then
				spent = currentLevel - reduction
			end
			possible = maxLevel - reduction
		else
			if not spent then
				spent = 1 - reduction
			end
			possible = 1 - reduction
		end
	end
	-- cache the results
	skills[skillIndex] = {spent, possible}
	return skills[skillIndex]
end


local enchantingSkillType, enchantingSkillLine = GetCraftingSkillLineIndices(CRAFTING_TYPE_ENCHANTING)
local provisionSkillType, provisionSkillLine = GetCraftingSkillLineIndices(CRAFTING_TYPE_PROVISIONING)

local DARK_BROTHERHOOD = 118
local FIGHTERS_GUILD = 45
local MAGES_GUILD = 44
local THIEVES_GUILD = 117
local UNDAUNTED = 55
local SOUL_MAGIC = 72
local LEGERDEMAIN = 111
local PSIJIIC_ORDER = 130

-- function which returns the maximum rank for each skill line
-- this information is nedded to format the skill level
function SpentSkillPoints.GetMaxRank(skillType, skillLine)
	if skillType == SKILL_TYPE_AVA or
		skillType == SKILL_TYPE_GUILD then
		local name, _, _, skillLineId = GetSkillLineInfo(skillType, skillLine)
		if skillLineId == THIEVES_GUILD then
			return 12
		end
		if skillLineId == DARK_BROTHERHOOD then
			return 12
		end
		return 10
	end
	if skillType == SKILL_TYPE_WORLD then
		local name, _, _, skillLineId = GetSkillLineInfo(skillType, skillLine)
		if skillLineId == LEGERDEMAIN then
			return 20
		else
			return 10
		end
	end
	return 50
end

function SpentSkillPoints.ReduceAbility( skillType, skillLine, skillIndex )
	if skillType == SKILL_TYPE_WORLD then
		local name, _, _, skillLineId = getSkillLineInfo(skillType, skillLine)
		-- everyone has access to soul trap without spending a skill point
		if skillLineId == SOUL_MAGIC then
			if skillIndex == 2 then
				return 1
			end
		end
		-- werewolves have access to their ultimate without spending a skill point
		if IsWerewolfSkillLine(skillType, skillLine) then
			if skillIndex == 1 then
				return 1
			end
		end
	end
	if skillType == SKILL_TYPE_TRADESKILL then
		if skillIndex == 1 then
			return 1 -- first trade skill rank is always free
		end
		
		-- echantment and provision have another free skill
		if skillIndex == 2 then
			if skillType == enchantingSkillType and skillLine == enchantingSkillLine then
				return 1
			end
			if skillType == provisionSkillType and skillLine == provisionSkillLine then
				return 1
			end
		end
	end
	
	local name, _, _, skillLineId = getSkillLineInfo(skillType, skillLine)
	if skillType == SKILL_TYPE_RACIAL and skillLineId == SpentSkillPoints.racialLines[GetUnitRaceId("player")] and skillIndex == 1 then
		-- racial exp bonus is free
		return 1
	end
	
	if skillType == SKILL_TYPE_GUILD then
		local name, _, _, skillLineId = getSkillLineInfo(skillType, skillLine)
		-- tg and db first skill is free
		if skillLineId == THIEVES_GUILD then
			if skillIndex == 1 then
				return 1
			end
		end
		
		if skillLineId == DARK_BROTHERHOOD then
			if skillIndex == 1 then
				return 1
			end
		end
		
		if skillLineId == PSIJIIC_ORDER then
			if skillIndex == 7 then
				return 1
			end
		end
	end
	return 0
end

-- if the number of skill points changed, we should calculate everything again
-- as there might be a new spent skill point somewhere or maybe there was a skill reset
function SpentSkillPoints.OnSkillPointsChanged( _, oldPoints, newPoints, oldSkyshards, newSkyshards )
	if oldPoints ~= newPoints then
		SpentSkillPoints.SetTotalSpentPoints()
	end
end

function SpentSkillPoints.ToggleColor( ... )
	SpentSkillPoints.settings.color = not SpentSkillPoints.settings.color
	if SpentSkillPoints.settings.color then
		d("Enabled colors for SpentSkillPoints.")
	else
		d("Disabled colors for SpentSkillPoints.")
	end
end

function SpentSkillPoints.OnLoad(eventCode, addOnName)
	if addOnName ~= "SpentSkillPoints" then
		return
	end
	SpentSkillPoints.cache = {}
	if not SpentSkillPoints.cache.total then
		SpentSkillPoints.SetTotalSpentPoints()
	end
	
	SLASH_COMMANDS["/ssp_color"] = SpentSkillPoints.ToggleColor
	
	SpentSkillPoints.settings = ZO_SavedVars:New("SSP_SavedVars", 2, "settings", {color = false})
	
	EVENT_MANAGER:RegisterForEvent("SpentSkillPoints", EVENT_SKILL_POINTS_CHANGED, SpentSkillPoints.OnSkillPointsChanged)
end

EVENT_MANAGER:RegisterForEvent("SpentSkillPoints", EVENT_ADD_ON_LOADED, SpentSkillPoints.OnLoad)