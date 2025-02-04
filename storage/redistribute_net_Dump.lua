-- Configuration
local CONFIG = {
    TARGET_CHEST = "minecraft:chest_102",  -- Target networked chest ID
    MODEM_SIDE = "left"
}

-- Initialize modem
if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
    error("No modem found on " .. CONFIG.MODEM_SIDE .. " side")
end

print("Starting item transfer from left-side chests...")

-- Get config chest
local configChest = peripheral.wrap(CONFIG.TARGET_CHEST)
if not configChest then
    error("Config chest not found!")
end

while true do
    -- Check if target chest is full
    local targetItems = configChest.list()
    local emptySlot = false
    for i = 1, configChest.size() do
        if not targetItems[i] then
            emptySlot = true
            break
        end
    end
    
    if not emptySlot then
        print("Target chest full! Running redistribution program...")
        shell.run("redistribute.lua")
        break
    end
    
    -- Get all networked chests from left side modem only
    local leftChests = {}
    local leftModem = peripheral.wrap(CONFIG.MODEM_SIDE)
    if leftModem then
        for _, name in ipairs(leftModem.getNamesRemote()) do
            if string.match(name, "minecraft:chest") and name ~= CONFIG.TARGET_CHEST then
                leftChests[name] = true
            end
        end
    end
    
    -- Pull items from each left-side chest
    local moved = false
    for chestName in pairs(leftChests) do
        local chest = peripheral.wrap(chestName)
        if chest then
            local items = chest.list()
            for slot, item in pairs(items) do
                local moved_count = configChest.pullItems(chestName, slot)
                if moved_count > 0 then
                    moved = true
                end
            end
        end
    end
    
    if not moved then
        print("No more items to move!")
        break
    end
    
    sleep(0.5)
end

print("Transfer complete!")