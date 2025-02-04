-- Configuration
local CONFIG = {
    TARGET_CHEST = "minecraft:chest_56",  -- Target networked chest ID
    MODEM_SIDE = "right"
}

-- Initialize modem
if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
    error("No modem found on " .. CONFIG.MODEM_SIDE .. " side")
end

print("Starting item transfer from right-side chests...")

-- Get config chest
local configChest = peripheral.wrap(CONFIG.TARGET_CHEST)
if not configChest then
    error("Config chest not found!")
end

-- Get all networked chests from right side modem only
local rightChests = {}
local rightModem = peripheral.wrap(CONFIG.MODEM_SIDE)
if rightModem then
    for _, name in ipairs(rightModem.getNamesRemote()) do
        if string.match(name, "minecraft:chest") and name ~= CONFIG.TARGET_CHEST then
            table.insert(rightChests, name)
        end
    end
end

-- Print found chests for debugging
print("Found right-side chests:")
for _, name in ipairs(rightChests) do
    print("- " .. name)
end

-- Pull items from each right-side chest into config chest
for _, chestName in ipairs(rightChests) do
    local chest = peripheral.wrap(chestName)
    if chest then
        local items = chest.list()
        for slot, item in pairs(items) do
            configChest.pullItems(chestName, slot)
        end
    end
end

print("Transfer complete!")