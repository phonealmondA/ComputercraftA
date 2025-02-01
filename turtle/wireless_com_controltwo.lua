-- Enhanced Wireless Control Interface with Warp Management
local CONFIG = {
    MODEM_SIDE = "left",
    PROTOCOL = "turtle_control",
    MYLISTLENGTH = 5,
    REQUEST_PROTOCOL = "item_network",
    STORAGE_IDS = {},
    LONG_TIMEOUT = 300, -- 5 minutes for long operations
    SHORT_TIMEOUT = 5   -- 5 seconds for quick operations
}

-- Initialize modem
if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
    error("No modem found on " .. CONFIG.MODEM_SIDE .. " side")
end
rednet.open(CONFIG.MODEM_SIDE)

-- UI Functions
local function clearScreen()
    term.clear()
    term.setCursorPos(1,1)
end

local function displayScrollingList(items, currentIndex, title, formatter)
    clearScreen()
    print(title)
    print("-----------------------------------------------")
    for i = currentIndex, math.min(currentIndex + CONFIG.MYLISTLENGTH, #items) do
        print(formatter(i, items[i]))
    end
    print("Up/Down arrows to scroll, Enter to select")
    print("\\ to exit")
end

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
            clearScreen()
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

-- Search function for items
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

-- Communication Functions
local function sendTurtleCommand(turtleId, command, data, timeout)
    timeout = timeout or CONFIG.SHORT_TIMEOUT
    rednet.send(turtleId, {
        type = command,
        data = data
    }, CONFIG.PROTOCOL)
    
    local sender, response
    local timer = os.startTimer(timeout)
    
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        if event == "rednet_message" then
            sender, response = param1, param2
            if sender == turtleId and response then
                return response
            end
        elseif event == "timer" and param1 == timer then
            return nil, "Timeout waiting for turtle response"
        end
    end
end

-- Storage ID Management
local function manageStorageIDs()
    while true do
        clearScreen()
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
            if #CONFIG.STORAGE_IDS == 0 then
                print("No storage IDs to remove")
                os.sleep(2)
                goto continue
            end
            print("Enter ID to remove:")
            for i, id in ipairs(CONFIG.STORAGE_IDS) do
                print(i .. ". " .. id)
            end
            local choice = tonumber(read())
            if choice and CONFIG.STORAGE_IDS[choice] then
                table.remove(CONFIG.STORAGE_IDS, choice)
                print("Storage ID removed")
                os.sleep(1)
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
        ::continue::
    end
end

-- Request Functions with enhanced search
local function makeRequests(turtleId)
    if #CONFIG.STORAGE_IDS == 0 then
        print("No storage IDs configured!")
        os.sleep(2)
        return
    end
    
    -- Select storage ID
    print("Select Storage ID:")
    for i, id in ipairs(CONFIG.STORAGE_IDS) do
        print(i .. ". " .. id)
    end
    local idChoice = tonumber(read())
    if not idChoice or not CONFIG.STORAGE_IDS[idChoice] then
        print("Invalid storage ID selection")
        os.sleep(2)
        return
    end
    
    -- Get warp points from turtle
    local response = sendTurtleCommand(turtleId, "get_points")
    if not response or not response.success then
        print("Failed to get warp points")
        os.sleep(2)
        return
    end
    
    -- Select warp point
    local choice, selectedPoint = selectFromList(response.points, "Select Warp Point:",
        function(i, point) return i .. ". " .. point end)
    if not choice then return end
    
    -- Get inventory from storage computer
    local storageId = CONFIG.STORAGE_IDS[idChoice]
    local result = sendTurtleCommand(turtleId, "get_storage_inventory", {
        storageId = storageId,
        point = selectedPoint
    }, CONFIG.LONG_TIMEOUT)
    
    if not result or not result.success or not result.items then
        print("Failed to get inventory")
        os.sleep(2)
        return
    end
    
    -- Handle item selection and queue building with search capability
    local requests = {}
    local searchAgain = true
    
    while searchAgain do
        clearScreen()
        print("\nEnter search term (or press Enter to see all items):")
        local searchTerm = read()
        local items
        
        if searchTerm and searchTerm ~= "" then
            items = searchItems(result.items, searchTerm)
        else
            items = result.items
        end

        if items and #items > 0 then
            while true do
                if #requests >= 16 then
                    print("Request queue full (16 items maximum)")
                    os.sleep(2)
                    break
                end
                
                local itemChoice, selectedItem = selectFromList(items, "Available Items:",
                    function(i, item) return string.format("%d. %s: %d", i, item.displayName, item.count) end)
                
                if not itemChoice then break end
                
                print("Enter amount (max 64):")
                local amount = tonumber(read())
                if amount and amount > 0 and amount <= 64 then
                    table.insert(requests, {
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
        
        print("\nSearch for more items? (y/n)")
        searchAgain = read():lower() == "y"
    end
    
    if #requests > 0 then
        sendTurtleCommand(turtleId, "set_requests", {
            requests = requests,
            storageId = storageId,
            point = selectedPoint
        })
    end
end

-- Main menu and control functions
local function handleManualControl(turtleId)
    clearScreen()
    print("Manual Control Mode")
    print("W - Forward    | Space - Up")
    print("S - Back       | LShift - Down")
    print("A - Turn Left  | Q - Exit Control")
    print("D - Turn Right | F - Dig Forward")
    
    local controlling = true
    while controlling do
        local event, key = os.pullEvent("key")
        local command = nil
        
        if key == keys.w then command = "move_forward"
        elseif key == keys.s then command = "move_back"
        elseif key == keys.a then command = "turn_left"
        elseif key == keys.d then command = "turn_right"
        elseif key == keys.space then command = "move_up"
        elseif key == keys.leftShift then command = "move_down"
        elseif key == keys.f then command = "dig"
        elseif key == keys.q then controlling = false
        end
        
        if command then
            local response = sendTurtleCommand(turtleId, command)
            if not response or not response.success then
                print("Command failed!")
                os.sleep(1)
            end
        end
    end
end

-- Main menu
local function mainMenu(turtleId)
    while true do
        clearScreen()
        print("\nWarp Storage and Control System")
        print("=== Movement Controls ===")
        print("1. Manual Control Mode")
        print("=== Storage Functions ===")
        print("2. Sort Inventory")
        print("3. List Points")
        print("4. Setup New Point")
        print("5. Delete Point")
        print("=== Request Functions ===")
        print("6. Manage Storage IDs")
        print("7. Make Requests")
        print("8. View Request Queue")
        print("9. Process Request Queue")
        print("10. Clear Request Queue")
        print("11. Exit")
        
        local choice = read()
        
        if choice == "1" then
            handleManualControl(turtleId)
        elseif choice == "2" then
            local response = sendTurtleCommand(turtleId, "sort_inventory", nil, CONFIG.LONG_TIMEOUT)
            print(response and response.message or "Sort failed")
            os.sleep(2)
        elseif choice == "3" then
            local response = sendTurtleCommand(turtleId, "list_points")
            if response and response.points then
                selectFromList(response.points, "Saved Warp Points:",
                    function(i, point) return i .. ". " .. point end)
            end
        elseif choice == "4" then
            print("Enter new point name:")
            local name = read()
            if name ~= "" then
                local response = sendTurtleCommand(turtleId, "setup_point", name)
                print(response and response.message or "Failed to save point")
                os.sleep(2)
            end
        elseif choice == "5" then
            local response = sendTurtleCommand(turtleId, "get_points")
            if response and response.points then
                local choice, point = selectFromList(response.points, "Points to Delete:",
                    function(i, point) return i .. ". " .. point end)
                if choice then
                    print("Are you sure you want to delete '" .. point .. "'? (y/n)")
                    if read():lower() == "y" then
                        local deleteResponse = sendTurtleCommand(turtleId, "delete_point", point)
                        print(deleteResponse and deleteResponse.message or "Delete failed")
                        os.sleep(2)
                    end
                end
            end
        elseif choice == "6" then
            manageStorageIDs()
        elseif choice == "7" then
            makeRequests(turtleId)
        elseif choice == "8" then
            local response = sendTurtleCommand(turtleId, "view_queue")
            if response and response.queue then
                clearScreen()
                print("Current Request Queue:")
                print("-----------------------------------------------")
                if #response.queue == 0 then
                    print("Queue is empty")
                else
                    for i, request in ipairs(response.queue) do
                        print(string.format("%d. %s x%d", i, request.displayName, request.amount))
                    end
                end
                print("\nPress any key to continue...")
                os.pullEvent("key")
            end
        elseif choice == "9" then
            local response = sendTurtleCommand(turtleId, "get_points")
            if response and response.points then
                local choice, point = selectFromList(response.points, "Select Collection Point:",
                    function(i, point) return i .. ". " .. point end)
                if choice then
                    local processResponse = sendTurtleCommand(turtleId, "process_queue", point, CONFIG.LONG_TIMEOUT)
                    print(processResponse and processResponse.message or "Processing failed")
                    os.sleep(2)
                end
            end
        elseif choice == "10" then
            local response = sendTurtleCommand(turtleId, "clear_queue")
            print(response and response.message or "Failed to clear queue")
            os.sleep(1)
        elseif choice == "11" then
            break
        end
    end
end

-- Start program
clearScreen()
print("Enter turtle ID:")
local turtleId = tonumber(read())

if not turtleId then
    error("Invalid turtle ID")
end

print("Connected to turtle " .. turtleId)
os.sleep(1)
mainMenu(turtleId)