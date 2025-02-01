-- Simplified Item Requester
local CONFIG = {
    PROTOCOL = "item_network",
    STORAGE_ID = nil,
    DEST_CHEST = "minecraft:chest_1",
    PAGE_SIZE = 10
}

-- Initialize network
if not peripheral.find("modem") then error("No modem found!") end
rednet.open(peripheral.getName(peripheral.find("modem")))

-- Get storage ID if not set
if not CONFIG.STORAGE_ID then
    print("Storage computer ID:")
    CONFIG.STORAGE_ID = tonumber(read())
end

-- Core functions
local function getInventory()
    rednet.send(CONFIG.STORAGE_ID, {type = "list"}, CONFIG.PROTOCOL)
    local _, msg = rednet.receive(CONFIG.PROTOCOL, 5)
    return msg and msg.type == "inventory" and msg.items
end

local function requestItem(name, amount)
    rednet.send(CONFIG.STORAGE_ID, {
        type = "request",
        item = name,
        amount = amount
    }, CONFIG.PROTOCOL)
    
    local _, msg = rednet.receive(CONFIG.PROTOCOL, 5)
    return msg and msg.type == "transfer_complete" and msg.success
end

local function displayItems(items, page)
    term.clear()
    print("=== Items (Page " .. page .. ") ===")
    local start = (page - 1) * CONFIG.PAGE_SIZE + 1
    local finish = math.min(start + CONFIG.PAGE_SIZE - 1, #items)
    
    for i = start, finish do
        print(string.format("%d. %s (%d)", i, items[i].name, items[i].count))
    end
    
    print("\nN:Next P:Prev R:Request Q:Quit")
end

-- Main loop
while true do
    local items = getInventory()
    if not items then
        print("Failed to get inventory")
        os.sleep(2)
        return
    end

    local page = 1
    local maxPages = math.ceil(#items / CONFIG.PAGE_SIZE)

    while true do
        displayItems(items, page)
        local _, key = os.pullEvent("char")
        
        if key == "n" and page < maxPages then
            page = page + 1
        elseif key == "p" and page > 1 then
            page = page - 1
        elseif key == "r" then
            print("\nItem number:")
            local num = tonumber(read())
            if num and items[num] then
                print("Amount (max " .. items[num].count .. "):")
                local amt = tonumber(read())
                if amt and amt > 0 and amt <= items[num].count then
                    print("Requesting items...")
                    if requestItem(items[num].name, amt) then
                        print("Success!")
                    else
                        print("Failed")
                    end
                    os.sleep(1)
                end
            end
            break
        elseif key == "q" then
            return
        end
    end
end