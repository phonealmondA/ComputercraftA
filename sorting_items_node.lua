-- Configuration
local CONFIG = {
    MODEM_SIDE = "right",
    REFRESH_INTERVAL = 5,
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

-- Get all chests and sort by their ID number
local function getChests()
    local chests = {}
    for _, name in ipairs(peripheral.getNames()) do
        if string.match(name, "minecraft:chest_%d+") then
            local id = tonumber(string.match(name, "minecraft:chest_(%d+)"))
            table.insert(chests, {
                name = name,
                id = id,
                peripheral = peripheral.wrap(name)
            })
        end
    end
    -- Sort chests by ID (lower numbers = higher in stack)
    table.sort(chests, function(a, b) return a.id < b.id end)
    return chests
end

-- Scan all chests and build item quantity map
local function scanInventory()
    local items = {}
    local chests = getChests()
    
    for _, chest in ipairs(chests) do
        local inventory = chest.peripheral.list()
        if inventory then
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
                end
            end
        end
    end
    return items
end

-- Sort items by rarity (quantity)
local function sortItemsByRarity(items)
    local itemList = {}
    for _, item in pairs(items) do
        table.insert(itemList, item)
    end
    
    -- Sort items by quantity (rarer items first)
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
    
    return itemList
end

-- Move items between chests
local function moveItems()
    print("Starting item organization...")
    
    -- Get current inventory state
    local items = scanInventory()
    local sortedItems = sortItemsByRarity(items)
    local chests = getChests()
    
    -- Calculate ideal distribution
    local itemsPerChest = math.ceil(#sortedItems / #chests)
    
    -- Track progress
    local totalMoves = 0
    
    -- Move items to their target chests
    for itemIndex, item in ipairs(sortedItems) do
        local targetChestIndex = math.ceil(itemIndex / itemsPerChest)
        local targetChest = chests[targetChestIndex]
        
        print(string.format("Processing %s (Quantity: %d)", 
            item.displayName, item.count))
        
        -- Move all instances of this item to target chest
        for _, location in ipairs(item.locations) do
            if location.chest ~= targetChest.name then
                local sourceChest = peripheral.wrap(location.chest)
                if sourceChest then
                    local moved = sourceChest.pushItems(targetChest.name, location.slot)
                    if moved > 0 then
                        totalMoves = totalMoves + 1
                        print(string.format("  Moved %d items from chest %s to chest %s",
                            moved, location.chest, targetChest.name))
                    end
                end
            end
        end
    end
    
    print(string.format("Organization complete! Made %d moves.", totalMoves))
end

-- Main program
print("Starting chest organization system...")
if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
    error("No modem found on " .. CONFIG.MODEM_SIDE .. " side")
end

while true do
    local success, error = pcall(moveItems)
    if not success then
        print("Error during organization: " .. error)
    end
    
    print(string.format("Waiting %d seconds before next organization...", 
        CONFIG.REFRESH_INTERVAL))
    os.sleep(CONFIG.REFRESH_INTERVAL)
end