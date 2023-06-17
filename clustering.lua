AddCSLuaFile()

xalutils = xalutils or {}

function xalutils.kmeans(points, numClusters, maxIterations)
    if numClusters == nil then
        local wcss = {}
        local maxK = math.min(#points, 10)

        for k = 1, maxK do
            local _, pointClusterIndex = xalutils.kmeans(points, k, maxIterations)
            local sumSquaredDistances = 0

            for i, point in ipairs(points) do
                local centroid = points[pointClusterIndex[i]]
                local distanceSq = point:DistToSqr(centroid)
                sumSquaredDistances = sumSquaredDistances + distanceSq
            end

            table.insert(wcss, sumSquaredDistances)
        end

        local elbowPoint = 2
        local minSlope = math.huge

        for k = 2, maxK do
            local slope = wcss[k] - wcss[k-1]
            if slope < minSlope then
                minSlope = slope
                elbowPoint = k
            end
        end

        numClusters = elbowPoint
    end

    local centroids = {}

    for i = 1, numClusters do
        table.insert(centroids, points[math.random(#points)])
    end

    local iteration = 0
    local clusters = {}
    local nearestCentroidIndex = {}

    repeat
        clusters = {}
        nearestCentroidIndex = {}

        for i, _ in ipairs(centroids) do
            clusters[i] = {}
        end

        for i, point in ipairs(points) do
            local minDistanceSq = math.huge
            local closestCluster

            for j, centroid in ipairs(centroids) do
                local distSq = point:DistToSqr(centroid)
                if distSq < minDistanceSq then
                    minDistanceSq = distSq
                    closestCluster = j
                end
            end

            table.insert(clusters[closestCluster], point)
            nearestCentroidIndex[i] = closestCluster
        end

        local newCentroids = {}

        for _, cluster in ipairs(clusters) do
            local centroid = Vector(0, 0, 0)

            for _, point in ipairs(cluster) do
                centroid.x = centroid.x + point.x
                centroid.y = centroid.y + point.y
                centroid.z = centroid.z + point.z
            end

            centroid.x = centroid.x / #cluster
            centroid.y = centroid.y / #cluster
            centroid.z = centroid.z / #cluster

            table.insert(newCentroids, centroid)
        end

        centroids = newCentroids
        iteration = iteration + 1
    until iteration >= maxIterations

    local clusterCentroids = {}
    local pointClusterIndex = {}

    for i, centroid in ipairs(centroids) do
        clusterCentroids[i] = { centroid = centroid, points = clusters[i] }
    end

    for i, point in ipairs(points) do
        pointClusterIndex[i] = nearestCentroidIndex[i]
    end

    return clusterCentroids, pointClusterIndex, numClusters
end

function xalutils.GetConvexHull(points)
    local function CrossProduct(p1, p2, p3)
        return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    end

    -- Sort points based on x-coordinate (leftmost point first)
    table.sort(points, function(p1, p2)
        return p1.x < p2.x or (p1.x == p2.x and p1.y < p2.y)
    end)

    local lowerHull = {}
    for _, point in ipairs(points) do
        while #lowerHull >= 2 and CrossProduct(lowerHull[#lowerHull - 1], lowerHull[#lowerHull], point) <= 0 do
            table.remove(lowerHull)
        end
        table.insert(lowerHull, point)
    end

    local upperHull = {}
    for i = #points, 1, -1 do
        local point = points[i]
        while #upperHull >= 2 and CrossProduct(upperHull[#upperHull - 1], upperHull[#upperHull], point) <= 0 do
            table.remove(upperHull)
        end
        table.insert(upperHull, point)
    end

    table.remove(upperHull, 1)
    table.remove(upperHull, #upperHull)

    for _, point in ipairs(upperHull) do
        table.insert(lowerHull, point)
    end

    return lowerHull
end

function xalutils.ClosestPointBetweenLines(line1Start, line1End, line2Start, line2End)
    local direction1 = line1End - line1Start
    local direction2 = line2End - line2Start
    local direction3 = line2Start - line1Start

    local dot1 = direction1:Dot(direction1)
    local dot2 = direction1:Dot(direction2)
    local dot3 = direction2:Dot(direction2)
    local dot4 = direction2:Dot(direction3)
    local dot5 = direction1:Dot(direction3)

    local denominator = dot1 * dot3 - dot2 * dot2

    local t1 = (dot2 * dot4 - dot3 * dot5) / denominator
    local t2 = (dot1 * dot4 - dot2 * dot5) / denominator

    t1 = math.max(0, math.min(t1, 1))
    t2 = math.max(0, math.min(t2, 1))

    local closestPoint1 = line1Start + t1 * direction1
    local closestPoint2 = line2Start + t2 * direction2
    local distance = (closestPoint2 - closestPoint1):Length()

    return closestPoint1, closestPoint2, distance
end

function xalutils.DrawLines(points)
    for i = 1, #points - 1 do
        local startPoint = points[i]
        local endPoint = points[i + 1]
        surface.DrawLine(startPoint.x, startPoint.y, endPoint.x, endPoint.y)
    end

    -- Connect the last point with the first point
    local lastPoint = points[#points]
    local firstPoint = points[1]
    surface.DrawLine(lastPoint.x, lastPoint.y, firstPoint.x, firstPoint.y)
end

if CLIENT then
    local function CreateHexagonPoints(center, radius)
        local points = {}

        for i = 0, 5 do
            local angle = math.rad(60 * i)
            local x = center.x + radius * math.cos(angle)
            local y = center.y + radius * math.sin(angle)
            table.insert(points, Vector(x, y, center.z))
        end

        return points
    end

    -- Example usage:
    local radius = 150 -- Radius of the hexagon


    local points = {}
    for i = 1, 50 do
        local vector = CreateHexagonPoints(Vector(math.Rand(0, ScrW()), math.Rand(0, ScrH()), 0), radius)
        table.Add(points, vector)
    end

    local clusterCentroids, pointClusterIndex = xalutils.kmeans(points, nil, 10)
    for k, v in pairs(clusterCentroids) do
        v.color = ColorRand(false)
    end

    hook.Add("HUDPaint", "cluster", function ()

    end)
end