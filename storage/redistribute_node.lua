-- Configuration
local CONFIG = {
    SOURCE_CHEST = "minecraft:chest_1",  -- Right side config chest ID
    MODEM_SIDE = "right"
}

-- Initialize modem
if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
    error("No modem found on " .. CONFIG.MODEM_SIDE .. " side")
end

print("Starting item redistribution...")

-- Get source chest
local sourceChest = peripheral.wrap(CONFIG.SOURCE_CHEST)
if not sourceChest then
    error("Source chest not found!")
end

-- Find chests with empty slots
local availableChests = {}
for _, name in ipairs(peripheral.getNames()) do
    if string.match(name, "minecraft:chest_%d+") and 
       name ~= CONFIG.SOURCE_CHEST then
        local chest = peripheral.wrap(name)
        local items = chest.list()
        
        -- Check for any empty slot
        for i = 1, chest.size() do
            if not items[i] then
                table.insert(availableChests, name)
                break
            end
        end
    end
end

if #availableChests == 0 then
    print("No chests with empty slots available!")
    return
end

-- Transfer items to chests with empty slots
local currentChestIndex = 1
local items = sourceChest.list()

for slot, item in pairs(items) do
    if currentChestIndex <= #availableChests then
        local targetChest = availableChests[currentChestIndex]
        local moved = sourceChest.pushItems(targetChest, slot)
        
        -- If push failed (chest full), try next chest
        if moved == 0 then
            currentChestIndex = currentChestIndex + 1
            -- Try again with new chest if available
            if currentChestIndex <= #availableChests then
                sourceChest.pushItems(availableChests[currentChestIndex], slot)
            else
                print("No more chests with empty slots available!")
                break
            end
        end
    else
        print("No more chests with empty slots available!")
        break
    end
end

print("Redistribution complete!")