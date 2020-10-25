--[[
	BEHAVIOR TREES V3
	
	Originally by iniich_n and tyridge77: https://devforum.roblox.com/t/behaviortree2-create-complex-behaviors-with-ease/451047
	Forked and improved by defaultio

	Improvements/changes:
		- Decorators will work as expected when parents of arbitrary nodes, instead of only Task nodes
		- Calling tree:run() will return the outcome of the tree (success [1], fail [2], running [3])
		- Added repeater node
			- can repeat infinitely with a "count" parameter of nil or <= 0
			- returns success when done repeating
			- returns fail if a "breakonfail" parameter is true and it receives a failed result from its child
		- Added tree node which will call another tree and return the result of the other tree
		- If a success/fail node is left hanging without a child, it will directly return success/fail
		- Improved ProcessNode organization and readability by adding the interateNodes() iterator and the addNode() function
		- Changed node runner from using string node states to using number enums, to avoid string comparisons. Should be slightly faster.
		- Changed tasks to report their status by returning a status number enum, instead of calling a success/fail/running function on self
		- Added some more assertions in ProcessNode
		- Added comments and documentation so it's a little easier to add new nodes
--]]


local BehaviorTree = {}

local SUCCESS,FAIL,RUNNING = 1,2,3


-------- TREE NODE PROCESSOR --------

	-- Iterates through raw node tree and constructs an optimzied data structure that will be used for quick tree traversal at runtime
	-- For each node, onsuccess and onfail values are set, which indicate the index of the next node that the runner hit after a success or failure

	-- During processing algorithm, onsuccess and onfail will be each set to true or false, until it is set to an actual int index.
	-- true indicates that a onsuccess or onfail should return success. false indicates that a onsuccess or onfail should return fail.


local function ProcessNode(node, nodes)
	
	-- Iterate and process all children and descendant nodes, returning an iterator for each descendant node
	local function iterateNodes()
		local c, i = 0, 0
		local childNode 
		local isFinalChildNode
		return function()
			i = i + 1
			if i == #nodes + 1 then
				childNode = nil
			end
			if not childNode then
				if isFinalChildNode then
					return nil
				end
				c = c + 1
				childNode = node.params.nodes[c]
				isFinalChildNode = c == #node.params.nodes
				i = #nodes + 1
				ProcessNode(childNode, nodes)
			end
			local node = nodes[i]
			return node, #nodes + 1, isFinalChildNode
		end
	end
	
	-- Add a new node to the final node table, returning the node and its index
	local function addNode(nodeType)
		local node = {type = nodeType}
		nodes[#nodes + 1] = node
		return node, #nodes
	end
	
	
	------------------------------
	--------- LEAF NODES ---------
	
	if node.type == "task" then
		assert(node.params.module, "Can't process tree; task leaf node has no linked task module")
		
		local taskNode = addNode("task")
		taskNode.start = node.params.module.start
		taskNode.run = node.params.module.run
		taskNode.finish = node.params.module.finish
		taskNode.onsuccess = true
		taskNode.onfail = false
		
		
	elseif node.type == "tree" then
		assert(node.params.tree, "Can't process tree; tree leaf node has no linked tree object")
		
		local treeNode = addNode("tree")
		treeNode.tree = node.params.tree
		treeNode.onsuccess = true
		treeNode.onfail = false
		
		
	-----------------------------------
	--------- DECORATOR NODES ---------	
		
	elseif node.type == "always_succeed" then
		assert(#node.params.nodes <= 1, "Can't process tree; succeed decorator with multiple children")
		
		if node.params.nodes[1] then
			-- All child node outcomes that return failure are switched to return success
			for node, nextNode, isFinal in iterateNodes() do
				if node.onsuccess == false then
					node.onsuccess = true
				end
				if node.onfail == false then
					node.onfail = true
				end
			end
		else
			-- Hanging succeed node, always return success
			local succeed = addNode("succeed")
			succeed.onsuccess = true
		end
		
		
	elseif node.type == "always_fail" then
		assert(#node.params.nodes <= 1, "Can't process tree; fail decorator with multiple children")
		
		if node.params.nodes[1] then
			-- All child node outcomes that return success are switched to return failure
			for node, nextNode, isFinal in iterateNodes() do
				if node.onsuccess == true then
					node.onsuccess = false
				end
				if node.onfail == true then
					node.onfail = false
				end
			end
		else
			-- Hanging fail node, always return fail
			local fail = addNode("fail")
			fail.onfail = false
		end
		
		
	elseif node.type == "invert" then
		assert(#node.params.nodes <= 1, "Can't process tree; invert decorator with multiple children")
		assert(#node.params.nodes == 1, "Can't process tree; hanging invert decorator")

		-- All child node outcomes are flipped
		for node, nextNode, isFinal in iterateNodes() do
			if node.onsuccess == true then
				node.onsuccess = false
			elseif node.onsuccess == false then
				node.onsuccess = true
			end
			if node.onfail == false then
				node.onfail = true
			elseif node.onfail == true then
				node.onfail = false
			end
		end
		
		
	elseif node.type == "repeat" then
		assert(#node.params.nodes <= 1, "Can't process tree; repeat decorator with multiple children")
		assert(#node.params.nodes == 1, "Can't process tree; hanging repeat decorator")
		
		local repeatNode, myIndex = addNode("repeat")
		repeatNode.repgoal = node.params.Count and node.params.Count > 0 and node.params.Count or nil
		repeatNode.repcount = 0
		repeatNode.childindex = myIndex + 1
		repeatNode.onsuccess = true
		repeatNode.onfail = false
		
		-- Direct all child node outcomes to this node. If break on fail, then leave fail outcomes as they are (fail outcome for breaking)
		local breakOnFail = node.params.breakonfail
		for node, nextNode, isFinal in iterateNodes() do
			if node.onsuccess == true then
				node.onsuccess = myIndex
			elseif node.onsuccess == false and not breakOnFail then
				node.onsuccess = myIndex
			end
			if node.onfail == false and not breakOnFail then
				node.onfail = myIndex
			elseif node.onfail == true then
				node.onfail = myIndex
			end
		end
		
		
	-----------------------------------
	--------- COMPOSITE NODES ---------	
		
	elseif node.type == "sequence" then
		assert(#node.params.nodes >= 1, "Can't process tree; sequence composite node has no children")
		
		-- All successful child node outcomes will return the next node, or success if it is the last node
		for node, nextNode, isFinal in iterateNodes() do
			if node.onsuccess == true then
				node.onsuccess = not isFinal and nextNode or true
			end
			if node.onfail == true then
				node.onfail = not isFinal and nextNode or true
			end
		end
		
		
	elseif node.type == "selector" then
		assert(#node.params.nodes >= 1, "Can't process tree; selector composite node has no children")
		
		-- All fail child node outcome will return the next node, or fail if it is the last node
		for node, nextNode, isFinal in iterateNodes() do
			if node.onsuccess == false then
				node.onsuccess = not isFinal and nextNode or false
			end
			if node.onfail == false then
				node.onfail = not isFinal and nextNode or false
			end
		end
		
		
	elseif node.type == "random" then
		assert(#node.params.nodes >= 1, "Can't process tree; random composite node has no children")

		local randomNode = addNode("random")
		randomNode.indices = {}
		for _,childNode in pairs(node.params.nodes) do
			if childNode.weight then
				local base = #randomNode.indices
				local index = #nodes + 1
				for i = 1, childNode.weight do
					randomNode.indices[base + i] = index
				end
			else
				randomNode.indices[#randomNode.indices + 1] = #nodes + 1
			end
			ProcessNode(childNode, nodes)
		end
		
		
	-----------------------------
	--------- ROOT NODE ---------
		
	elseif node.type == "root" then
		assert(#nodes == 0, "Can't process tree; root node found at nonroot location")
		
		ProcessNode(node.tree, nodes)
		
		for i = 1, #nodes do
			local node = nodes[i]
			-- Set success outcomes next index to #nodes + 1 to indicate success
			-- Set fail outcomes next index to #nodes + 2 to indicate failure
			if node.onsuccess == true then
				node.onsuccess = #nodes + 1
			elseif node.onsuccess == false then
				node.onsuccess = #nodes + 2
			end
			if node.onfail == true then
				node.onfail = #nodes + 1
			elseif node.onfail == false then
				node.onfail = #nodes + 2
			end
		end
		
		
	else
		error("ProcessNode: bad node.type " .. tostring(node.type))
	end
end



-------- TREE RUNNER --------

	-- Traversas across the processed node tree produced by ProcessNode

	-- For each node, calculates success, fail, or running
		-- If running, pause the runner and immediately break out of the runner, returning a running state.
		-- If success or fail, gets the next node we should move to using node.onsuccess or node.onfail

	-- When the final node is processed, its onsuccess/onfail index will point outside of the scope of nodes, causing the loop to break
		-- onsuccess final nodes will point to #nodes + 1, which indicates a tree outcome of success
		-- onfail final nodes will point to #nodes + 2, which indicates a tree outcome of fail


local TreeProto = {}

function TreeProto:run(...)
	if self.running then
		-- warn(debug.traceback("Tried to run BehaviorTree while it was already running"))
		return
	end
	
	local nodes = self.nodes
	local obj = self.object
	local index = self.index
	local nodeCount = #nodes
	
	local didResume = self.paused
	self.paused = false
	self.running = true
	
	
	-- Loop over all nodes until complete or a task node returns RUNNING
	while index <= nodeCount do
		local node = nodes[index]
		
		------------------------------
		--------- LEAF NODES ---------	
		
		if node.type == "task" then
			if didResume then
				didResume = false
			elseif node.start then
				node.start(obj, ...)
			end
			local status = node.run(obj, ...)
			if status == nil then
				warn("node.run did not call success, running or fail, acting as fail")
				status = FAIL
			end
			if status == RUNNING then
				self.paused = true
				break
			elseif status == SUCCESS then
				if node.finish then
					node.finish(obj, ...)
				end
				index = node.onsuccess
			elseif status == FAIL then
				if node.finish then
					node.finish(obj, ...)
				end
				index = node.onfail
			else
				error("bad node.status")
			end
			
			
		elseif node.type == "tree" then
			local treeResult = node.tree:run(...)
			if treeResult == RUNNING then
				self.paused = true
				break
			elseif treeResult == SUCCESS then
				index = node.onsuccess
			elseif treeResult == FAIL then
				index = node.onfail
			else
				error("bad tree result")
			end
			
			
		-----------------------------------
		--------- COMPOSITE NODES ---------	

		elseif node.type == "random" then
			index = node.indices[math.random(1, #node.indices)]
			
			
		-----------------------------------
		--------- DECORATOR NODES ---------	
			
		elseif node.type == "repeat" then
			if node.repcount == node.repgoal then
				node.repcount = 0
				index = node.onsuccess
			else
				node.repcount = node.repcount + 1
				index = node.childindex
			end
			
			
		elseif node.type == "succeed" then -- Hanging succeed node (technically a leaf)
			index = node.onsuccess
			

		elseif node.type == "fail" then -- Hanging fail node (technically a leaf)
			index = node.onfail
			
		
		else
			error("bad node.type")
		end
	end
	
	
	-- Get tree outcome from the break index outcome
		-- +1 indicates success, +2 indicates fail
		-- If index is <= node count, then tree must be running
	local treeOutcome
	if index == nodeCount + 1 then
		treeOutcome = SUCCESS
	elseif index == nodeCount + 2 then
		treeOutcome = FAIL
	else
		treeOutcome = RUNNING
	end
	
	self.index = index <= nodeCount and index or 1
	self.running = false
	
	return treeOutcome
end


function TreeProto:setObject(object)
	self.object = object
	for i, node in pairs(self.nodes) do
		if node.type == "tree" then
			node.tree:setObject(object)
		end
	end
end


function TreeProto:clone()
	-- Shallow copy the nodes, including copy child trees
	local nodes = {}
	for i, node in pairs(self.nodes) do
		local newNode = {}
		for k, v in pairs(node) do
			if k == "tree" then
				newNode[k] = v:clone()
			else
				newNode[k] = v
			end
		end
		nodes[i] = newNode
	end
	return setmetatable({
		nodes = nodes,
		index = self.index,
		object = self.object
	}, { __index = TreeProto })
end


------- TREE CONSTRUCTOR -------

function BehaviorTree:new(params)
	local tree = params.tree
	local nodes = {}
	
	ProcessNode({type = "root", tree = tree, params = {}}, nodes)
	
	return setmetatable({
		nodes = nodes,
		index = 1,
		object = nil
	}, { __index = TreeProto })
end


------- NODE CONSTRUCTORS -------

-- Composites
BehaviorTree.Sequence = function(params) return {type = "sequence", params = params} end
BehaviorTree.Selector = function(params) return {type = "selector", params = params} end
BehaviorTree.Random = function(params) return {type = "random", params = params} end

-- Decorators
BehaviorTree.Succeed = function(params) return {type = "always_succeed", params = params} end
BehaviorTree.Fail = function(params) return {type = "always_fail", params = params} end
BehaviorTree.Invert = function(params) return {type = "invert", params = params} end
BehaviorTree.Repeat = function(params) return {type = "repeat", params = params} end

-- Leafes
BehaviorTree.Task = function(params) return {type = "task", params = params} end
BehaviorTree.Tree = function(params) return {type = "tree", params = params} end


return BehaviorTree
