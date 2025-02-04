-- Configuration
local CONFIG = {
    MODEM_SIDE = "right",
    REFRESH_INTERVAL = 5,
    CHEST_SLOTS = 54,  -- Standard double chest size
    -- Items that should always be considered high priority regardless of quantity
    PRIORITY_OVERRIDE = {
        -- Diamond tier
        "minecraft:diamond",
        "minecraft:diamond_block",
        "minecraft:diamond_ore",
        "minecraft:deepslate_diamond_ore",
        
        -- Gold tier
        "minecraft:gold_ingot",
        "minecraft:gold_block",
        "minecraft:raw_gold",
        "minecraft:gold_ore",
        "minecraft:deepslate_gold_ore",
        "minecraft:nether_gold_ore",
        
        -- Iron tier
        "minecraft:iron_ingot",
        "minecraft:iron_block",
        "minecraft:raw_iron",
        "minecraft:iron_ore",
        "minecraft:deepslate_iron_ore",
        
        -- Copper tier
        "minecraft:copper_ingot",
        "minecraft:copper_block",
        "minecraft:raw_copper",
        "minecraft:copper_ore",
        "minecraft:deepslate_copper_ore",
        
        -- Redstone tier
        "minecraft:redstone",
        "minecraft:redstone_block",
        "minecraft:redstone_ore",
        "minecraft:deepslate_redstone_ore",
        
        -- ComputerCraft items
        "computercraft:computer_normal",
        "computercraft:computer_advanced",
        "computercraft:turtle_normal",
        "computercraft:turtle_advanced",
        "computercraft:disk_drive",
        "computercraft:wireless_modem_normal",
        "computercraft:wireless_modem_advanced",
        "computercraft:monitor_normal",
        "computercraft:monitor_advanced",
        "computercraft:speaker",
        "computercraft:printed_page",
        "computercraft:printed_book",
        "computercraft:pocket_computer_normal",
        "computercraft:pocket_computer_advanced"
    }
}

-- Function to wait for user input
local function waitForInput(message)
    print("\n" .. message)
    print("Press any key to continue...")
    os.pullEvent("key")
end

-- Get all chests and sort by their ID number
local function getChests()
    print("Scanning for chests on right network...")
    local chests = {}
    
    -- Only get peripherals from right modem
    local rightModem = peripheral.wrap(CONFIG.MODEM_SIDE)
    if not rightModem then
        error("Could not access right modem")
    end
    
    local peripheralNames = rightModem.getNamesRemote()
    for _, name in ipairs(peripheralNames) do
        if string.match(name, "minecraft:chest_%d+") then
            local id = tonumber(string.match(name, "minecraft:chest_(%d+)"))
            table.insert(chests, {
                name = name,
                id = id,
                peripheral = peripheral.wrap(name)
            })
            print(string.format("Found chest: %s (ID: %d)", name, id))
        end
    end
    
    table.sort(chests, function(a, b) return a.id < b.id end)
    print(string.format("Total chests found on right network: %d", #chests))
    waitForInput("Chest scanning complete.")
    return chests
end

-- Scan all chests and build item quantity map
local function scanInventory()
    print("\nScanning chest contents...")
    local items = {}
    local chests = getChests()
    local totalItems = 0
    
    for _, chest in ipairs(chests) do
        print(string.format("\nScanning chest %s (ID: %d)", chest.name, chest.id))
        local inventory = chest.peripheral.list()
        if inventory then
            local chestItems = 0
            for slot, item in pairs(inventory) do
                local detail = chest.peripheral.getItemDetail(slot)
                if detail then
                    if not items[detail.name] then
                        items[detail.name] = {
                            name = detail.name,
                            displayName = detail.displayName,
                            count = 0,
                            locations = {}
                        }
                    end
                    items[detail.name].count = items[detail.name].count + item.count
                    table.insert(items[detail.name].locations, {
                        chest = chest.name,
                        slot = slot,
                        count = item.count
                    })
                    chestItems = chestItems + 1
                end
            end
            print(string.format("  Found %d unique items in this chest (%d/%d slots used)", 
                chestItems, chestItems, CONFIG.CHEST_SLOTS))
            totalItems = totalItems + chestItems
        end
    end
    print(string.format("\nTotal items found across all chests: %d", totalItems))
    waitForInput("Inventory scan complete.")
    return items
end

-- Sort items by rarity (quantity)
local function sortItemsByRarity(items)
    print("\nSorting items by priority and rarity...")
    local itemList = {}
    for _, item in pairs(items) do
        table.insert(itemList, item)
    end
    
    table.sort(itemList, function(a, b)
        -- Check priority override first
        local aOverride = false
        local bOverride = false
        for i, priority in ipairs(CONFIG.PRIORITY_OVERRIDE) do
            if a.name == priority then aOverride = true; a.priorityIndex = i end
            if b.name == priority then bOverride = true; b.priorityIndex = i end
        end
        if aOverride and bOverride then
            return a.priorityIndex < b.priorityIndex
        end
        if aOverride then return true end
        if bOverride then return false end
        
        return a.count < b.count
    end)
    
    print("Priority items found:")
    for _, item in ipairs(itemList) do
        if item.priorityIndex then
            print(string.format("  %s (Priority: %d)", item.displayName, item.priorityIndex))
        end
    end
    
    waitForInput("Item sorting complete.")
    return itemList
end

-- Move items between chests
local function moveItems()
    print("\n=== Starting item organization ===")
    print("Time: " .. textutils.formatTime(os.time(), true))
    
    -- Get current inventory state
    local items = scanInventory()
    local sortedItems = sortItemsByRarity(items)
    local chests = getChests()
    
    -- Track used slots in each chest
    local chestSlots = {}
    for _, chest in ipairs(chests) do
        chestSlots[chest.name] = {
            used = 0,
            inventory = chest.peripheral.list()
        }
        -- Count currently used slots
        for _ in pairs(chestSlots[chest.name].inventory) do
            chestSlots[chest.name].used = chestSlots[chest.name].used + 1
        end
        print(string.format("Chest %s has %d/%d slots used", 
            chest.name, chestSlots[chest.name].used, CONFIG.CHEST_SLOTS))
    end
    
    -- Calculate ideal distribution
    local itemsPerChest = math.ceil(#sortedItems / #chests)
    print(string.format("\nPlanning distribution: ~%d items per chest", itemsPerChest))
    waitForInput("Ready to begin moving items.")
    
    -- Track progress
    local totalMoves = 0
    local targetMoves = 0
    
    -- Count needed moves
    for _, item in ipairs(sortedItems) do
        targetMoves = targetMoves + #item.locations
    end
    
    -- Move items to their target chests
    for itemIndex, item in ipairs(sortedItems) do
        local targetChestIndex = math.ceil(itemIndex / itemsPerChest)
        local targetChest = chests[targetChestIndex]
        
        -- Find next available chest if current target is full
        while targetChestIndex <= #chests and 
              chestSlots[targetChest.name].used >= CONFIG.CHEST_SLOTS do
            targetChestIndex = targetChestIndex + 1
            if targetChestIndex <= #chests then
                targetChest = chests[targetChestIndex]
                print(string.format("  Skipping full chest, trying chest %s", targetChest.name))
            else
                print("All chests are full! Ending cycle.")
                return
            end
        end
        
        print(string.format("\nProcessing %s", item.displayName))
        print(string.format("  Current quantity: %d", item.count))
        print(string.format("  Target chest: %s (ID: %d, Slots used: %d/%d)", 
            targetChest.name, targetChest.id, 
            chestSlots[targetChest.name].used, CONFIG.CHEST_SLOTS))
        
        -- Track if we've moved this item type to the target chest
        local itemPlaced = false
        
        -- Move all instances of this item to target chest
        for _, location in ipairs(item.locations) do
            if location.chest ~= targetChest.name then
                local sourceChest = peripheral.wrap(location.chest)
                if sourceChest then
                    -- Only attempt move if target chest has space
                    if chestSlots[targetChest.name].used < CONFIG.CHEST_SLOTS then
                        print(string.format("  Moving from chest %s to %s...", 
                            location.chest, targetChest.name))
                        local moved = sourceChest.pushItems(targetChest.name, location.slot)
                        if moved > 0 then
                            totalMoves = totalMoves + 1
                            if not itemPlaced then
                                chestSlots[targetChest.name].used = 
                                    chestSlots[targetChest.name].used + 1
                                itemPlaced = true
                            end
                            print(string.format(
                                "    Moved %d items successfully (%d/%d moves complete)", 
                                moved, totalMoves, targetMoves))
                        else
                            print("    Failed to move items - target chest might be full")
                        end
                    else
                        print("    Target chest is full, skipping remaining moves for this item")
                        break
                    end
                end
            else
                print(string.format("  Items already in correct chest (%s)", targetChest.name))
            end
        end
        
        if itemIndex % 5 == 0 then
            waitForInput(string.format("Completed %d/%d items. Continue?", 
                itemIndex, #sortedItems))
        end
    end
    
    print(string.format("\nOrganization complete! Made %d moves.", totalMoves))
    print("=== Organization cycle finished ===\n")
    waitForInput("Organization cycle complete.")
end

-- Main program
print("=== Starting chest organization system ===")
print("Version: 1.1")
print("Time: " .. textutils.formatTime(os.time(), true))

if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
    error("No modem found on " .. CONFIG.MODEM_SIDE .. " side")
end

print(string.format("Modem found on %s side", CONFIG.MODEM_SIDE))
print("System running with refresh interval: " .. CONFIG.REFRESH_INTERVAL .. " seconds")
print("Priority override list contains " .. #CONFIG.PRIORITY_OVERRIDE .. " items")
print("Chest slot limit set to: " .. CONFIG.CHEST_SLOTS .. " slots")

waitForInput("System initialized. Begin operation?")

while true do
    local success, error = pcall(moveItems)
    if not success then
        print("\nERROR during organization: " .. error)
        print("Will retry after delay...")
    end
    
    waitForInput("Begin next organization cycle?")
end