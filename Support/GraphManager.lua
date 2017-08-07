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
        if self.m_Front > self.m_Back then
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
        o.m_Vertices = {}
        o.m_VerticeCount = 0
        o.m_Key = key

        return o
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    AddVertex = function(self, nodeKey, vertexValue)
        -- default vertexValue to 1
        if vertexValue == nil then
          vertexValue = 1
        end
        self.m_Vertices[nodeKey] = vertexValue
        self.m_VerticeCount = self.m_VerticeCount + 1
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    HasVertex = function(self, nodeKey)
        return self.m_Vertices[nodeKey] ~= nil
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    RemoveVertex = function(self, nodeKey)
        self.m_Vertices[nodeKey] = nil
        self.m_VerticeCount = self.m_VerticeCount - 1
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    ClearVertices = function(self)
        for nodeKey, verticeValue in self:Vertices() do
            self:RemoveVertex(nodeKey)
        end
    end,

    ------------------------------------------------------------------
    -- Iterator
    ------------------------------------------------------------------
    Vertices = function(self)
        return pairs(self.m_Vertices)
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    __eq = function(o1, o2)
        if o1.m_VerticeCount == o2.m_VerticeCount then
            for n1, _ in o1:Vertices() do
                if not o2:HasVertex(n1) then
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
        local s = string.format(" [%s]", self.m_Key)
        for nodeKey, verticeValue in self:Vertices() do
            s = s .. string.format(" --/-- %s(%s) ", nodeKey, verticeValue)
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
    ------------------------------------------------------------------
    AddNode = function(self, nodeKey)
        if self.m_Nodes[nodeKey] == nil then
            local newNode = Node:new(nodeKey)
            self.m_Nodes[nodeKey] = newNode
            self.m_NodeCount = self.m_NodeCount + 1
            return true
        end
        return false
    end,

    ------------------------------------------------------------------
    -- Creates nodes, if they don't exist
    -- Adds link between them. AddLink on existing link, just updates it
    ------------------------------------------------------------------
    AddConnection = function(self, nodeKey1, nodeKey2, linkValue, directional)
        if not self:HasNode(nodeKey1) then
            self:AddNode(nodeKey1)
        end
        if not self:HasNode(nodeKey2) then
            self:AddNode(nodeKey2)
        end
        self:AddLink(nodeKey1, nodeKey2, linkValue, directional)
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
    AddLink = function(self, nodeKey1, nodeKey2, linkValue, directional)
        if self.m_Nodes[nodeKey1] ~= nil and self.m_Nodes[nodeKey2] ~= nil then
            self.m_Nodes[nodeKey1]:AddVertex(nodeKey2, linkValue)
            if not directional then
                self.m_Nodes[nodeKey2]:AddVertex(nodeKey1, linkValue)
            end
            return true
        end
        return false
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    HasLink = function(self, nodeKey1, nodeKey2)
        if self.m_Nodes[nodeKey1] ~= nil and self.m_Nodes[nodeKey2] ~= nil then
            return self.m_Nodes[nodeKey1]:HasVertex(nodeKey2)
        end
    end,

    ------------------------------------------------------------------
    -- removes all links emanating from this node
    ------------------------------------------------------------------
    RemoveAllLinksFromNode = function(self, nodekey)
        if self.m_Nodes[nodekey] ~= nil then
            self.m_Nodes[nodekey]:ClearVertices()
        end
    end,

    ------------------------------------------------------------------
    -- removes all links going to this node
    ------------------------------------------------------------------
    RemoveAllLinksToNode = function(self, nodekey)
        for key, node in self:Nodes() do
            if node:HasVertex(nodekey) then
                node:RemoveVertex(nodekey)
            end
        end
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    RemoveNode = function(self, nodeKey)
        self.m_Nodes[nodeKey] = nil
        self.m_NodeCount = self.m_NodeCount - 1

        -- Cleanup links
        self:RemoveAllLinksToNode(nodeKey)
    end,

    ------------------------------------------------------------------
    -- Iterator
    ------------------------------------------------------------------
    Nodes = function(self)
        return pairs(self.m_Nodes)
    end,

    ------------------------------------------------------------------
    -- Uses BFS to check for path b/w nodeKey1, nodeKey2
    -- Path with itself exists, if there is a vertex with itself
    ------------------------------------------------------------------
    PathExists = function(self, startKey, endKey)
        local startNode = self.m_Nodes[startKey]
        local endNode = self.m_Nodes[endKey]

        if startNode ~= nil and endNode ~= nil then
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
            nodeStates[startNode.m_Key] = NODE_VISITED
            nodeq:enqueue(startNode.m_Key)

            -- go through unfinished nodes, till queue is empty
            for nodeKey1 in nodeq:empty() do
                if nodeStates[nodeKey1] ~= NODE_FINISHED then
                    local n1 = self.m_Nodes[nodeKey1]
                    for nodeKey2, verticeValue in n1:Vertices() do
                        local n2 = self.m_Nodes[nodeKey2]
                        if nodeStates[n2.m_Key] == NODE_UNDISCOVERED then
                            if endNode.m_Key == n2.m_Key then
                                return true
                            end
                            nodeStates[n2.m_Key] = NODE_VISITED
                            nodeq:enqueue(n2.m_Key)
                        end
                    end
                    nodeStates[nodeKey1] = NODE_FINISHED
                end
            end
        end
        return false
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
            for vKey, vVal in node:Vertices() do
                cloneGraph:AddConnection(key, vKey, vVal, true)
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
n1:AddVertex("n2")
n1:AddVertex("n3")
n1:AddVertex("n4")

n2 = Node:new("n1")
n2:AddVertex("n2")
n2:AddVertex("n3")
n2:AddVertex("n4")
print(n1 == n2)

local g = Graph:new()
g:AddNode("n1")
g:AddNode("n2")
g:AddNode("n3")
g:AddNode("n4")
g:AddNode("n5")
g:AddNode("n6")
g:AddLink("n3", "n6", 1, true)
g:AddLink("n3", "n5", 1, true)
g:AddLink("n6", "n6", 1, true)
g:AddLink("n5", "n4", 1, true)
g:AddLink("n4", "n2", 1, true)
g:AddLink("n2", "n5", 1, true)
g:AddLink("n1", "n4", 1, true)
g:AddLink("n1", "n2", 1, true)

local g2 = g:Clone()
g:RemoveNode("n1")
g2:RemoveNode("n6")
g:Print()
g2:Print()
]]
