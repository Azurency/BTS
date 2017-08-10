include("GraphManager.lua")

-- ===========================================================================
--  Constants
-- ===========================================================================

local MIN_CITY_DISTANCE = tonumber(GameInfo.GlobalParameters["CITY_MIN_RANGE"].Value)
local TRADE_LAND_RANGE = math.max(tonumber(GameInfo.GlobalParameters["TRADE_ROUTE_BASE_RANGE"].Value), tonumber(GameInfo.GlobalParameters["TRADE_ROUTE_LAND_RANGE_REFUEL"].Value))
local TRADE_WATER_RANGE = tonumber(GameInfo.GlobalParameters["TRADE_ROUTE_WATER_RANGE_REFUEL"].Value)
local TRADE_MAX_RANGE = TRADE_LAND_RANGE + TRADE_WATER_RANGE

-- ===========================================================================
--  Functions
-- ===========================================================================

function BuildPlotGraph()
    local time1 = Automation.GetTime();
    local mapWidth, mapHeight = Map.GetGridSize();
    local localPlayer:number = Game.GetLocalPlayer();
    local localPlayerVis:table = PlayersVisibility[localPlayer];
    local playerCanEmbark:boolean = PlayerHasTraderEmbarkTech(Players[localPlayer])
    local plotGraph = Graph:new();

    -- First just add visible plots, impassable plots.
    -- Don't add water plots, if player does not have embarkation tech
    for plotIndex = 0, (mapWidth * mapHeight) - 1, 1 do
        local pPlot = Map.GetPlotByIndex(plotIndex)
        if localPlayerVis:IsRevealed(pPlot:GetX(), pPlot:GetY()) then
            if pPlot:IsWater() then
                if playerCanEmbark then
                    plotGraph:AddNode(plotIndex)
                end
            else
                plotGraph:AddNode(plotIndex)
            end
        end
    end

    -- Link up adjacent plots
    for plotIndex, node in plotGraph:Nodes() do
        local pPlot = Map.GetPlotByIndex(plotIndex)
        local plotX = pPlot:GetX()
        local plotY = pPlot:GetY()
        for dx = -1, 1 do
            for dy = -1, 1 do
                local adjPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 1);
                if (adjPlot) then
                    local adjPlotIndex = adjPlot:GetIndex()
                    if not plotGraph:HasVertex(plotIndex, adjPlotIndex) then
                        plotGraph:AddVertex(plotIndex, adjPlotIndex, 1, false)
                    end
                end
            end
        end
    end

    local time2 = Automation.GetTime();
    print(plotGraph:HasPath(4465, 2264))
    print("plot graph build took: " .. tostring(time2-time1));
end

function BuildRouteGraph()
    -- Get Trade constants
    local time1 = Automation.GetTime()
    print("building graph...")

    local players = Game.GetPlayers()
    local localPlayer = Game.GetLocalPlayer()
    local localPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
    local tradeManager:table = Game.GetTradeManager();

    -- Check for embark tech
    local pPlayer = Players[localPlayer]
    local traderCanEmbark = PlayerHasTraderEmbarkTech(pPlayer)
    print("trader embark:", traderCanEmbark)

    local routeGraph = Graph:new()
    local failedRouteGraph = Graph:new()

    -- short cache for simple checks
    local cityEmbarkInfo = {}
    local cityTradingPostInfo = {}
    local cityRevealInfo = {}

    for _, sPlayer in ipairs(players) do
        local sPlayerID = sPlayer:GetID()
        for _, dPlayer in ipairs(players) do
            local dPlayerID = dPlayer:GetID()
            for _, sCity in sPlayer:GetCities():Members() do
                for _, dCity in dPlayer:GetCities():Members() do

                    local sCityID = sCity:GetID()
                    local dCityID = dCity:GetID()
                    local sKey:string = string.format("%d.%d", sPlayerID, sCityID)
                    local dKey:string = string.format("%d.%d", dPlayerID, dCityID)

                    -- Get cities location info
                    local sCityX = sCity:GetX()
                    local sCityY = sCity:GetY()
                    local dCityX = dCity:GetX()
                    local dCityY = dCity:GetY()

                    -- update trading post status, if not local city
                    if sPlayerID ~= localPlayer and cityTradingPostInfo[sKey] == nil then
                        cityTradingPostInfo[sKey] = hasTradingPost(sCity)
                    end

                    -- update visibility on city
                    if cityRevealInfo[sKey] == nil then
                        if sPlayerID == localPlayer then
                            cityRevealInfo[sKey] = true
                        else
                            cityRevealInfo[sKey] = localPlayerVis:IsRevealed(sCityX, sCityY)
                        end
                    end
                    if cityRevealInfo[dKey] == nil then
                        if dPlayerID == localPlayer then
                            cityRevealInfo[dKey] = true
                        else
                            cityRevealInfo[dKey] = localPlayerVis:IsRevealed(dCityX, dCityY)
                        end
                    end

                    -- proceed with check if and only if
                    -- 1. not the same city
                    -- 2. both cities are revealed
                    -- 3. is not one vertex connection in both graphs
                    -- 4. origin city is owned by local player or source has a trading post
                    if (sKey ~= dKey and
                            (cityRevealInfo[sKey] and cityRevealInfo[dKey]) and
                            (not failedRouteGraph:HasVertex(sKey, dKey) and not routeGraph:HasVertex(sKey, dKey)) and
                            (sPlayerID == localPlayer or cityTradingPostInfo[sKey])) then

                        -- update trader embark status, if not found earlier
                        if cityEmbarkInfo[sKey] == nil then
                            cityEmbarkInfo[sKey] = TraderCanEmbarkInCity(sCity)
                        end
                        if cityEmbarkInfo[dKey] == nil and dPlayerID ~= localPlayer then
                            cityEmbarkInfo[dKey] = TraderCanEmbarkInCity(dCity)
                        end

                        -- setup the correct trade range
                        local tradeRange = TRADE_LAND_RANGE
                        if traderCanEmbark and cityEmbarkInfo[sKey] and
                                (dPlayerID == localPlayer or cityEmbarkInfo[dKey]) then
                            tradeRange = TRADE_LAND_RANGE + TRADE_WATER_RANGE
                        end

                        local canTrade:boolean = false
                        local cityDistance = Map.GetPlotDistance(sCityX, sCityY, dCityX, dCityY)

                        -- Skip if distance is beyond reachable by a non-refuel route
                        if cityDistance <= tradeRange then
                            local pathPlots = tradeManager:GetTradeRoutePath(sPlayerID, sCityID, dPlayerID, dCityID);
                            local pathLength = table.count(pathPlots)-1 -- dont count the source city in length

                            -- check for any route
                            if pathLength > 0 then

                                -- check for non-refuel route
                                if AssertNonRefuelRoute(pathPlots) then
                                    -- unidirectional, since a non-refuel route
                                    routeGraph:CreateAndLink(sKey, dKey, pathLength, false)

                                -- add this route, if the source player was local, ie trading posts count
                                elseif sPlayerID == localPlayer then
                                    -- directional to avoid refuel issues
                                    routeGraph:CreateAndLink(sKey, dKey, pathLength, true)

                                -- else
                                    -- technically this route exists, but the source player is not local.
                                    -- hence trading posts used to achieve this route, cannot be used by the local player
                                    -- NOTE: dont add this failedRouteGraph since, opposite route could still exist
                                end
                            else
                                -- if pathLength is <= 0, the route is gauranteed to fail. prevent checks between these in future
                                -- directional to avoid trading post issues with source player, counting against destination player
                                failedRouteGraph:CreateAndLink(sKey, dKey, cityDistance, true)
                            end
                        end
                    end
                end -- of nested loops between cities
            end
        end
    end

    local time2 = Automation.GetTime();
    print("took: " .. tostring(time2-time1));
    print("\n\n~~~~~ CAN BASE TRADE ~~~~~\n" .. tostring(routeGraph) .. "========\n.");
    print("\n\n~~~~~ CANNOT TRADE ~~~~~\n" .. tostring(failedRouteGraph) .. "========\n.");

    return routeGraph, failedRouteGraph
end

-- Checks if the path can be achieved though a non-refuel route
function AssertNonRefuelRoute(pathPlots)
    local plotCount = table.count(pathPlots)

    local landFuel = TRADE_LAND_RANGE
    local waterFuel = TRADE_WATER_RANGE

    -- plot count should be atleast the min distance between citites
    if plotCount <= MIN_CITY_DISTANCE then
        return false
    end

    -- plot count should not be above the max range
    if plotCount > TRADE_MAX_RANGE then
        return false
    end

    -- if within land fuel, it is gauranteed to be non-refuel
    -- if plotCount <= landFuel then
    --     return true
    -- end

    local waterRoute:boolean = false
    local plot = nil

    -- start from the plot after the start
    for i=2, plotCount do
        plot = Map.GetPlotByIndex(pathPlots[i])

        if plot:IsWater() then
            waterFuel = waterFuel - 1
            if not waterRoute then
                waterRoute = true
            end
        else
            landFuel = landFuel - 1
        end

        if landFuel < 0 or waterFuel < 0 then
            return false
        end
    end

    -- backtrack to see it does not use a launching point. Skip if destination is a local city
    plot = Map.GetPlotByIndex(pathPlots[plotCount])
    if waterRoute and plot:GetOwner() ~= Game.GetLocalPlayer() then
        -- does not use launching point if 2nd, 3rd or 4th last plot was water
        for i=1, 3 do
            plot = Map.GetPlotByIndex(pathPlots[plotCount-i])
            if plot:IsWater() then
                return true
            end
        end
    end

    -- land/local non-refuel route
    return true
end

function AddLocalRunningRoutesToGraph(graph1, graph2)
    local localPlayerCities:table = Players[Game.GetLocalPlayer()]:GetCities();
    for _, city in localPlayerCities:Members() do
        local outgoingRoutes = city:GetTrade():GetOutgoingRoutes();
        for _, routeInfo in ipairs(outgoingRoutes) do
            local sKey:string = string.format("%d.%d", routeInfo.OriginCityPlayer, routeInfo.OriginCityID)
            local dKey:string = string.format("%d.%d", routeInfo.DestinationCityPlayer, routeInfo.DestinationCityID)
            graph1:CreateAndLink(sKey, dKey, 1, true)
            if graph2 ~= nil then
                graph2:CreateAndLink(sKey, dKey, 1, true)
            end
        end
    end
end

function UpdateGraphForCity(graph, pCity)
    local sKey:string = string.format("%d.%d", pCity:GetOwner(), pCity:GetID())
    for key, node in graph:Nodes() do
        if key ~= sKey then
            local dKey:string = tostring(key)
            -- print(dKey)
            local i, j = dKey:find(".")
            local id0 = dKey:sub(0,i)
            local id1 = dKey:sub(j+2, dKey:len())
            -- print(id0, id1)
            local playerID = tonumber(id0)
            local cityID = tonumber(id1)

            -- check for trading post. if it does not have one, remove all emanating links
            local pDestinationCity = Players[playerID]:GetCities():FindID(cityID)
            if not hasTradingPost(pDestinationCity) then
                graph:RemoveAllVerticesFromNode(key)
            end
        end
    end
end

function TestGraph()
    -- Get graphs. Add all running routes to failed graph
    local totalGraph, failedGraph = BuildRouteGraph()
    AddLocalRunningRoutesToGraph(failedGraph)
    print("\n\n~~~~~ MODFIED FAIL ~~~~~\n" .. tostring(failedGraph) .. "========\n.");

    local routesCheck = {}
    local sourcePlayerID = Game.GetLocalPlayer();
    local sourceCities:table = Players[sourcePlayerID]:GetCities();
    local players:table = Game.GetPlayers{ Alive=true };
    local destinationCitiesID:table = {};
    local tradeManager:table = Game.GetTradeManager();
    local safeFails = 0
    local badFails = 0

    for _, sourceCity in sourceCities:Members() do

        -- Update graph, specifically for the source city
        local cityGraph = totalGraph:Clone()
        UpdateGraphForCity(cityGraph, sourceCity)
        local badRouteFailed = false

        local sourceCityID:number = sourceCity:GetID();
        for _, destinationPlayer in ipairs(players) do
            local destinationPlayerID:number = destinationPlayer:GetID()
            -- Check for war, met, etc
            if CanPossiblyTradeWithPlayer(sourcePlayerID, destinationPlayerID) then
                for _, destinationCity in destinationPlayer:GetCities():Members() do
                    local destinationCityID:number = destinationCity:GetID();

                    local sKey:string = string.format("%d.%d", sourcePlayerID, sourceCityID)
                    local dKey:string = string.format("%d.%d", destinationPlayerID, destinationCityID)

                    local routeExists:boolean = tradeManager:CanStartRoute(sourcePlayerID, sourceCityID, destinationPlayerID, destinationCityID)
                    local rpathExists:boolean = cityGraph:HasPath(sKey, dKey)
                    local fpathExists:boolean = failedGraph:HasVertex(sKey, dKey)

                    local gpathExists;
                    if not fpathExists and rpathExists then
                        gpathExists = true
                    else
                        gpathExists = false
                    end

                    -- if the route exists, but we failed to find it in graph
                    if routeExists and (not gpathExists) then
                        print("ASSERT FAILED: " .. sKey .. " " .. dKey)
                        print(tostring(routeExists) .. " " .. tostring(rpathExists) .. " " .. tostring(fpathExists))
                        badRouteFailed = true
                        badFails = badFails + 1
                    elseif routeExists ~= gpathExists then
                        print("Found non-existant path " .. cityGraph:GetPathString(sKey, dKey))
                        safeFails = safeFails + 1
                    end
                end
            end
        end
        if badRouteFailed then
            print("Graph for " .. L_Lookup(sourceCity:GetName()) .. "\n" .. tostring(cityGraph) .. "\n=====")
            print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
        end
    end

    print("Total safe fails: " .. tostring(safeFails))
    print("Total BAD fails: " .. tostring(badFails))
end

-- ===========================================================================
--  Support
-- ===========================================================================

-- Similiar to GetPath in GraphManager.lua. Few differences
-- Uses pseudo-BFS algorithm, which uses priority queue based on max-heap.
-- Priority is given based on the absolute distance from endIndex
-- Minor optimization by having an upper limit with maxDistance
-- Specializes for trader, ie special embarkation rules
function TraderPathFind(plotGraph, startIndex, endIndex, maxDistance)

end

function TraderCanEmbarkInCity(pCity:table)
    -- Check for coastal city
    local pPlot = Map.GetPlot(pCity:GetX(), pCity:GetY())
    if pPlot:IsCoastalLand() then
        return true
    end

    -- Check for harbor district
    return hasDistrict(pCity, "DISTRICT_HARBOR")
end

function PlayerHasTraderEmbarkTech(pPlayer:table)
    -- get trade embark tech
    local traderEmbarTech = nil;
    for techInfo in GameInfo.Technologies() do
        if techInfo.EmbarkUnitType == "UNIT_TRADER" then
            traderEmbarTech = techInfo.TechnologyType
            break
        end
    end

    if traderEmbarTech ~= nil then
        local pPlayerTechnologies = pPlayer:GetTechs()
        return pPlayerTechnologies:HasTech(GameInfo.Technologies[traderEmbarTech].Index)
    else
        print("Could not find trader embark tech")
    end
    return false
end

function hasDistrict(city:table, districtType:string)
    local hasDistrict:boolean = false;
    local cityDistricts:table = city:GetDistricts();
    for i, district in cityDistricts:Members() do
        if district:IsComplete() then
            --gets the district type of the currently selected district
            local districtInfo:table = GameInfo.Districts[district:GetType()];
            local currentDistrictType = districtInfo.DistrictType

            --assigns currentDistrictType to be the general type of district (i.e. DISTRICT_HANSA becomes DISTRICT_INDUSTRIAL_ZONE)
            local replaces = GameInfo.DistrictReplaces[districtInfo.Hash];
            if replaces then
                currentDistrictType = GameInfo.Districts[replaces.ReplacesDistrictType].DistrictType
            end

            if currentDistrictType == districtType then
                return true
            end
        end
    end

    return false
end

function hasTradingPost(city:table)
    local localPlayer = Game.GetLocalPlayer()
    return city:GetTrade():HasActiveTradingPost(localPlayer) or city:GetTrade():HasInactiveTradingPost(localPlayer)
end
