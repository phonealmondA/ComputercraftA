-- item_searcher.lua
local CONFIG = {
    SOURCE_SIDE = "right",
    DEST_SIDE = "left"
}

-- Initialize cache structures
local Cache = {
    sourceChests = {},  -- right network chests
    destChests = {},    -- left network chests
    itemLocations = {}, -- where items are stored
}

-- Initialize networks
print("Initializing networks...")
if not peripheral.isPresent(CONFIG.SOURCE_SIDE) then
    error("No modem found on " .. CONFIG.SOURCE_SIDE .. " side!")
end
if not peripheral.isPresent(CONFIG.DEST_SIDE) then
    error("No modem found on " .. CONFIG.DEST_SIDE .. " side!")
end

-- Get all chests on a network
local function scanNetwork(side)
    local chests = {}
    print("Scanning " .. side .. " network...")
    local names = peripheral.getNames()
    print("Found peripherals: ")
    for _, name in ipairs(names) do
        print("  " .. name .. " (type: " .. peripheral.getType(name) .. ")")
        if peripheral.getType(name) == "minecraft:chest" then
            print("    Adding chest: " .. name)
            chests[name] = peripheral.wrap(name)
        end
    end
    print("Found " .. #chests .. " chests on " .. side)
    return chests
end

-- Scan source network and cache item locations
local function updateSourceCache()
    print("Updating source cache...")
    Cache.sourceChests = scanNetwork(CONFIG.SOURCE_SIDE)
    Cache.itemLocations = {}
    
    for chestName, chest in pairs(Cache.sourceChests) do
        print("Scanning chest: " .. chestName)
        local inventory = chest.list()
        if inventory then
            for slot, item in pairs(inventory) do
                local detail = chest.getItemDetail(slot)
                if detail then
                    if not Cache.itemLocations[detail.name] then
                        Cache.itemLocations[detail.name] = {
                            displayName = detail.displayName,
                            locations = {}
                        }
                    end
                    table.insert(Cache.itemLocations[detail.name].locations, {
                        chest = chestName,
                        slot = slot,
                        count = item.count
                    })
                end
            end
        else
            print("  No inventory found!")
        end
    end
    
    local count = 0
    for _ in pairs(Cache.itemLocations) do count = count + 1 end
    print("Cache update complete - Found " .. count .. " unique items")
end

-- Search for items matching term
local function searchItems(term)
    local results = {}
    local index = 1
    term = string.lower(term)
    
    for itemName, info in pairs(Cache.itemLocations) do
        if string.find(string.lower(itemName), term) or 
           string.find(string.lower(info.displayName), term) then
            -- Calculate total count
            local total = 0
            for _, loc in ipairs(info.locations) do
                total = total + loc.count
            end
            
            results[index] = {
                index = index,
                name = itemName,
                displayName = info.displayName,
                count = total
            }
            index = index + 1
        end
    end
    
    return results
end

-- Transfer items to destination network
local function transferItems(itemName)
    local destChests = scanNetwork(CONFIG.DEST_SIDE)
    local locations = Cache.itemLocations[itemName].locations
    if not locations then return false end
    
    -- Try to fill each destination chest
    for destName, _ in pairs(destChests) do
        for _, loc in ipairs(locations) do
            local sourceChest = peripheral.wrap(loc.chest)
            if sourceChest then
                sourceChest.pushItems(destName, loc.slot)
            end
        end
    end
    
    -- Update cache after transfers
    updateSourceCache()
    return true
end

-- Main program loop
while true do
    term.clear()
    term.setCursorPos(1,1)
    print("Item Search and Transfer System")
    print("===============================")
    print("Enter search term (or 'exit' to quit):")
    
    local input = read()
    if input:lower() == "exit" then
        break
    end
    
    -- Update cache and search
    updateSourceCache()
    local results = searchItems(input)
    
    -- Display results
    if #results == 0 then
        print("No items found matching: " .. input)
        print("\nPress any key to continue...")
        os.pullEvent("key")
    else
        print("\nFound items:")
        print("-------------")
        for _, item in ipairs(results) do
            print(string.format("%d. %s (x%d)", 
                item.index, 
                item.displayName, 
                item.count))
        end
        
        print("\nPress any key to continue...")
        os.pullEvent("key")
        print("\nEnter number to transfer item (or 0 to search again):")
        local selection = tonumber(read())
        
        if selection and selection > 0 and selection <= #results then
            print("Transferring " .. results[selection].displayName .. "...")
            transferItems(results[selection].name)
            print("Transfer complete!")
            print("Press any key to continue...")
            os.pullEvent("key")
        end
    end
end

print("Program terminated.")