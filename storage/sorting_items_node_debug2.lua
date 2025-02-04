-- Configuration
local CONFIG = {
    MODEM_SIDE = "right",
    CHEST_SLOTS = 54
}

-- Slot tracking system
local SlotManager = {
    slots = {}, -- Format: slots[chestName][slotNumber] = {name=string, count=number}
    
    init = function(self)
        if fs.exists("slot_data.txt") then
            local file = fs.open("slot_data.txt", "r")
            self.slots = textutils.unserialize(file.readAll())
            file.close()
            print("Loaded saved slot data")
        end
    end,
    
    save = function(self)
        local file = fs.open("slot_data.txt", "w")
        file.write(textutils.serialize(self.slots))
        file.close()
    end,
    
    updateChestData = function(self, chestName, chestPeripheral)
        if not self.slots[chestName] then
            self.slots[chestName] = {}
        end
        
        local inventory = chestPeripheral.list()
        for i = 1, CONFIG.CHEST_SLOTS do
            self.slots[chestName][i] = nil
        end
        
        for slot, item in pairs(inventory) do
            local detail = chestPeripheral.getItemDetail(slot)
            if detail then
                self.slots[chestName][slot] = {
                    name = detail.name,
                    count = item.count
                }
            end
        end
    end,
    
    findEmptySlot = function(self, chestName)
        if not self.slots[chestName] then return 1 end
        
        for i = 1, CONFIG.CHEST_SLOTS do
            if not self.slots[chestName][i] then
                return i
            end
        end
        return nil
    end
}

-- Function to scan all chests and find items by count
local function scanAndSortItems()
    local modem = peripheral.wrap(CONFIG.MODEM_SIDE)
    local items = {}  -- Format: {name = {total = number, locations = {chest, slot, count}}}
    
    -- Scan all chests
    for _, name in ipairs(modem.getNamesRemote()) do
        if string.match(name, "minecraft:chest_%d+") then
            local chest = peripheral.wrap(name)
            local id = tonumber(string.match(name, "minecraft:chest_(%d+)"))
            SlotManager:updateChestData(name, chest)
            
            for slot, itemData in pairs(SlotManager.slots[name]) do
                if not items[itemData.name] then
                    items[itemData.name] = {
                        total = 0,
                        locations = {}
                    }
                end
                items[itemData.name].total = items[itemData.name].total + itemData.count
                table.insert(items[itemData.name].locations, {
                    chest = name,
                    id = id,
                    slot = slot,
                    count = itemData.count
                })
            end
        end
    end
    
    -- Convert to sorted list
    local itemList = {}
    for name, data in pairs(items) do
        table.insert(itemList, {
            name = name,
            total = data.total,
            locations = data.locations
        })
    end
    
    -- Sort by total count (highest first)
    table.sort(itemList, function(a, b) return a.total > b.total end)
    
    return itemList
end

local function getChests()
    local chests = {}
    local modem = peripheral.wrap(CONFIG.MODEM_SIDE)
    
    for _, name in ipairs(modem.getNamesRemote()) do
        if string.match(name, "minecraft:chest_%d+") then
            local id = tonumber(string.match(name, "minecraft:chest_(%d+)"))
            table.insert(chests, {
                name = name,
                id = id,
                peripheral = peripheral.wrap(name)
            })
        end
    end
    
    -- Sort by ID (highest first)
    table.sort(chests, function(a, b) return a.id > b.id end)
    return chests
end

local function moveItems()
    local chests = getChests()
    local moves = 0
    local sortedItems = scanAndSortItems()
    
    print("\nFound items by quantity:")
    for i, item in ipairs(sortedItems) do
        print(string.format("%s: %d total", item.name, item.total))
        if i == 5 then break end  -- Show top 5 items
    end
    
    -- Process each item type, starting with highest quantity
    for _, item in ipairs(sortedItems) do
        print(string.format("\nMoving %s (Total: %d)", item.name, item.total))
        
        -- Sort locations by chest ID (lowest first)
        table.sort(item.locations, function(a, b) return a.id < b.id end)
        
        -- Try to move to highest ID chests first
        for _, targetChest in ipairs(chests) do
            for _, location in ipairs(item.locations) do
                -- Only move up to higher numbered chests
                if location.id < targetChest.id then
                    local targetSlot = SlotManager:findEmptySlot(targetChest.name)
                    if targetSlot then
                        local sourceChest = peripheral.wrap(location.chest)
                        local moved = sourceChest.pushItems(targetChest.name, location.slot)
                        if moved > 0 then
                            moves = moves + 1
                            print(string.format("Moved %d items: %s (ID:%d Slot:%d) -> %s (ID:%d Slot:%d)",
                                moved,
                                location.chest, location.id, location.slot,
                                targetChest.name, targetChest.id, targetSlot))
                                
                            -- Update slot tracking
                            SlotManager.slots[targetChest.name][targetSlot] = {
                                name = item.name,
                                count = moved
                            }
                            SlotManager.slots[location.chest][location.slot] = nil
                        end
                    end
                end
            end
        end
    end
    
    return moves
end

local function main()
    if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
        error("No modem found on " .. CONFIG.MODEM_SIDE .. " side")
    end
    
    SlotManager:init()
    
    while true do
        local moves = moveItems()
        print(string.format("\nCompleted %d moves", moves))
        print("\nPress any key to start next cycle...")
        os.pullEvent("key")
    end
end

-- Start program
pcall(main)