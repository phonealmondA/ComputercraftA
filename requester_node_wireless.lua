-- pocket_requester.lua
-- Standard configuration
local CONFIG = {
    REQUEST_PROTOCOL = "item_network",
    STORAGE_ID = 8
}

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

-- Display search results
local function displaySearchResults(results)
    if #results == 0 then
        print("\nNo items found matching your search.")
        return
    end
    
    print("\nFound items:")
    for _, item in ipairs(results) do
        print(string.format("%d. %s: %d", item.index, item.displayName, item.count))
        os.pullEvent("key")
    end
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

-- Main interface
while true do
    term.clear()
    term.setCursorPos(1,1)
    print("=== Pocket Item Requester ===")
    print("\nOptions:")
    print("1. List all items")
    print("2. Search items")
    print("3. Request items")
    print("4. Exit")
    
    local choice = read()
    
    if choice == "1" then
        local items = getInventory()
        if items then
            print("\nAvailable items:")
            for _, item in ipairs(items) do
                print(string.format("%d. %s: %d", item.index, item.displayName, item.count))
                os.pullEvent("key")
            end
            print("\nPress any key to continue...")
            os.pullEvent("key")
        end
    
    elseif choice == "2" then
        print("\nEnter search term:")
        local searchTerm = read()
        local items = getInventory()
        local results = searchItems(items, searchTerm)
        displaySearchResults(results)
        
        if #results > 0 then
            print("\nWould you like to request any of these items? (Y/N)")
            local valid = false
            while not valid do
                local event, key = os.pullEvent("char")
                if key:lower() == "y" then
                    valid = true
                    print("Enter item number:")
                    local itemNum = tonumber(read())
                    local selectedItem = nil
                    for _, item in ipairs(results) do
                        if item.index == itemNum then
                            selectedItem = item
                            break
                        end
                    end
                    
                    if selectedItem then
                        print("Enter amount (max " .. selectedItem.count .. "):")
                        local amount = tonumber(read())
                        if amount and amount > 0 and amount <= selectedItem.count then
                            if requestItems(selectedItem.name, amount) then
                                print("Request sent successfully")
                            else
                                print("Request failed")
                            end
                        else
                            print("Invalid amount")
                        end
                    else
                        print("Invalid item number")
                    end
                    os.sleep(2)
                elseif key:lower() == "n" then
                    valid = true
                end
            end
        end
        print("\nPress any key to continue...")
        os.pullEvent("key")
    
    elseif choice == "3" then
        local items = getInventory()
        if items then
            print("\nEnter item number:")
            local itemNum = tonumber(read())
            local selectedItem = nil
            for _, item in ipairs(items) do
                if item.index == itemNum then
                    selectedItem = item
                    break
                end
            end
            
            if selectedItem then
                print("Enter amount (max " .. selectedItem.count .. "):")
                local amount = tonumber(read())
                if amount and amount > 0 and amount <= selectedItem.count then
                    if requestItems(selectedItem.name, amount) then
                        print("Request sent successfully")
                    else
                        print("Request failed")
                    end
                else
                    print("Invalid amount")
                end
            else
                print("Invalid item number")
            end
            os.sleep(2)
        end
    
    elseif choice == "4" then
        break
    end
end

print("Closing network...")
rednet.close("back")
print("Program ended.")