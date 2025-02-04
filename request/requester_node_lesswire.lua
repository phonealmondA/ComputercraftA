-- pocket_requester.lua
-- Standard configuration
local CONFIG = {
    REQUEST_PROTOCOL = "item_network",
    STORAGE_ID = 18,
	MYLISTLENGTH = 13,
	MY_REQUEST_TIME = 3
}

-- Request queue for multiple items
local requestQueue = {}

-- Initialize network
print("Initializing wireless network...")
if not peripheral.find("modem") then
    error("No wireless modem found!")
end

print("Opening network...")
rednet.open("back") -- Pocket computers have their modem on the back
print("Network opened successfully")

-- Get storage node ID if not set
if not CONFIG.STORAGE_ID then
    print("Enter storage node computer ID:")
    CONFIG.STORAGE_ID = tonumber(read())
end

-- Generic scrolling display function
local function displayScrollingList(items, currentIndex, title, formatter)
    term.clear()
    print(title)
    print("-----------------------------------------------")
    for i = currentIndex, math.min(currentIndex + CONFIG.MYLISTLENGTH, #items) do
        print(formatter(i, items[i]))
    end
    print("Up/Down arrows to scroll, Enter to select")
    print("Press \\ to finish and send requests")
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

-- Get inventory list from storage
local function getInventory()
    print("\nRequesting inventory list...")
    rednet.send(CONFIG.STORAGE_ID, {
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

-- Request items from network
local function requestItems(itemName, amount)
    rednet.send(CONFIG.STORAGE_ID, {
        type = "request",
        item = itemName,
        amount = amount
    }, CONFIG.REQUEST_PROTOCOL)
    
    local senderId, message = rednet.receive(CONFIG.REQUEST_PROTOCOL, 5)
    if message and message.type == "transfer_complete" then
        return message.success
    end
    return false
end

-- Process the request queue
local function processRequestQueue()
    if #requestQueue == 0 then
        print("No items in queue")
        return
    end

    print("\nProcessing request queue...")
    for i, request in ipairs(requestQueue) do
        print(string.format("Requesting %d x %s", request.amount, request.displayName))
        local success = requestItems(request.name, request.amount)
        if success then
            print("Request successful")
        else
            print("Request failed")
        end
        os.sleep(CONFIG.MY_REQUEST_TIME) -- Delay between requests
    end
    
    -- Clear the queue after processing
    requestQueue = {}
    print("\nAll requests processed")
    print("Press any key to continue...")
    os.pullEvent("key")
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

-- Main interface
while true do
    term.clear()
    term.setCursorPos(1,1)
    print("=== Pocket Item Requester ===")
    print("\nOptions:")
    print("1. List all items")
    print("2. Search items")
    print("3. View request queue")
    print("4. Process request queue")
    print("5. Clear request queue")
    print("6. Exit")
    
    local choice = read()
    
    if choice == "1" or choice == "2" then
        local items
        if choice == "1" then
            items = getInventory()
        else
            print("\nEnter search term:")
            local searchTerm = read()
            items = searchItems(getInventory(), searchTerm)
        end

        if items and #items > 0 then
            while true do
                local choice, selectedItem = selectFromList(items, "Available Items:",
                    function(i, item) return string.format("%d. %s: %d", i, item.displayName, item.count) end)
                
                if selectedItem == "exit" then
                    break
                elseif selectedItem then
                    print("Enter amount (max " .. selectedItem.count .. "):")
                    local amount = tonumber(read())
                    if amount and amount > 0 and amount <= selectedItem.count then
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
            end
        else
            print("No items found")
            os.sleep(2)
        end
    
    elseif choice == "3" then
        displayQueue()
    
    elseif choice == "4" then
        processRequestQueue()
    
    elseif choice == "5" then
        requestQueue = {}
        print("Queue cleared")
        os.sleep(1)
    
    elseif choice == "6" then
        break
    end
end

print("Closing network...")
rednet.close("back")
print("Program ended.")