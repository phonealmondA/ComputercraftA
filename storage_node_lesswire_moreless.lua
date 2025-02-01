-- Optimized Storage Management System
local CONFIG = {
    PROTOCOL = "item_network",
    MODEM_SIDES = {"right", "left", "top"},
    OUTPUT_CHEST = "minecraft:chest_1",
    REFRESH_RATE = 1,
    SORT_INTERVAL = 30,
    ITEMS_PER_CHEST = 27
}

-- Storage management
local Storage = {
    network = {}, -- Format: chestName = {peripheral, slots={}, isSorted=bool}
    items = {}, -- Format: itemName = {total=num, locations={{chest,slot,count}}}
    sortRules = {}, -- Format: itemType = targetChest
}

-- Initialize modems
for _, side in ipairs(CONFIG.MODEM_SIDES) do
    if peripheral.isPresent(side) then
        rednet.open(side)
    end
end

-- Core functions
local function scanNetwork()
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        if peripheral.getType(name) == "minecraft:chest" and not Storage.network[name] then
            Storage.network[name] = {
                peripheral = peripheral.wrap(name),
                slots = {},
                isSorted = false
            }
        end
    end
end

local function updateChestContents(chestName, chest)
    local inventory = chest.list()
    local changed = false
    local slots = {}

    if inventory then
        for slot, item in pairs(inventory) do
            local detail = chest.getItemDetail(slot)
            if detail then
                slots[slot] = {
                    name = detail.name,
                    count = item.count,
                    displayName = detail.displayName
                }
                changed = true
            end
        end
    end

    if changed then
        Storage.network[chestName].slots = slots
        return true
    end
    return false
end

local function rebuildItemIndex()
    Storage.items = {}
    for chestName, data in pairs(Storage.network) do
        for slot, item in pairs(data.slots) do
            if not Storage.items[item.name] then
                Storage.items[item.name] = {
                    total = 0,
                    locations = {}
                }
            end
            table.insert(Storage.items[item.name].locations, {
                chest = chestName,
                slot = slot,
                count = item.count
            })
            Storage.items[item.name].total = Storage.items[item.name].total + item.count
        end
    end
end

local function assignSortRules()
    local itemTypes = {}
    for itemName, _ in pairs(Storage.items) do
        local itemType = itemName:match("([^:]+):[^:]+$")
        if not itemTypes[itemType] then
            itemTypes[itemType] = true
        end
    end

    local chests = {}
    for name, _ in pairs(Storage.network) do
        if name ~= CONFIG.OUTPUT_CHEST then
            table.insert(chests, name)
        end
    end

    local chestIndex = 1
    for itemType, _ in pairs(itemTypes) do
        Storage.sortRules[itemType] = chests[chestIndex]
        chestIndex = (chestIndex % #chests) + 1
    end
end

local function sortItems()
    for itemName, itemData in pairs(Storage.items) do
        local itemType = itemName:match("([^:]+):[^:]+$")
        local targetChest = Storage.sortRules[itemType]
        
        if targetChest then
            for _, loc in ipairs(itemData.locations) do
                if loc.chest ~= targetChest then
                    local sourceChest = Storage.network[loc.chest].peripheral
                    local targetPeripheral = Storage.network[targetChest].peripheral
                    sourceChest.pushItems(targetChest, loc.slot)
                end
            end
        end
    end
end

local function handleRequest(senderId, message)
    if message.type == "list" then
        local inventory = {}
        for itemName, data in pairs(Storage.items) do
            table.insert(inventory, {
                name = itemName,
                count = data.total
            })
        end
        rednet.send(senderId, {type = "inventory", items = inventory}, CONFIG.PROTOCOL)
    
    elseif message.type == "request" then
        local success = false
        local itemData = Storage.items[message.item]
        
        if itemData then
            local remaining = message.amount
            for _, loc in ipairs(itemData.locations) do
                local chest = Storage.network[loc.chest].peripheral
                local moved = chest.pushItems(CONFIG.OUTPUT_CHEST, loc.slot, remaining)
                remaining = remaining - moved
                if remaining <= 0 then
                    success = true
                    break
                end
            end
        end
        
        rednet.send(senderId, {
            type = "transfer_complete",
            success = success
        }, CONFIG.PROTOCOL)
    end
end

-- Main loops
parallel.waitForAll(
    -- Network scanner
    function()
        while true do
            scanNetwork()
            os.sleep(CONFIG.REFRESH_RATE * 5)
        end
    end,

    -- Content updater
    function()
        while true do
            for name, data in pairs(Storage.network) do
                if updateChestContents(name, data.peripheral) then
                    rebuildItemIndex()
                end
            end
            os.sleep(CONFIG.REFRESH_RATE)
        end
    end,

    -- Sorter
    function()
        while true do
            assignSortRules()
            sortItems()
            os.sleep(CONFIG.SORT_INTERVAL)
        end
    end,

    -- Request handler
    function()
        while true do
            local sender, message = rednet.receive(CONFIG.PROTOCOL)
            if message and type(message) == "table" then
                handleRequest(sender, message)
            end
        end
    end
)