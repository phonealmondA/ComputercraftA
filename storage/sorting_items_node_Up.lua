-- Configuration
local CONFIG = {
    MODEM_SIDE = "right",
    CHEST_SLOTS = 54,
    HIGH_COUNT_THRESHOLD = 1000  -- Ignore items with counts above this
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