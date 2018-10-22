-- in this file we manipulte the skill window
-- the counting of skill points is done in SpentSkillPoints.lua

-- when the skill window is refreshed, we also need to refresh the displayed number of skill points
local oldRefresh = SKILLS_WINDOW.RefreshSkillPointInfo
SKILLS_WINDOW.RefreshSkillPointInfo = function( self )
	oldRefresh( self )
    
	local availablePoints = SKILL_POINT_ALLOCATION_MANAGER:GetAvailableSkillPoints()
    self.availablePointsLabel:SetText(zo_strformat(SI_SKILLS_POINTS_TO_SPEND, availablePoints) .. "/" .. (SSP.GetTotalSpentPoints() + availablePoints))
end

-- replace the controls which display the skill lines on the left part of the skill window
-- with my own control
local oldAddNode = SKILLS_WINDOW.skillLinesTree.AddNode
SKILLS_WINDOW.skillLinesTree.AddNode = function( self, template, data, parentNode, selectSound )
	if template == "ZO_SkillIconHeader" then
		return oldAddNode( self, "SSP_Header", data, parentNode, selectSound )
	elseif template == "ZO_SkillsNavigationEntry" then
		return oldAddNode( self, "SSP_NavigationEntry", data, parentNode, selectSound )
	end
	return oldAddNode( self, template, data, parentNode, selectSound )
end

-- when a skill type (World, Class etc) control is initialized/refreshed, then add the spent skill points to it
local header = SKILLS_WINDOW.skillLinesTree.templateInfo["ZO_SkillIconHeader"]
local headerFunction = header.setupFunction
local function TreeHeaderSetup(node, control, skillTypeData, open)
	headerFunction(node, control, skillTypeData, open)
	local label = control:GetNamedChild("PointText")
	local skillType = skillTypeData:GetSkillType()
	label:SetText(SSP.GetTypeSpentPoints( skillType )) 
end
SKILLS_WINDOW.skillLinesTree:AddTemplate("SSP_Header", TreeHeaderSetup, nil, nil, nil, 0)

local navigationSetup = SKILLS_WINDOW.skillLinesTree.templateInfo["ZO_SkillsNavigationEntry"].setupFunction
local navigationSelect = SKILLS_WINDOW.skillLinesTree.templateInfo["ZO_SkillsNavigationEntry"].selectionFunction
local navigationEQ = SKILLS_WINDOW.skillLinesTree.templateInfo["ZO_SkillsNavigationEntry"].equalityFunction
-- the function which initalizes/refreshes the skill line control
local function TreeEntrySetup(node, control, data, open)
	local skillType, skillLineIndex = data:GetIndices()
	-- initialize the control with skill line name etc
	navigationSetup(node, control, data, open)
	-- now we add our custom information
	local label = control:GetNamedChild("PointText")
	-- do we want to colorize the skill line?
	if SSP.settings.color then
		-- todo, i should probably use this
		--SKILL_POINT_ALLOCATION_MANAGER:GetNumPointsAllocatedInSkillLine(self)
		-- add the colorized number of spent skill points in this skill line
		local quote = SSP.GetLineSpentPoints( skillType, skillLineIndex ) / SSP.GetLinePossiblePoints( skillType, skillLineIndex )
		local red = 255 * (1-quote)
		local green = 255 * quote
		label:SetText(
			string.format("|c%02x%02x%02x%d|r", red, green, 0, SSP.GetLineSpentPoints( skillType, skillLineIndex ))
			)
		-- add the colorized rank for this skill line
		label = control:GetNamedChild("LevelText")
		local rank = data:GetCurrentRank()
		--local _, rank = GetSkillLineInfo(skillType, skillLineIndex)
		quote = rank / SSP.GetMaxRank(skillType, skillLineIndex)
		red = 255 * (1-quote)
		green = 255 * quote
		label:SetText(
			string.format("|c%02x%02x%02x%d|r", red, green, 0, rank)
			)
	else
		-- add number of spent skill points and the rank of the skill line
		label:SetText(SSP.GetLineSpentPoints( skillType, skillLineIndex ))
		label = control:GetNamedChild("LevelText")
		local _, rank = GetSkillLineInfo(skillType, skillLineIndex)
		label:SetText(rank)
	end
end

SKILLS_WINDOW.skillLinesTree:AddTemplate("SSP_NavigationEntry", TreeEntrySetup, navigationSelect, navigationEQ)
