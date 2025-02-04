-- requester_node.lua
local DEST_CHEST = "minecraft:chest_55"  -- Destination chest to pull items into
local NETWORK_CHESTS = {                 -- All available chests on network
    "minecraft:chest_55"
}

-- Standard configuration
local CONFIG = {
    REQUEST_PROTOCOL = "item_network",
    SOURCE_SIDE = "left",
    STORAGE_ID = 8
}

-- Initialize network
print("Initializing network...")
if not peripheral.isPresent(CONFIG.SOURCE_SIDE) then
    error("No modem found on " .. CONFIG.SOURCE_SIDE .. " side!")
end

print("Opening network...")
rednet.open(CONFIG.SOURCE_SIDE)
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
        -- Search in both internal name and display name
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

-- Pull items from network to local chest
local function pullItems(itemName, amount)
    rednet.send(CONFIG.STORAGE_ID, {
        type = "request",
        item = itemName,
        amount = amount
    }, CONFIG.REQUEST_PROTOCOL)
    
    -- Wait 2 seconds then try to pull items
    os.sleep(2)
    
    local destChest = peripheral.wrap(DEST_CHEST)
    if not destChest then
        print("Could not find destination chest")
        return false
    end
    
    local itemsMoved = 0
    for _, chestName in ipairs(NETWORK_CHESTS) do
        if chestName ~= DEST_CHEST then
            for slot = 1, 27 do
                local moved = destChest.pullItems(chestName, slot)
                if moved and moved > 0 then
                    itemsMoved = itemsMoved + moved
                end
            end
        end
    end
    
    return itemsMoved > 0
end

-- Main interface
while true do
    term.clear()
    term.setCursorPos(1,1)
    print("=== Item Requester ===")
    print("\nOptions:")
    print("1. List all items")
    print("2. Search items")
    print("3. Request items")
    print("4. request until found")
    print("5. Exit")
    
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
            
            -- Wait for specific Y or N key press
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
						
						os.sleep(5)
						
						--while items2 == nil do
						--print(items2)
						--os.sleep(5)
						--local items2 = getInventory()
						--end
						
                            if pullItems(selectedItem.name, amount) then
                                print("Items transferred successfully")
                            else
                                print("Transfer failed")
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
				
				
				--os.sleep(5)
				while items2 == false do
				print(items2)
				os.sleep(5)
				local items2 = getInventory()
				end
				
                    if pullItems(selectedItem.name, amount) then
                        print("Items transferred successfully")
                    else
                        print("Transfer failed")
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
    print("\nWaiting for network to be ready...")
    local items = nil
    while items == nil do
        items = getInventory()
        if items == nil then
            os.sleep(1)  -- Wait 1 second between attempts
        end
    end
    print("Ready for transfers")
    os.sleep(2)  -- Give user time to see the message
		
    elseif choice == "5" then
        break
    end
end

print("Closing network...")
rednet.close(CONFIG.SOURCE_SIDE)
print("Program ended.")