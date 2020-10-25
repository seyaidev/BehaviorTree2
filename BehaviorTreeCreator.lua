--[[
	BEHAVIOR TREE CREATOR V2
	
	Originally by tyridge77: https://devforum.roblox.com/t/btrees-visual-editor-v2-0/461015
	Forked and improved by defaultio

	Improvements/changes:
		- Changed TreeCreator:Create parameters from obj, treeFolder to treeFolder, obj. Made obj parameter optional.
		- Trees are created and cached from the tree folder directly, rather than a string treeindex.
		- Added :SetTreeID(treeFolder, treeId) for use with Tree nodes
		- Added comments/documentation
	
--]]

local TreeCreator = {}
local BehaviorTree3 = require(script.BehaviorTree3)

local Trees = {}
local SourceTasks = {}
local TreeIDs = {}


--------------------------------------------
-------------- PUBLIC METHODS --------------

-- Create tree object from a treeFolder. Optionaal object parameter to associate with the tree
function TreeCreator:Create(treeFolder, obj)
	assert(treeFolder, "Invalid parameters, expecting treeFolder, object")
	
	local Tree = self:_getTree(treeFolder)
	if Tree then
		Tree = Tree:clone()
		Tree:setObject(obj)
		return Tree
	else
		warn("Couldn't get tree for ",treeFolder)
	end
end


-- Use SetTreeID to associate a tree folder with a string id, for use with Tree nodes
function TreeCreator:SetTreeID(treeId, treeFolder)
	assert(typeof(treeFolder) == "Instance" and treeFolder:IsA("Folder"), "SetTreeID requires a treeFolder parameter")
	assert(typeof(treeId) == "string", "SetTreeID requires a treeId string parameter")
	
	TreeIDs[treeId] = treeFolder
end


---------------------------------------------
-------------- PRIVATE METHODS --------------

local function GetModule(ModuleScript)
	local found = SourceTasks[ModuleScript]
	if found then
		return found
	else
		found = require(ModuleScript)
		SourceTasks[ModuleScript]=found
		return found
	end
end


local function GetModuleScript(folder)
	local found = folder:FindFirstChildWhichIsA("ModuleScript")
	if found then
		return found
	else
		local link = folder:FindFirstChild("Link")
		if link then
			local linked = link.Value
			if linked then
				return GetModuleScript(linked)
			end
		end
	end
end


-- For task nodes, get module script from node folder
function TreeCreator:_getSourceTask(folder)
	local ModuleScript = GetModuleScript(folder)
	if ModuleScript then
		return GetModule(ModuleScript)
	end
end


-- For tree nodes, get tree object from 
function TreeCreator:_getGetTreeFromId(treeId)
	local folder = TreeIDs[treeId]
	if folder then
		return self:Create(folder)
	end
end


function TreeCreator:_buildNode(folder)
	local nodeType = folder.Type.Value
	local weight = folder:FindFirstChild("Weight") and folder.Weight.Value or 1

	-- Get outputs, sorted in index order 
	local Outputs = folder.Outputs:GetChildren()
	local orderedChildren = {}
	for i = 1,#Outputs do
		local objvalue = Outputs[i]
		table.insert(orderedChildren,objvalue)
	end
	table.sort(orderedChildren,function(a,b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)
	for i = 1,#orderedChildren do
		orderedChildren[i] = self:_buildNode(orderedChildren[i].Value)
	end
	
	-- Get parameters from parameters folder
	local parameters = {}
	for _, value in pairs(folder.Parameters:GetChildren()) do
		if not (value.Name == "Index") then
			parameters[string.lower(value.Name)] = value.Value
		end
	end
	
	-- Add nodes and task module/tree to node parameters
	parameters.nodes = orderedChildren
	if nodeType == "Task" then
		local sourcetask = self:_getSourceTask(folder)
		assert(sourcetask, "could't build tree; task node had no module")
		parameters.module = sourcetask
	elseif nodeType == "Tree" then
		local tree = self:_getGetTreeFromId(parameters.treeid)
		assert(tree, string.format("could't build tree; couldn't get tree object for tree node with TreeID:  %s!",tostring(parameters.treeid)))
		parameters.tree = tree
	end
	
	-- Initialize node with BehaviorTree3
	local node = BehaviorTree3[nodeType](parameters)
	node.weight=weight
	
	return node
end


function TreeCreator:_createTree(treeFolder)
	local nodes = treeFolder.Nodes
	local RootFolder = nodes:FindFirstChild("Root")
	assert(RootFolder, string.format("Could not find Root under BehaviorTrees.Trees.%s.Nodes!",treeFolder.Name))
	assert(#RootFolder.Outputs:GetChildren() == 1, string.format("The root node does not have exactly one connection for %s!",treeFolder.Name))
	
	local firstNodeFolder = RootFolder.Outputs:GetChildren()[1].Value
	local root = self:_buildNode(firstNodeFolder)
	local Tree = BehaviorTree3:new({tree=root})
	Trees[treeFolder] = Tree
	return Tree	
end


function TreeCreator:_getTree(treeFolder)
	return Trees[treeFolder] or self:_createTree(treeFolder)
end


return TreeCreator
