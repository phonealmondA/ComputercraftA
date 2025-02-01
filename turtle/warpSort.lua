-- Warp Storage System
-- Complete version with all functions and scrolling interface

-- Initialize warp drive
if not peripheral.isPresent("left") then
    error("Warp Drive not found on left side")
end
local warpDrive = peripheral.wrap("left")
--save original location
warpDrive.savePoint("start")

-- Safe warping function
local function safeWarp(point)
    if not point then return false end
    os.sleep(1.5) -- Essential delay before warp
    return warpDrive.warpToPoint(point)
end

-- Generic scrolling display function
local function displayScrollingList(items, currentIndex, title, formatter)
    term.clear()
	--clear screen before each print
    print(title)--apears from input 3
    print("-----------------------------------------------")
    for i = currentIndex, math.min(currentIndex + 3, #items) do--(index list, +3 appears to be its leng of list) to end of list# or total items.
        print(formatter(i, items[i]))--(formatter unknown) inputs i (loop), items(i)
    end
    print("\nUp/Down arrows to scroll, Enter to select")--code to print, describes control of formatter. 
end

-- List selection function
local function selectFromList(items, title, formatter)
    if #items == 0 then return nil end
    
    local currentIndex = 1
    while true do
        displayScrollingList(items, currentIndex, title,  )
        local event, key = os.pullEvent("key")
        
        if key == keys.up and currentIndex > 1 then
            currentIndex = currentIndex - 1
        elseif key == keys.down and currentIndex < #items - 3 then
            currentIndex = currentIndex + 1
        elseif key == keys.enter then
            term.clear()
            print("Enter the number (1-" .. #items .. "):")
            local choice = tonumber(read())
            if choice and items[choice] then
                return choice, items[choice]
            end
            print("Invalid selection")
        end
    end
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

    -- Show scrollable list of points
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

-- Retrieve items from storage
local function retrieveItems()
    local savedPoints = warpDrive.points()
    if #savedPoints == 0 then
        print("No warp points saved!")
        return
    end

    -- Check inventory space first
    local hasSpace = false
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            hasSpace = true
            break
        end
    end
    
    if not hasSpace then
        print("No empty inventory slots!")
        return
    end

    print("\nEnter search term (partial match):")
    local searchTerm = read():lower()
    
    -- Find matching points
    local matches = {}
    for _, point in ipairs(savedPoints) do
        if point ~= "start" and point:lower():find(searchTerm) then
            table.insert(matches, point)
        end
    end
    
    if #matches == 0 then
        print("No matching storage points found")
        return
    end
    
    -- Show scrollable list of matching points
    local choice, selectedPoint = selectFromList(matches, "Matching Storage Points:", 
        function(i, point) return i .. ". " .. point end)
    
    if not choice then return end
    
    -- Warp to selected storage location
    if safeWarp(selectedPoint) then
        -- Get chest contents
        local chest = peripheral.wrap("bottom")
        if not chest then
            print("No chest found at storage location")
            safeWarp("start")
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
        
        -- Return to start for item selection
        safeWarp("start")
        
        if #chestContents == 0 then
            print("Chest is empty")
            return
        end
        
        -- Show scrollable list of items
        local itemChoice, selectedItem = selectFromList(chestContents, "Chest Contents:",
            function(i, item) return string.format("%d. Slot %d: %s (x%d)", 
                i, item.slot, item.name, item.count) end)
        
        if not itemChoice then return end
        
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
        
        -- Retrieve the item
        if safeWarp(selectedPoint) then
            turtle.select(emptySlot)
            if turtle.suckDown() then
                print("Successfully retrieved items")
            else
                print("Failed to retrieve items")
            end
            safeWarp("start")
        else
            print("Failed to reach storage location")
        end
    else
        print("Failed to reach storage point")
    end
end

-- Main menu
local function mainMenu()
    while true do
        print("\nWarp Storage System")
        print("1. Sort Inventory")
        print("2. Retrieve Items")
        print("3. List Points")
        print("4. Setup New Point")
        print("5. Delete Point")
        print("6. Exit")
        
        local choice = read()
        
        if choice == "1" then
            sortInventory()
        elseif choice == "2" then
            retrieveItems()
        elseif choice == "3" then
            listPoints()
        elseif choice == "4" then
            setupPoint()
        elseif choice == "5" then
            deletePoints()
        elseif choice == "6" then
            print("Exiting...")
            break
        else
            print("Invalid choice")
        end
    end
end

-- Start program
print("Warp Storage System Starting...")
mainMenu()