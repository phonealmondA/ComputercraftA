-- Combined Warp Storage and Request System
-- Configuration
local CONFIG = {
    REQUEST_PROTOCOL = "item_network",
    STORAGE_IDS = {}, -- Will store multiple storage IDs
    MYLISTLENGTH = 5,
    MY_REQUEST_TIME = 3,
    CURRENT_STORAGE_ID = nil
}

-- Initialize peripherals
if not peripheral.isPresent("left") then
    error("Warp Drive not found on left side")
end
if not peripheral.isPresent("right") then
    error("Wireless modem not found on right side")
end

local warpDrive = peripheral.wrap("left")
rednet.open("right")

-- Save original location
warpDrive.savePoint("start")

-- Request queue for multiple items
local requestQueue = {}

-- Generic scrolling display function
local function displayScrollingList(items, currentIndex, title, formatter)
    term.clear()
    print(title)
    print("-----------------------------------------------")
    for i = currentIndex, math.min(currentIndex + CONFIG.MYLISTLENGTH, #items) do
        print(formatter(i, items[i]))
    end
    print("Up/Down arrows to scroll, Enter to select")
    print("\ to exit")
end

-- List selection function
local function selectFromList(items, title, formatter)
    if #items == 0 then return nil end
    
    local currentIndex = 1
    while true do
        displayScrollingList(items, currentIndex, title, formatter)
        local event, key = os.pullEvent("key")
        
        if key == keys.up and currentIndex > 1 then
            currentIndex = currentIndex - 1
        elseif key == keys.down and currentIndex < #items - CONFIG.MYLISTLENGTH then
            currentIndex = currentIndex + 1
        elseif key == keys.enter then
            term.clear()
            print("Enter the number (1-" .. #items .. "):")
            local choice = tonumber(read())
            if choice and items[choice] then
                return choice, items[choice]
            end
            print("Invalid selection")
        elseif key == keys.backslash then
            return nil, "exit"
        end
    end
end
-- Safe warping function
local function safeWarp(point)
    if not point then return false end
    os.sleep(1.5)
    return warpDrive.warpToPoint(point)
end

-- Select warp point with scrolling
local function selectWarpPoint(title)
    local points = warpDrive.points()
    if #points == 0 then
        print("No warp points saved!")
        return nil
    end
    
    local choice, selectedPoint = selectFromList(points, title,
        function(i, point) return i .. ". " .. point end)
    
    if choice then
        return points[choice]
    end
    return nil
end



-- List all warp points
local function listPoints()
    local points = warpDrive.points()
    if #points == 0 then
        print("No warp points saved")
        return false
    end
    
    selectFromList(points, "Saved Warp Points:", 
        function(i, point) return i .. ". " .. point end)
    os.pullEvent("key")
    return true
end

-- Set up new warp point
local function setupPoint()
    print("\nEnter new point name:")
    local name = read()
    if name == "" then
        print("Name cannot be empty")
        return false
    end
    
    if warpDrive.savePoint(name) then
        print("Saved point: " .. name)
        return true
    else
        print("Failed to save point")
        return false
    end
end

-- Delete warp points function
local function deletePoints()
    local savedPoints = warpDrive.points()
    if #savedPoints == 0 then
        print("No warp points saved!")
        return
    end

    -- Filter out 'start' point from deletion list
    local deletablePoints = {}
    for _, point in ipairs(savedPoints) do
        if point ~= "start" then
            table.insert(deletablePoints, point)
        end
    end

    if #deletablePoints == 0 then
        print("No points available to delete (excluding 'start' point)")
        return
    end

    print("\nSelect point to delete:")
    local choice, selectedPoint = selectFromList(deletablePoints, "Available Points to Delete:",
        function(i, point) return i .. ". " .. point end)
    
    if not choice then return end

    print("\nAre you sure you want to delete '" .. selectedPoint .. "'? (y/n)")
    local confirm = read():lower()
    if confirm == "y" then
        if warpDrive.deletePoint(selectedPoint) then
            print("Deleted point: " .. selectedPoint)
        else
            print("Failed to delete point")
        end
    else
        print("Deletion cancelled")
    end
end

-- Sort inventory to matching storage points
local function sortInventory()
    local savedPoints = warpDrive.points()
    if #savedPoints == 0 then
        print("No warp points saved!")
        return
    end

    print("Starting inventory sort...")
    local sorted = false
    
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            print("Checking " .. item.name)
            local itemName = item.name:lower()
            
            for _, point in ipairs(savedPoints) do
                if point ~= "start" and (itemName:find(point:lower()) or point:lower():find(itemName)) then
                    turtle.select(slot)
                    if safeWarp(point) then
                        if turtle.dropDown() then
                            print("Sorted " .. item.name .. " to " .. point)
                            sorted = true
                        else
                            print("Failed to drop at " .. point)
                        end
                        break
                    else
                        print("Failed to warp to " .. point)
                    end
                end
            end
        end
    end

    if sorted then
        safeWarp("start")
        print("Sorting complete")
    else
        print("No items were sorted")
    end
end

-- Storage ID Management
local function manageStorageIDs()
    while true do
        term.clear()
        print("Storage ID Management")
        print("1. Add Storage ID")
        print("2. Remove Storage ID")
        print("3. List Storage IDs")
        print("4. Back")
        
        local choice = read()
        if choice == "1" then
            print("Enter new storage ID:")
            local id = tonumber(read())
            if id then
                table.insert(CONFIG.STORAGE_IDS, id)
                print("Added storage ID: " .. id)
            end
        elseif choice == "2" then
            print("Enter ID to remove:")
            local id = tonumber(read())
            for i, stored_id in ipairs(CONFIG.STORAGE_IDS) do
                if stored_id == id then
                    table.remove(CONFIG.STORAGE_IDS, i)
                    print("Removed storage ID: " .. id)
                    break
                end
            end
        elseif choice == "3" then
            print("Storage IDs:")
            for i, id in ipairs(CONFIG.STORAGE_IDS) do
                print(i .. ". " .. id)
            end
            print("Press any key to continue...")
            os.pullEvent("key")
        elseif choice == "4" then
            break
        end
    end
end

-- Get inventory list from storage
local function getInventory()
    print("\nRequesting inventory list...")
    rednet.send(CONFIG.CURRENT_STORAGE_ID, {
        type = "list"
    }, CONFIG.REQUEST_PROTOCOL)
    
    local senderId, message = rednet.receive(CONFIG.REQUEST_PROTOCOL, 5)
    if message and message.type == "inventory" then
        return message.items
    end
    return nil
end

-- Search items by name
local function searchItems(items, searchTerm)
    if not items then return {} end
    searchTerm = searchTerm:lower()
    local results = {}
    
    for _, item in ipairs(items) do
        if string.find(item.name:lower(), searchTerm) or 
           string.find(item.displayName:lower(), searchTerm) then
            table.insert(results, item)
        end
    end
    
    return results
end

-- Display current queue
local function displayQueue()
    term.clear()
    term.setCursorPos(1,1)
    print("Current Request Queue:")
    print("-----------------------------------------------")
    if #requestQueue == 0 then
        print("Queue is empty")
    else
        for i, request in ipairs(requestQueue) do
            print(string.format("%d. %s x%d", i, request.displayName, request.amount))
        end
    end
    print("\nPress any key to continue...")
    os.pullEvent("key")
end




-- Make requests function
local function makeRequests(selectedPoint)
    local items = getInventory()
    if items and #items > 0 then
        while true do
            if #requestQueue >= 16 then
                print("Request queue full (16 items maximum)")
                os.sleep(2)
                break
            end
            
            local choice, selectedItem = selectFromList(items, "Available Items:",
                function(i, item) return string.format("%d. %s: %d", i, item.displayName, item.count) end)
            
            if not choice then break end
            
            print("Enter amount (max 64):")
            local amount = tonumber(read())
            if amount and amount > 0 and amount <= 64 then
                table.insert(requestQueue, {
                    name = selectedItem.name,
                    displayName = selectedItem.displayName,
                    amount = amount
                })
                print("Added to queue")
                os.sleep(1)
            else
                print("Invalid amount")
                os.sleep(1)
            end
        end
    else
        print("No items found")
        os.sleep(2)
    end
end

-- Process request queue with warping
local function processRequestQueueWithWarp(selectedPoint)
    if #requestQueue == 0 then
        print("No items in queue")
        return
    end

    print("\nProcessing request queue...")
    local itemCount = 0
    local currentItems = {}
    
    -- Initial warp to selected point
    if not safeWarp(selectedPoint) then
        print("Failed to reach request location")
        return
    end
    
    for i, request in ipairs(requestQueue) do
        if itemCount >= 16 then
            -- Return to start to unload
            safeWarp("start")
            -- Empty inventory into storage
            for slot = 1, 16 do
                turtle.select(slot)
                turtle.dropDown()
            end
            itemCount = 0
            currentItems = {}
            -- Return to request point
            if not safeWarp(selectedPoint) then
                print("Failed to return to request location")
                return
            end
        end

        print(string.format("Requesting %d x %s", request.amount, request.displayName))
        rednet.send(CONFIG.CURRENT_STORAGE_ID, {
            type = "request",
            item = request.name,
            amount = request.amount
        }, CONFIG.REQUEST_PROTOCOL)
        
        local senderId, message = rednet.receive(CONFIG.REQUEST_PROTOCOL, 5)
        if message and message.type == "transfer_complete" then
            -- Wait briefly for items to arrive
            os.sleep(0.5)
            
            -- Try to collect items
            for slot = 1, 16 do
                turtle.select(slot)
                if turtle.getItemCount(slot) == 0 then  -- Only try empty slots
                    if turtle.suckDown() then
                        itemCount = itemCount + 1
                        table.insert(currentItems, request)
                        break
                    end
                end
            end
        end
        
        os.sleep(CONFIG.MY_REQUEST_TIME)
    end
    
    -- Final return to start
    if itemCount > 0 then
        safeWarp("start")
        -- Empty inventory
        --for slot = 1, 16 do
        --    turtle.select(slot)
        --    turtle.dropDown()
        --end
    end
    
    requestQueue = {}
    print("\nAll requests processed")
    print("Press any key to continue...")
    os.pullEvent("key")
end



-- Main menu
local function mainMenu()
    while true do
        term.clear()
        print("\nWarp Storage and Request System")
        print("=== Storage Functions ===")
        print("1. Sort Inventory")
        print("2. List Points")
        print("3. Setup New Point")
        print("4. Delete Point")
        print("=== Request Functions ===")
        print("5. Manage Storage IDs")
        print("6. Make Requests")
        print("7. View Request Queue")
        print("8. Process Request Queue")
        print("9. Clear Request Queue")
        print("10. Exit")
        
        local choice = read()
        
        if choice == "1" then
            sortInventory()
        elseif choice == "2" then
            listPoints()
        elseif choice == "3" then
            setupPoint()
        elseif choice == "4" then
            deletePoints()
        elseif choice == "5" then
            manageStorageIDs()
        elseif choice == "6" then
            if #CONFIG.STORAGE_IDS == 0 then
                print("No storage IDs configured!")
                os.sleep(2)
                goto continue
            end
            
            print("Select Storage ID:")
            for i, id in ipairs(CONFIG.STORAGE_IDS) do
                print(i .. ". " .. id)
            end
            local idChoice = tonumber(read())
            if not idChoice or not CONFIG.STORAGE_IDS[idChoice] then
                print("Invalid choice")
                os.sleep(2)
                goto continue
            end
            CONFIG.CURRENT_STORAGE_ID = CONFIG.STORAGE_IDS[idChoice]
            
            -- Use scrolling selection for warp points
            local selectedPoint = selectWarpPoint("Select Warp Point:")
            if not selectedPoint then
                print("Invalid point selection")
                os.sleep(2)
                goto continue
            end
            
            -- Warp to selected point first
            if not safeWarp(selectedPoint) then
                print("Failed to warp to selected point")
                os.sleep(2)
                goto continue
            end
            
            -- Get item list at location
            local items = getInventory()
            
            -- Return to start
            safeWarp("start")
            
            -- Now handle item selection
            if items and #items > 0 then
                makeRequests(selectedPoint)
            else
                print("No items found at storage location")
                os.sleep(2)
            end
            
        elseif choice == "7" then
            displayQueue()
        elseif choice == "8" then
            local selectedPoint = selectWarpPoint("Select Warp Point for collection:")
            if selectedPoint then
                processRequestQueueWithWarp(selectedPoint)
            else
                print("Invalid point selection")
                os.sleep(2)
            end
        elseif choice == "9" then
            requestQueue = {}
            print("Queue cleared")
            os.sleep(1)
        elseif choice == "10" then
            print("Exiting...")
            break
        end
        
        ::continue::
    end
end

-- Start program
print("Warp Storage and Request System Starting...")
mainMenu()
