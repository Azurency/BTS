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
        o.m_Key = key

        return o
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    AddVertice = function(self, nodeKey, verticeValue)
        -- default verticeValue to 1
        if verticeValue == nil then
          verticeValue = 1
        end
        self.m_Vertices[nodeKey] = verticeValue
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    RemoveVertice = function(self, nodeKey, verticeValue)
        self.m_Vertices[nodeKey] = nil
    end,

    ------------------------------------------------------------------
    -- Iterator
    ------------------------------------------------------------------
    Vertices = function(self)
        return pairs(self.m_Vertices)
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

        return o
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    AddNode = function(self, nodeKey)
        if self.m_Nodes[nodeKey] == nil then
            local newNode = Node:new(nodeKey)
            self.m_Nodes[nodeKey] = newNode
            return true
        end
        return false
    end,

    ------------------------------------------------------------------
    ------------------------------------------------------------------
    Link = function(self, nodeKey1, nodeKey2, linkValue, directional)
        if self.m_Nodes[nodeKey1] ~= nil and self.m_Nodes[nodeKey2] ~= nil then
            self.m_Nodes[nodeKey1]:AddVertice(nodeKey2, linkValue)
            if not directional then
                self.m_Nodes[nodeKey2]:AddVertice(nodeKey1, linkValue)
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
    -- Uses BFS to check for path b/w nodeKey1, nodeKey2
    -- Path with itself exists, if there is a vertex with itself
    ------------------------------------------------------------------
    PathExists = function(self, startKey, endKey)
        local startNode = self.m_Nodes[startKey]
        local endNode = self.m_Nodes[endKey]

        -- Node States
        local nodeStates = {}
        local NODE_UNDISCOVERED = 0
        local NODE_VISITED = 1
        local NODE_FINISHED = 2

        -- Init node states to undiscovered
        for nodeKey, node in self:Nodes() do
            nodeStates[nodeKey] = NODE_UNDISCOVERED
        end

        if startNode ~= nil and endNode ~= nil then
            nodeq = Queue:new()
            nodeStates[startNode.m_Key] = NODE_VISITED
            nodeq:enqueue(startNode.m_Key)

            -- cycle through unfinished nodes, till queue is empty
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
    __tostring = function(self)
        local s = ""
        for nodeKey, node in self:Nodes() do
            s = s .. "(" .. nodeKey .. ") "
            for nodeEndKey, verticeValue in node:Vertices() do
                s = s .. string.format("--> %s(%s) ", nodeEndKey, verticeValue)
            end
            s = s .. "\n"
        end
        return s
    end
}

g = Graph:new()
g:AddNode("n1")
g:AddNode("n2")
g:AddNode("n3")
g:AddNode("n4")
g:AddNode("n5")
g:AddNode("n6")
g:Link("n5", "n4", 1, false)
g:Link("n4", "n2", 1, false)
g:Link("n3", "n5", 1, false)
g:Link("n3", "n6", 1, false)
print(g:PathExists("n6", "n1"))
