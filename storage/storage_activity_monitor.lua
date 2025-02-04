-- storage_activity_monitor.lua

local CONFIG = {
    MONITOR_SIDE = "monitor_1",
    STORAGE_ID = 18,  -- Same as in requester_node
    REQUEST_PROTOCOL = "item_network",
    REFRESH_RATE = 60, -- Check every minute
    DAILY_RESET_HOUR = 0 -- Reset at midnight
}

-- Initialize monitor
local monitor = peripheral.wrap(CONFIG.MONITOR_SIDE)
if not monitor then
    error("No monitor found on " .. CONFIG.MONITOR_SIDE .. " side!")
end

-- Storage for inventory snapshots
local inventoryData = {
    daily_start = {},  -- Beginning of day snapshot
    current = {},      -- Current snapshot
    changes = {}       -- Tracked changes
}

-- Add error tracking
local lastSuccessfulInventory = nil

-- Improved getInventory function with error handling
local function getInventory()
    rednet.send(CONFIG.STORAGE_ID, {
        type = "list"
    }, CONFIG.REQUEST_PROTOCOL)
    
    local senderId, message = rednet.receive(CONFIG.REQUEST_PROTOCOL, 5)
    if message and message.type == "inventory" then
        local itemMap = {}
        for _, item in ipairs(message.items) do
            itemMap[item.name] = {
                count = item.count,
                displayName = item.displayName
            }
        end
        lastSuccessfulInventory = itemMap
        return itemMap
    end
    return lastSuccessfulInventory -- Return last known good state if current request fails
end

-- Convert inventory to tracking format
local function takeInventorySnapshot()
    local currentInv = getInventory()
    if currentInv then
        return currentInv
    end
    return {}
end

-- Improved calculateChanges function
local function calculateChanges()
    local changes = {}
    
    -- Only calculate if we have both snapshots
    if not inventoryData.daily_start or not inventoryData.current then
        return changes
    end
    
    -- First, get all unique item names
    local allItems = {}
    for itemName, _ in pairs(inventoryData.daily_start) do
        allItems[itemName] = true
    end
    for itemName, _ in pairs(inventoryData.current) do
        allItems[itemName] = true
    end
    
    -- Calculate changes for all items
    for itemName in pairs(allItems) do
        local startCount = inventoryData.daily_start[itemName] and inventoryData.daily_start[itemName].count or 0
        local currentCount = inventoryData.current[itemName] and inventoryData.current[itemName].count or 0
        local difference = currentCount - startCount
        
        if difference ~= 0 then
            changes[itemName] = {
                difference = difference,
                displayName = (inventoryData.current[itemName] and inventoryData.current[itemName].displayName) or
                            (inventoryData.daily_start[itemName] and inventoryData.daily_start[itemName].displayName) or
                            itemName
            }
        end
    end
    
    return changes
end

-- Time calculation functions
local function getTimeUnits(days)
    local daysPerYear = 365
    local DAYS_PER_MONTH = 28
    local DAYS_PER_WEEK = 7
    
    local years = math.floor(days / daysPerYear)
    local remainingDays = days % daysPerYear
    local months = math.floor(remainingDays / DAYS_PER_MONTH)
    local daysIntoMonth = remainingDays % DAYS_PER_MONTH
    
    return years, months, daysIntoMonth
end

-- Display information on monitor
local function displayInfo()
    monitor.clear()
    local time = os.time()
    local ampm = time >= 12 and "PM" or "AM"
    local displayTime = time >= 12 and (time-12 == 0 and "12" or time-12) or (time == 0 and "12" or time)
    
    local years, months, daysIntoMonth = getTimeUnits(os.day())
    
    -- Display time and date
    monitor.setCursorPos(1, 1)
    monitor.write(string.format("Time: %s %s", displayTime, ampm))
    monitor.setCursorPos(1, 2)
    monitor.write(string.format("Day %d of Month %d", daysIntoMonth + 1, months + 1))
    
    -- Display storage activity
    monitor.setCursorPos(1, 4)
    monitor.write("=== Today's Storage Changes ===")
    
    local line = 6
    for itemName, changeData in pairs(inventoryData.changes) do
        local prefix = changeData.difference > 0 and "+" or ""
        monitor.setCursorPos(1, line)
        monitor.write(string.format("%s: %s%d", 
            changeData.displayName,
            prefix,
            changeData.difference
        ))
        line = line + 1
    end
end

-- Initialize network
rednet.open("top") -- Adjust side as needed

-- Modified main loop with better error handling
while true do
    local currentTime = os.time()
    
    -- Reset at the start of a new day
    if currentTime == CONFIG.DAILY_RESET_HOUR then
        local snapshot = takeInventorySnapshot()
        if next(snapshot) then -- Only update if we got valid data
            inventoryData.daily_start = snapshot
            inventoryData.changes = {}
        end
    end
    
    -- Update current inventory and calculate changes
    local currentSnapshot = takeInventorySnapshot()
    if next(currentSnapshot) then -- Only update if we got valid data
        inventoryData.current = currentSnapshot
        inventoryData.changes = calculateChanges()
    end
    
    displayInfo()
    os.sleep(CONFIG.REFRESH_RATE)
end