-- storage_node.lua
local CONFIG = {
    REQUEST_PROTOCOL = "item_network",
    SOURCE_SIDE = "right",
    DEST_SIDE = "left",
    OUTPUT_CHEST = "minecraft:chest_56",
    REFRESH_INTERVAL = 1
}

-- Initialize network
print("Initializing networks...")
if not peripheral.isPresent(CONFIG.SOURCE_SIDE) then
    error("No modem found on " .. CONFIG.SOURCE_SIDE .. " side!")
end
if not peripheral.isPresent(CONFIG.DEST_SIDE) then
    error("No modem found on " .. CONFIG.DEST_SIDE .. " side!")
end

rednet.open(CONFIG.SOURCE_SIDE)
rednet.open(CONFIG.DEST_SIDE)
print("Networks initialized")

-- Cache structures
local Cache = {
    -- Maps chest names to their contents
    chestContents = {}, -- Format: chestName = { slot = {name, count, displayName} }
    
    -- Maps item names to their locations
    itemLocations = {}, -- Format: itemName = { {chest = chestName, slot = slot, count = count} }
    
    -- Consolidated item counts
    totalItems = {},    -- Format: itemName = {count = total, displayName = name}
    
    -- Track changes for efficient updates
    lastUpdate = {}     -- Format: chestName = timestamp
}

-- Update cache for a single chest
local function updateChestCache(chestName, chest)
    local inventory = chest.list()
    local oldContents = Cache.chestContents[chestName] or {}
    local newContents = {}
    local changed = false

    -- Scan current contents
    if inventory then
        for slot, item in pairs(inventory) do
            local detail = chest.getItemDetail(slot)
            if detail then
                newContents[slot] = {
                    name = detail.name,
                    count = item.count,
                    displayName = detail.displayName
                }
                
                -- Check if slot changed
                local oldSlot = oldContents[slot]
                if not oldSlot or 
                   oldSlot.name ~= detail.name or 
                   oldSlot.count ~= item.count then
                    changed = true
                end
            end
        end
    end

    -- Check for removed items
    for slot, _ in pairs(oldContents) do
        if not newContents[slot] then
            changed = true
            break
        end
    end

    -- Only update if contents changed
    if changed then
        Cache.chestContents[chestName] = newContents
        Cache.lastUpdate[chestName] = os.epoch("utc")
        return true
    end
    return false
end

-- Rebuild item location cache
local function rebuildItemLocations()
    local newItemLocations = {}
    local newTotalItems = {}

    for chestName, contents in pairs(Cache.chestContents) do
        for slot, item in pairs(contents) do
            -- Update item locations
            if not newItemLocations[item.name] then
                newItemLocations[item.name] = {}
            end
            table.insert(newItemLocations[item.name], {
                chest = chestName,
                slot = slot,
                count = item.count
            })

            -- Update total counts
            if not newTotalItems[item.name] then
                newTotalItems[item.name] = {
                    count = 0,
                    displayName = item.displayName
                }
            end
            newTotalItems[item.name].count = newTotalItems[item.name].count + item.count
        end
    end

    Cache.itemLocations = newItemLocations
    Cache.totalItems = newTotalItems
end

-- Get inventory list for network requests
local function getInventoryList()
    local items = {}
    local index = 1
    for itemName, info in pairs(Cache.totalItems) do
        table.insert(items, {
            index = index,
            name = itemName,
            displayName = info.displayName,
            count = info.count
        })
        index = index + 1
    end
    return items
end

-- Optimized transfer function using location cache
local function transferItems(itemName, amount)
    local outputChest = peripheral.wrap(CONFIG.OUTPUT_CHEST)
    if not outputChest then return false end

    local locations = Cache.itemLocations[itemName]
    if not locations then return false end

    local remaining = amount
    for _, loc in ipairs(locations) do
        local chest = peripheral.wrap(loc.chest)
        if chest then
            local moved = chest.pushItems(CONFIG.OUTPUT_CHEST, loc.slot, remaining)
            remaining = remaining - moved
            if moved > 0 then
                -- Update cache for this chest
                updateChestCache(loc.chest, chest)
                if remaining <= 0 then
                    rebuildItemLocations()
                    return true
                end
            end
        end
    end

    rebuildItemLocations()
    return remaining <= 0
end

-- Main loop
parallel.waitForAll(
    -- Inventory refresh thread
    function()
        while true do
            local peripherals = peripheral.getNames()
            for _, name in ipairs(peripherals) do
                if peripheral.getType(name) == "minecraft:chest" then
                    local chest = peripheral.wrap(name)
                    if updateChestCache(name, chest) then
                        rebuildItemLocations()
                    end
                end
            end
            os.sleep(CONFIG.REFRESH_INTERVAL)
        end
    end,
    
    -- Request handling thread
    function()
        while true do
            local senderId, message = rednet.receive(CONFIG.REQUEST_PROTOCOL)
            if message and type(message) == "table" then
                if message.type == "list" then
                    rednet.send(senderId, {
                        type = "inventory",
                        items = getInventoryList()
                    }, CONFIG.REQUEST_PROTOCOL)
                
                elseif message.type == "request" then
                    local success = transferItems(message.item, message.amount)
                    rednet.send(senderId, {
                        type = "transfer_complete",
                        success = success
                    }, CONFIG.REQUEST_PROTOCOL)
                end
            end
        end
    end
)