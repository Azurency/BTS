-- ===================================================================
-- Utilites
-- ===================================================================

local Queue = {
    ------------------------------------------------------------------
    -- constructor
    ------------------------------------------------------------------
    new = function(self)
        local o = {}
        setmetatable(o, self)
        self.__index = self

        -- Member variables
        o.m_Values = {}
        o.m_Back = 0
        o.m_Front = 1

        return o
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    enqueue = function(self, val)
        self.m_Back = self.m_Back + 1
        self.m_Values[self.m_Back] = val
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    dequeue = function(self)
        if self:isEmpty() then
            return nil
        end
        local val = self.m_Values[self.m_Front]
        self.m_Values[self.m_Front] = nil
        self.m_Front = self.m_Front + 1
        return val
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    isEmpty = function(self)
        return self.m_Front > self.m_Back
    end,

    ------------------------------------------------------------------
    -- Iterator
    ------------------------------------------------------------------
    empty = function(self)
        -- closure
        return function()
            return self:dequeue()
        end
    end
}

-- ===================================================================
-- Graph
-- ===================================================================

local Node = {
    ------------------------------------------------------------------
    -- constructor
    ------------------------------------------------------------------
    new = function(self, key)
        local o = {}
        setmetatable(o, self)
        self.__index = self

        -- Member variables
        o.m_Adjacencies = {}        -- all adjacent nodes
        o.m_AdjacencyCount = 0      -- adjacent nodes
        o.m_Key = key               -- key used to reference this node

        return o
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    GetKey = function(self)
        return self.m_Key
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    AddAdjacent = function(self, nodeKey, vertexValue)
        -- default vertexValue to 1
        if vertexValue == nil then
          vertexValue = 1
        end
        self.m_Adjacencies[nodeKey] = vertexValue
        self.m_AdjacencyCount = self.m_AdjacencyCount + 1
    end,
    ------------------------------------------------------------------
    ------------------------------------------------------------------
    GetAdjacencyTo = function(self, nodeKey)
        return self.m_Adjacencies[nodeKey]
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    IsAdjacent = function(self, nodeKey)
        return self:GetAdjacencyTo(nodeKey) ~= nil
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    RemoveAdjacency = function(self, nodeKey)
        self.m_Adjacencies[nodeKey] = nil
        self.m_AdjacencyCount = self.m_AdjacencyCount - 1
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    ClearAdjacency = function(self)
        for nodeKey, vertexValue in self:Adjacencies() do
            self:RemoveAdjacency(nodeKey)
        end
    end,

    ------------------------------------------------------------------
    -- Iterator
    ------------------------------------------------------------------
    Adjacencies = function(self)
        return pairs(self.m_Adjacencies)
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    __eq = function(o1, o2)
        if o1.m_AdjacencyCount == o2.m_AdjacencyCount then
            for n1, _ in o1:Adjacencies() do
                if not o2:IsAdjacent(n1) then
                    return false
                end
            end
            return true
        end
        return false
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    __tostring = function(self)
        local s = string.format(" [%s]", self:GetKey())
        for nodeKey, vertexValue in self:Adjacencies() do
            s = s .. string.format(" -/- %s(%s)", nodeKey, vertexValue)
        end
        return s
    end
}

Graph = {
    ------------------------------------------------------------------
    -- constructor
    ------------------------------------------------------------------
    new = function(self)
        local o = {}
        setmetatable(o, self)
        self.__index = self

        o.m_Nodes = {}
        o.m_NodeCount = 0

        return o
    end,

    ------------------------------------------------------------------
    -- NODES
    ------------------------------------------------------------------
    AddNode = function(self, nodeKey)
        if not self:HasNode(nodeKey) then
            self.m_Nodes[nodeKey] = Node:new(nodeKey)
            self.m_NodeCount = self.m_NodeCount + 1
            return true
        end
        return false
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    HasNode = function(self, nodeKey)
        return self.m_Nodes[nodeKey] ~= nil
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    GetNode = function(self, nodeKey)
        return self.m_Nodes[nodeKey]
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    RemoveNode = function(self, nodeKey)
        self.m_Nodes[nodeKey] = nil
        self.m_NodeCount = self.m_NodeCount - 1

        -- Cleanup vertices
        self:RemoveAllVerticesToNode(nodeKey)
    end,

    ------------------------------------------------------------------
    -- VERTICES
    ------------------------------------------------------------------
    AddVertex = function(self, nodeKey1, nodeKey2, vertexWeight, directional)
        if self.m_Nodes[nodeKey1] ~= nil and self.m_Nodes[nodeKey2] ~= nil then
            self.m_Nodes[nodeKey1]:AddAdjacent(nodeKey2, vertexWeight)
            if not directional then
                self.m_Nodes[nodeKey2]:AddAdjacent(nodeKey1, vertexWeight)
            end
            return true
        end
        return false
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    HasVertex = function(self, nodeKey1, nodeKey2)
        if self.m_Nodes[nodeKey1] ~= nil and self.m_Nodes[nodeKey2] ~= nil then
            return self.m_Nodes[nodeKey1]:IsAdjacent(nodeKey2)
        end
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    GetVertex = function(self, nodeKey1, nodeKey2)
        if self.m_Nodes[nodeKey1] ~= nil and self.m_Nodes[nodeKey2] ~= nil then
            return self.m_Nodes[nodeKey1]:GetVertex(nodeKey2)
        end
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    RemoveVertex = function(self, nodeKey1, nodeKey2)
        if self.m_Nodes[nodeKey1] ~= nil and self.m_Nodes[nodeKey2] ~= nil then
            self.m_Nodes[nodeKey1]:RemoveAdjacency(nodeKey2)
        end
    end,

    ------------------------------------------------------------------
    -- Creates nodes, if they don't exist
    -- Adds link between them. AddVertex on existing link, just updates it
    ------------------------------------------------------------------
    CreateAndLink = function(self, nodeKey1, nodeKey2, linkValue, directional)
        if not self:HasNode(nodeKey1) then
            self:AddNode(nodeKey1)
        end
        if not self:HasNode(nodeKey2) then
            self:AddNode(nodeKey2)
        end
        self:AddVertex(nodeKey1, nodeKey2, linkValue, directional)
    end,

    ------------------------------------------------------------------
    -- removes all links emanating from this node
    ------------------------------------------------------------------
    RemoveAllVerticesFromNode = function(self, nodekey)
        if self.m_Nodes[nodekey] ~= nil then
            self.m_Nodes[nodekey]:ClearAdjacency()
        end
    end,

    ------------------------------------------------------------------
    -- removes all links going to this node
    ------------------------------------------------------------------
    RemoveAllVerticesToNode = function(self, nodekey)
        for key, node in self:Nodes() do
            if node:IsAdjacent(nodekey) then
                node:RemoveAdjacency(nodekey)
            end
        end
    end,

    ------------------------------------------------------------------
    -- Iterator
    ------------------------------------------------------------------
    Nodes = function(self)
        return pairs(self.m_Nodes)
    end,

    ------------------------------------------------------------------
    -- Uses BFS to check for path b/w nodeKey1, nodeKey2.
    -- Returns immediately it finds one.
    -- Path with itself exists, if there is a vertex with itself
    ------------------------------------------------------------------
    GetPath = function(self, startKey, endKey)
        local path = {}

        if self:HasNode(startKey) and self:HasNode(endKey) then
            -- Node States
            local nodeStates = {}
            local NODE_UNDISCOVERED = 0
            local NODE_VISITED = 1
            local NODE_FINISHED = 2

            -- Init node states to undiscovered
            for nodeKey, node in self:Nodes() do
                nodeStates[nodeKey] = NODE_UNDISCOVERED
            end

            nodeq = Queue:new()
            nodeStates[startKey] = NODE_VISITED
            nodeq:enqueue(startKey)

            -- go through unfinished nodes, till queue is empty
            for nodeKey1 in nodeq:empty() do
                if nodeStates[nodeKey1] ~= NODE_FINISHED then
                    local n1 = self.m_Nodes[nodeKey1]
                    for nodeKey2, vertexValue in n1:Adjacencies() do
                        local n2 = self.m_Nodes[nodeKey2]
                        if nodeStates[nodeKey2] == NODE_UNDISCOVERED then
                            path[nodeKey2] = nodeKey1
                            if endKey == nodeKey2 then
                                return path
                            end
                            nodeStates[nodeKey2] = NODE_VISITED
                            nodeq:enqueue(nodeKey2)
                        end
                    end
                    nodeStates[nodeKey1] = NODE_FINISHED
                end
            end
        end

        -- endKey not found from startKey
        return nil
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    GetPathString = function(self, startKey, endKey)
        local path = self:GetPath(startKey, endKey)
        if path ~= nil then
            return self:PathToString(startKey, endKey, path)
        else
            return "NO PATH"
        end
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    HasPath = function(self, startKey, endKey)
        return self:GetPath(startKey, endKey) ~= nil
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    PathToString = function(self, startKey, endKey, path)
        if startKey == endKey then
            return string.format("[%s]", startKey)
        elseif path[endKey] == nil then
            return "[?]"
        end

        return self:PathToString(startKey, path[endKey], path) .. string.format("-[%s]", endKey)
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    Print = function(self)
        print(tostring(self))
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    Clone = function(self)
        local cloneGraph = Graph:new()
        for key, node in self:Nodes() do
            for vKey, vVal in node:Adjacencies() do
                cloneGraph:CreateAndLink(key, vKey, vVal, true)
            end
        end
        return cloneGraph
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    __tostring = function(self)
        local s = ""
        for nodeKey, node in self:Nodes() do
            s = s .. tostring(node) .. "\n"
        end
        return s
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    __eq = function(o1, o2)
        if o1.m_NodeCount == o2.m_NodeCount then
            for key, n1 in o1:Nodes() do
                if n1 ~= o2:GetNode(key) then
                    return false
                end
            end
            return true
        end
        return false
    end
}

--[[
local n1 = Node:new("n1")
n1:AddAdjacent("n2")
n1:AddAdjacent("n3")
n1:AddAdjacent("n4")

n2 = Node:new("n1")
n2:AddAdjacent("n2")
n2:AddAdjacent("n3")
n2:AddAdjacent("n4")
print(n1 == n2)

local g = Graph:new()
g:CreateAndLink("n3", "n6", 1, true)
g:CreateAndLink("n3", "n5", 1, true)
g:CreateAndLink("n6", "n6", 1, true)
g:CreateAndLink("n5", "n4", 1, true)
g:CreateAndLink("n4", "n2", 1, true)
g:CreateAndLink("n2", "n5", 1, true)
g:CreateAndLink("n1", "n4", 1, true)
g:CreateAndLink("n1", "n2", 1, true)
print(g:GetPathString("n3", "n2"))

local gN = g:Clone()
gN:RemoveVertex("n4", "n2")
print(gN:GetPathString("n3", "n2"))
print(g:GetPathString("n3", "n2"))
]]
