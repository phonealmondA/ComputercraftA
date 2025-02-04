-- Configuration
local CONFIG = {
    MODEM_SIDE = "right",
    CHEST_SLOTS = 54,
    HIGH_COUNT_THRESHOLD = 1000
}

-- Slot tracking system
local SlotManager = {
    slots = {},
    
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
        if not self.slots[chestName] then 
            return 1 
        end
        
        for i = 1, CONFIG.CHEST_SLOTS do
            if not self.slots[chestName][i] then
                return i
            end
        end
        return nil
    end
}

-- Item counting function
local function getTotalItemCounts()
    local modem = peripheral.wrap(CONFIG.MODEM_SIDE)
    local itemTotals = {}
    local itemLocations = {}
    
    for _, name in ipairs(modem.getNamesRemote()) do
        if string.match(name, "minecraft:chest_%d+") then
            local chest = peripheral.wrap(name)
            local id = tonumber(string.match(name, "minecraft:chest_(%d+)"))
            SlotManager:updateChestData(name, chest)
            
            for slot, itemData in pairs(SlotManager.slots[name]) do
                if not itemTotals[itemData.name] then
                    itemTotals[itemData.name] = 0
                    itemLocations[itemData.name] = {}
                end
                itemTotals[itemData.name] = itemTotals[itemData.name] + itemData.count
                table.insert(itemLocations[itemData.name], {
                    chest = name,
                    id = id,
                    slot = slot,
                    count = itemData.count
                })
            end
        end
    end
    return itemTotals, itemLocations
end

-- List categorization
local function categorizeLists()
    local itemTotals, itemLocations = getTotalItemCounts()
    local listA = {}
    local listB = {}
    
    for itemName, total in pairs(itemTotals) do
        if total >= CONFIG.HIGH_COUNT_THRESHOLD then
            listA[itemName] = itemLocations[itemName]
        else
            listB[itemName] = itemLocations[itemName]
        end
    end
    
    return listA, listB
end

-- Get chest list
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
    
    table.sort(chests, function(a, b) return a.id < b.id end)
    return chests
end

-- Main item movement function
local function moveItems()
    local chests = getChests()
    local moves = 0
    local listA, listB = categorizeLists()
    
    print("Phase 1: Moving low-count items out of high ID chests")
    for itemName, locations in pairs(listB) do
        for _, location in ipairs(locations) do
            if location.id > math.floor(#chests/2) then
                for i = 1, math.floor(#chests/2) do
                    local targetChest = chests[i]
                    local targetSlot = SlotManager:findEmptySlot(targetChest.name)
                    if targetSlot then
                        local sourceChest = peripheral.wrap(location.chest)
                        local moved = sourceChest.pushItems(targetChest.name, location.slot)
                        if moved > 0 then
                            moves = moves + 1
                            print(string.format("Moved %s (%d) from chest %d to chest %d", 
                                itemName, moved, location.id, targetChest.id))
                            break
                        end
                    end
                end
            end
        end
    end
    
    print("\nPhase 2: Moving high-count items to high ID chests")
    for itemName, locations in pairs(listA) do
        for _, location in ipairs(locations) do
            for i = #chests, math.ceil(#chests/2), -1 do
                local targetChest = chests[i]
                local targetSlot = SlotManager:findEmptySlot(targetChest.name)
                if targetSlot then
                    local sourceChest = peripheral.wrap(location.chest)
                    local moved = sourceChest.pushItems(targetChest.name, location.slot)
                    if moved > 0 then
                        moves = moves + 1
                        print(string.format("Moved %s (%d) from chest %d to chest %d", 
                            itemName, moved, location.id, targetChest.id))
                        break
                    end
                end
            end
        end
    end
    
    print("\nPhase 3: Consolidating low-count items in lower ID chests")
    for itemName, locations in pairs(listB) do
        for _, location in ipairs(locations) do
            for i = 1, math.floor(#chests/2) do
                local targetChest = chests[i]
                local targetSlot = SlotManager:findEmptySlot(targetChest.name)
                if targetSlot then
                    local sourceChest = peripheral.wrap(location.chest)
                    local moved = sourceChest.pushItems(targetChest.name, location.slot)
                    if moved > 0 then
                        moves = moves + 1
                        print(string.format("Moved %s (%d) from chest %d to chest %d", 
                            itemName, moved, location.id, targetChest.id))
                        break
                    end
                end
            end
        end
    end
    
    return moves
end

-- Main program loop
local function main()
    if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
        error("No modem found on " .. CONFIG.MODEM_SIDE .. " side")
    end
    
    SlotManager:init()
    
        local moves = moveItems()
        print(string.format("\nCompleted %d moves", moves))
    
end

-- Start program
pcall(main)