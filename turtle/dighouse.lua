-- Configuration
local CONFIG = {
    SIZE = 10,  -- Size of the square (10x10, 15x15, etc.)
    DEPTH = 10, -- How deep to dig
    FUEL_THRESHOLD = 100,
    CENTER_RATIO = 0.6 -- Ratio of center area to preserve (0.6 = 60% of total size)
}

-- Check fuel level
local function checkFuel()
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel < CONFIG.FUEL_THRESHOLD then
        print("Low fuel! Current level: " .. fuelLevel)
        print("Please add fuel to continue")
        return false
    end
    return true
end

-- Dig a layer with optional center preservation
local function digLayer(preserveCenter, centerSize)
    -- Start at back-left corner
    for row = 1, CONFIG.SIZE do
        for col = 1, CONFIG.SIZE do
            -- Check if we should preserve this block (center area)
            local shouldPreserve = false
            if preserveCenter then
                local centerStart = math.ceil((CONFIG.SIZE - centerSize) / 2)
                local centerEnd = centerStart + centerSize - 1
                if row >= centerStart and row <= centerEnd and
                   col >= centerStart and col <= centerEnd then
                    shouldPreserve = true
                end
            end

            -- Dig if we shouldn't preserve this block
            if not shouldPreserve then
                turtle.digDown()
            end
            
            -- Move forward if not at end of row
            if col < CONFIG.SIZE then
                turtle.dig()
                turtle.forward()
            end
        end
        
        -- Return to start and prepare for next row
        if row < CONFIG.SIZE then
            if row % 2 == 1 then
                turtle.turnRight()
                turtle.dig()
                turtle.forward()
                turtle.turnRight()
            else
                turtle.turnLeft()
                turtle.dig()
                turtle.forward()
                turtle.turnLeft()
            end
        end
    end
    
    -- Return to starting corner
    turtle.turnRight()
    for i = 1, CONFIG.SIZE - 1 do
        turtle.forward()
    end
    turtle.turnRight()
    for i = 1, CONFIG.SIZE - 1 do
        turtle.forward()
    end
    turtle.turnLeft()
    turtle.turnLeft()
end

-- Calculate center size for each layer
local function getCenterSize(layer)
    local maxCenterSize = math.floor(CONFIG.SIZE * CONFIG.CENTER_RATIO)
    local layerRatio = layer / CONFIG.DEPTH
    
    if layerRatio < 0.2 then
        return 0  -- No center preserved for top 20% of layers
    elseif layerRatio < 0.3 then
        return math.floor(maxCenterSize * 0.3)  -- Small center for next 10%
    else
        return maxCenterSize  -- Full center size for remaining layers
    end
end

-- Main excavation function
local function excavateHouse()
    if not checkFuel() then return end
    
    print("Starting excavation of " .. CONFIG.SIZE .. "x" .. CONFIG.SIZE .. "x" .. CONFIG.DEPTH .. " house...")
    
    -- Excavate each layer
    for layer = 1, CONFIG.DEPTH do
        print("Digging layer " .. layer)
        local centerSize = getCenterSize(layer)
        digLayer(centerSize > 0, centerSize)
        
        -- Go down if not at bottom
        if layer < CONFIG.DEPTH then
            turtle.down()
        end
    end
    
    -- Return to surface
    for i = 1, CONFIG.DEPTH - 1 do
        turtle.up()
    end
    
    print("Excavation complete!")
end

-- Get size from user
print("Enter size (e.g., 10 for 10x10): ")
CONFIG.SIZE = tonumber(read())

print("Enter depth: ")
CONFIG.DEPTH = tonumber(read())

-- Validate input
if not CONFIG.SIZE or CONFIG.SIZE < 5 or not CONFIG.DEPTH or CONFIG.DEPTH < 1 then
    print("Invalid size or depth! Must be at least 5x5x1")
    return
end

-- Run the program
excavateHouse()