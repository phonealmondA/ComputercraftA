-- Get peripheral access
local warpDrive = peripheral.wrap("left")

-- Save starting position
warpDrive.savePoint("start")

-- Define item categories and their warp points
local itemDestinations = {
    -- Wood types
    birch = "birch",
    oak = "oak",
    spruce = "spruce",
    jungle = "jungle",
    acacia = "acacia",
    dark_oak = "dark_oak",
    mangrove = "mangrove",

    -- Basic materials
    cobble = "cobble",
    stone = "stone",
    dirt = "dirt",
    gravel = "gravel",
    sand = "sand",

    -- Crafted items
    stick = "stick",
    plank = "planks",
    slab = "slabs",
    stair = "stairs",
    fence = "fences",

    -- Ores and minerals
    iron = "iron",
    gold = "gold",
    coal = "coal",
    diamond = "diamond",
    emerald = "emerald",
    redstone = "redstone",
    lapis = "lapis",
    copper = "copper"
}

-- Function to check if string contains any of our keywords
local function matchesCategory(itemName)
    for category in pairs(itemDestinations) do
        if itemName:find(category) then
            return category
        end
    end
    return nil
end

-- Function to list all saved warp points
local function listWarpPoints()
    local points = warpDrive.points()
    if #points == 0 then
        print("No warp points saved")
        return points
    end
    
    print("\nSaved Warp Points:")
    for i, point in ipairs(points) do
        print(i .. ". " .. point)
		os.pullEvent("key")
    end
    return points
end

-- Function to delete warp points
local function deleteWarpPoints()
    while true do
        print("\nDelete Warp Points:")
        print("1. Delete single point")
        print("2. Delete multiple points")
        print("3. Delete all points")
        print("4. Back to main menu")
        
        local choice = read()
        
        if choice == "1" then
            local points = listWarpPoints()
            if #points > 0 then
                print("\nEnter number to delete (1-" .. #points .. "):")
                local num = tonumber(read())
                if num and points[num] then
                    warpDrive.deletePoint(points[num])
                    print("Deleted point: " .. points[num])
                else
                    print("Invalid selection")
                end
            end
            
        elseif choice == "2" then
            local points = listWarpPoints()
            if #points > 0 then
                print("\nEnter numbers to delete (comma-separated, e.g. 1,3,5):")
                local input = read()
                for num in input:gmatch("%d+") do
                    num = tonumber(num)
                    if num and points[num] then
                        warpDrive.deletePoint(points[num])
                        print("Deleted point: " .. points[num])
                    end
                end
            end
            
        elseif choice == "3" then
            local points = warpDrive.points()
            print("\nAre you sure you want to delete ALL points? (y/n)")
            if read():lower() == "y" then
                for _, point in ipairs(points) do
                    warpDrive.deletePoint(point)
                    print("Deleted point: " .. point)
                end
                print("All points deleted")
            end
            
        elseif choice == "4" then
            break
        else
            print("Invalid choice")
        end
    end
end

-- Function to set up storage points
local function setupStoragePoints()
    print("Set up a new warp point? (y/n)")
    if read():lower() == "y" then
        print("Enter name for this warp point:")
        local pointName = read()
        if pointName ~= "" then
            if warpDrive.savePoint(pointName) then
                print("Saved point: " .. pointName)
                print("\nWould you like to set up another point? (y/n)")
                if read():lower() ~= "y" then
                    return
                end
            else
                print("Failed to save point: " .. pointName)
            end
        else
            print("Skipped - empty name provided")
        end
    end
end

-- Function to sort inventory
local function sortInventory()
    local savedPoints = warpDrive.points()
    local pointsExist = {}
    for _, point in ipairs(savedPoints) do
        pointsExist[point] = true
    end

    print("Starting inventory sorting...")
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        
        if item then
            local category = matchesCategory(item.name)
            
            if category and itemDestinations[category] and pointsExist[itemDestinations[category]] then
                turtle.select(slot)
                os.sleep(1.5)
                if warpDrive.warpToPoint(itemDestinations[category]) then
                    if turtle.dropDown() then
                        print("Dropped " .. item.name .. " at " .. category .. " storage")
                    else
                        print("Failed to drop " .. item.name .. " - storage might be full")
                    end
                else
                    print("Failed to warp to " .. category .. " storage point")
                end
            else
                if category then
                    print("No warp point found for: " .. item.name)
                else
                    print("No category match for: " .. item.name)
                end
            end
        end
    end
    os.sleep(1.5)
    warpDrive.warpToPoint("start")
    print("Sorting complete")
end

-- Function to retrieve items from chest
local function retrieveItems()
    print("\nEnter item name to retrieve (e.g. 'stick', 'oak', etc):")
    local searchTerm = read():lower()
    local category = matchesCategory(searchTerm)
    
    if not category then
        print("No storage category found for: " .. searchTerm)
        return
    end
    
    -- Warp to storage location
    os.sleep(1.5)
    local warpPoint = itemDestinations[category]
    if not warpDrive.warpToPoint(warpPoint) then
        print("Failed to warp to storage location")
        return
    end
    
    -- Wrap the chest below and get inventory
    local chest = peripheral.wrap("bottom")
    if not chest then
        print("No chest found below turtle")
        os.sleep(1.5)
        warpDrive.warpToPoint("start")
        return
    end
    
    -- Scan chest contents
    local chestContents = {}
    local chestSize = chest.size()
    for slot = 1, chestSize do
        local item = chest.getItemDetail(slot)
        if item then
            table.insert(chestContents, {
                slot = slot,
                name = item.name,
                count = item.count
            })
        end
    end
    
    -- Return to start position
    os.sleep(1.5)
    warpDrive.warpToPoint("start")
    
    if #chestContents == 0 then
        print("Chest is empty")
        return
    end
    
    -- Show chest contents with scrolling
    local currentIndex = 1
    local function displayItems()
        term.clear()
        print("Contents of chest (Press Up/Down to scroll, Enter to select):")
        print("-----------------------------------------------")
        for i = currentIndex, math.min(currentIndex + 3, #chestContents) do
            local item = chestContents[i]
            print(string.format("%d. Slot %d: %s (x%d)", 
                i, item.slot, item.name, item.count))
        end
    end
    
    -- Handle scrolling and selection
    while true do
        displayItems()
        local event, key = os.pullEvent("key")
        
        if key == 265 and currentIndex > 1 then
            currentIndex = currentIndex - 1
        elseif key == 264 and currentIndex < #chestContents - 3 then
            currentIndex = currentIndex + 1
        elseif key == 257 then
            break
        end
    end
    
    -- Get slot selection
    term.clear()
    print("Enter the number of the item to retrieve:")
    local selection = tonumber(read())
    
    if not selection or not chestContents[selection] then
        print("Invalid selection")
        return
    end
    
    -- Find empty turtle slot
    local emptySlot = -1
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            emptySlot = slot
            break
        end
    end
    
    if emptySlot == -1 then
        print("No empty slots in turtle inventory")
        return
    end
    
    -- Warp back to chest
    os.sleep(1.5)
    if not warpDrive.warpToPoint(warpPoint) then
        print("Failed to return to storage location")
        return
    end
    
    -- Pull the selected item
    turtle.select(emptySlot)
    if turtle.suckDown() then
        print("Successfully retrieved items")
    else
        print("Failed to retrieve items")
    end
    
    -- Return to start
    os.sleep(1.5)
    warpDrive.warpToPoint("start")
end

-- Main menu
while true do
    print("\nStorage System Menu:")
    print("1. Sort Inventory")
    print("2. Retrieve Items")
    print("3. List Warp Points")
    print("4. Setup New Points")
    print("5. Delete Points")
    print("6. Exit")
    
    local choice = read()
    
    if choice == "1" then
        sortInventory()
    elseif choice == "2" then
        retrieveItems()
    elseif choice == "3" then
        listWarpPoints()
    elseif choice == "4" then
        setupStoragePoints()
    elseif choice == "5" then
        deleteWarpPoints()
    elseif choice == "6" then
        break
    else
        print("Invalid choice")
    end
end