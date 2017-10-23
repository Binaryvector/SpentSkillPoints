-- in this file we manipulte the skill window
-- the counting of skill points is done in SpentSkillPoints.lua

-- when the skill window is refreshed, we also need to refresh the displayed number of skill points
local oldRefresh = SKILLS_WINDOW.RefreshSkillInfo
SKILLS_WINDOW.RefreshSkillInfo = function( self )
	oldRefresh( self )
    
    self.availablePointsLabel:SetText(zo_strformat(SI_SKILLS_POINTS_TO_SPEND, self.availablePoints) .. "/" .. (SSP.GetTotalSpentPoints() + self.availablePoints))
end

-- replace the controls which display the skill lines on the left part of the skill window
-- with my own control
local oldAddNode = SKILLS_WINDOW.navigationTree.AddNode
SKILLS_WINDOW.navigationTree.AddNode = function( self, template, data, parentNode, selectSound )
	if template == "ZO_SkillIconHeader" then
		return oldAddNode( self, "SSP_Header", data, parentNode, selectSound )
	elseif template == "ZO_SkillsNavigationEntry" then
		return oldAddNode( self, "SSP_NavigationEntry", data, parentNode, selectSound )
	end
	return oldAddNode( self, template, data, parentNode, selectSound )
end

-- when a skill type (World, Class etc) control is initialized/refreshed, then add the spent skill points to it
local header = SKILLS_WINDOW.navigationTree.templateInfo["ZO_SkillIconHeader"]
local headerFunction = header.setupFunction
local function TreeHeaderSetup(node, control, skillType, open)
	headerFunction(node, control, skillType, open)
	local label = control:GetNamedChild("PointText")
	label:SetText(SSP.GetTypeSpentPoints( skillType )) 
end
SKILLS_WINDOW.navigationTree:AddTemplate("SSP_Header", TreeHeaderSetup, nil, nil, nil, 0)

-- function which returns the maximum rank for each skill line
-- this information is nedded to format the skill level
local function GetMaxRank(skillType, skillLine)
	if skillType == SKILL_TYPE_AVA or
		skillType == SKILL_TYPE_GUILD then
		local name = GetSkillLineInfo(skillType, skillLine)
		if name == "Thieves Guild" or "Diebesgilde^f" or "Guilde des voleurs^f" then
			return 12
		end
		if name == "Dark Brotherhood" or "dunkle Bruderschaft^fdc" or "Confrérie noire^f" then
			return 12
		end
		return 10
	end
	if skillType == SKILL_TYPE_WORLD then
		local name = GetSkillLineInfo(skillType, skillLine)
		if name == "Legerdemain" or name == "Lug und Trug^N" or name == "Escroquerie" then
			return 20
		else
			return 10
		end
	end
	return 50
end

local navigationSetup = SKILLS_WINDOW.navigationTree.templateInfo["ZO_SkillsNavigationEntry"].setupFunction
local navigationSelect = SKILLS_WINDOW.navigationTree.templateInfo["ZO_SkillsNavigationEntry"].selectionFunction
local navigationEQ = SKILLS_WINDOW.navigationTree.templateInfo["ZO_SkillsNavigationEntry"].equalityFunction
-- the function which initalizes/refreshes the skill line control
local function TreeEntrySetup(node, control, data, open)
	-- initialize the control with skill line name etc
	navigationSetup(node, control, data, open)
	-- now we add our custom information
	local label = control:GetNamedChild("PointText")
	-- do we want to colorize the skill line?
	if SSP.settings.color then
		-- add the colorized number of spent skill points in this skill line
		local quote = SSP.GetLineSpentPoints( data.skillType, data.skillLineIndex ) / SSP.GetLinePossiblePoints( data.skillType, data.skillLineIndex )
		local red = 255 * (1-quote)
		local green = 255 * quote
		label:SetText(
			string.format("|c%02x%02x%02x%d|r", red, green, 0, SSP.GetLineSpentPoints( data.skillType, data.skillLineIndex ))
			)
		-- add the colorized rank for this skill line
		label = control:GetNamedChild("LevelText")
		local _, rank = GetSkillLineInfo(data.skillType, data.skillLineIndex)
		quote = rank / GetMaxRank(data.skillType, data.skillLineIndex)
		red = 255 * (1-quote)
		green = 255 * quote
		label:SetText(
			string.format("|c%02x%02x%02x%d|r", red, green, 0, rank)
			)
	else
		-- add number of spent skill points and the rank of the skill line
		label:SetText(SSP.GetLineSpentPoints( data.skillType, data.skillLineIndex ))
		label = control:GetNamedChild("LevelText")
		local _, rank = GetSkillLineInfo(data.skillType, data.skillLineIndex)
		label:SetText(rank)
	end
end

SKILLS_WINDOW.navigationTree:AddTemplate("SSP_NavigationEntry", TreeEntrySetup, navigationSelect, navigationEQ)
