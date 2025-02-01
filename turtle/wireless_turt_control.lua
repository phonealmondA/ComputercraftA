-- Enhanced Wireless Turtle Program with Warp Sorting
local CONFIG = {
    MODEM_SIDE = "right",
    WARP_SIDE = "left",
    PROTOCOL = "turtle_control",
    REQUEST_PROTOCOL = "item_network",
    FUEL_THRESHOLD = 100,
    MAX_HEIGHT = 20,
    MY_REQUEST_TIME = 3,
    CURRENT_STORAGE_ID = nil
}

-- Initialize peripherals
if not peripheral.isPresent(CONFIG.MODEM_SIDE) then
    error("Wireless modem not found on " .. CONFIG.MODEM_SIDE .. " side")
end
if not peripheral.isPresent(CONFIG.WARP_SIDE) then
    error("Warp Drive not found on " .. CONFIG.WARP_SIDE .. " side")
end

local warpDrive = peripheral.wrap(CONFIG.WARP_SIDE)
rednet.open(CONFIG.MODEM_SIDE)

-- Save original location
warpDrive.savePoint("start")

-- Request queue for multiple items
local requestQueue = {}

-- Safe warping function
local function safeWarp(point)
    if not point then return false end
    os.sleep(1.5)
    return warpDrive.warpToPoint(point)
end

-- Get inventory from storage computer
local function getStorageInventory(storageId)
    rednet.send(storageId, {
        type = "list"
    }, CONFIG.REQUEST_PROTOCOL)
    
    local senderId, message = rednet.receive(CONFIG.REQUEST_PROTOCOL, 5)
    if message and message.type == "inventory" then
        return message.items
    end
    return nil
end

-- Sort inventory to matching storage points

-- Sort inventory to matching storage points
local function sortInventory()
    local savedPoints = warpDrive.points()
    if #savedPoints == 0 then
        return false, "No warp points saved!"
    end

    local sorted = false
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            local itemName = item.name:lower()
            
            -- Track tried points to avoid rechecking full chests
            local triedPoints = {}
            local success = false
            
            -- First try exact matches
            for _, point in ipairs(savedPoints) do
                if point ~= "start" and itemName == point:lower() and not triedPoints[point] then
                    turtle.select(slot)
                    if safeWarp(point) then
                        if turtle.dropDown() then
                            sorted = true
                            success = true
                            break
                        else
                            -- Mark this point as tried (chest is full)
                            triedPoints[point] = true
                        end
                    end
                end
            end
            
            -- If no exact match or exact match chest was full, try partial matches
            if not success then
                for _, point in ipairs(savedPoints) do
                    if triedPoints[point] or point == "start" then
                        goto continue
                    end

                    -- Remove any prefix markers (like "z ") before checking
                    local cleanPoint = point:match("[^%s]+%s*(.+)") or point
                    cleanPoint = cleanPoint:lower()
                    
                    if itemName:find(cleanPoint) or cleanPoint:find(itemName) then
                        turtle.select(slot)
                        if safeWarp(point) then
                            if turtle.dropDown() then
                                sorted = true
                                success = true
                                break
                            else
                                -- Mark this point as tried (chest is full)
                                triedPoints[point] = true
                            end
                        end
                    end
                    
                    ::continue::
                end
            end

            -- If we couldn't store the item anywhere, we can optionally handle it here
            if not success then
                -- Could add logic to handle completely full storage
                -- For now, we'll just continue to the next item
            end
        end
    end

    if sorted then
        safeWarp("start")
        return true, "Sorting complete"
    end
    return false, "No items were sorted"
end

-- Process request queue
local function processRequestQueue(selectedPoint)
    if #requestQueue == 0 then
        return false, "No items in queue"
    end

    local itemCount = 0
    local currentItems = {}
    
    if not safeWarp(selectedPoint) then
        return false, "Failed to reach request location"
    end
    
    for i, request in ipairs(requestQueue) do
        if itemCount >= 16 then
            safeWarp("start")
            for slot = 1, 16 do
                turtle.select(slot)
                turtle.dropDown()
            end
            itemCount = 0
            currentItems = {}
            if not safeWarp(selectedPoint) then
                return false, "Failed to return to request location"
            end
        end

        rednet.send(CONFIG.CURRENT_STORAGE_ID, {
            type = "request",
            item = request.name,
            amount = request.amount
        }, CONFIG.REQUEST_PROTOCOL)
        
        local senderId, message = rednet.receive(CONFIG.REQUEST_PROTOCOL, 5)
        if message and message.type == "transfer_complete" then
            os.sleep(0.5)
            
            for slot = 1, 16 do
                turtle.select(slot)
                if turtle.getItemCount(slot) == 0 then
                    if turtle.suckDown() then
                        itemCount = itemCount + 1
                        table.insert(currentItems, request)
                        break
                    end
                end
            end
        end
        
        os.sleep(CONFIG.MY_REQUEST_TIME)
    end
    
    if itemCount > 0 then
        safeWarp("start")
        --for slot = 1, 16 do
        --    turtle.select(slot)
        --    turtle.dropDown()
        --end
    end
    
    requestQueue = {}
    return true, "All requests processed"
end

-- Command handlers
local commands = {
    -- Movement commands
    move_forward = function() return {success = turtle.forward()} end,
    move_back = function() return {success = turtle.back()} end,
    turn_left = function() return {success = turtle.turnLeft()} end,
    turn_right = function() return {success = turtle.turnRight()} end,
    move_up = function() return {success = turtle.up()} end,
    move_down = function() return {success = turtle.down()} end,
    dig = function() return {success = turtle.dig()} end,
    
    -- Warp point commands
    get_points = function()
        return {success = true, points = warpDrive.points()}
    end,
    
    setup_point = function(name)
        if warpDrive.savePoint(name) then
            return {success = true, message = "Saved point: " .. name}
        end
        return {success = false, message = "Failed to save point"}
    end,
    
    delete_point = function(point)
        if point == "start" then
            return {success = false, message = "Cannot delete start point"}
        end
        if warpDrive.deletePoint(point) then
            return {success = true, message = "Deleted point: " .. point}
        end
        return {success = false, message = "Failed to delete point"}
    end,
    
    -- Inventory and request commands
    sort_inventory = function()
        local success, message = sortInventory()
        return {success = success, message = message}
    end,
    
    get_storage_inventory = function(data)
        safeWarp(data.point)
        local items = getStorageInventory(data.storageId)
        safeWarp("start")
        return {success = items ~= nil, items = items}
    end,
    
    set_requests = function(data)
        requestQueue = data.requests
        CONFIG.CURRENT_STORAGE_ID = data.storageId
        return {success = true, message = "Requests queued"}
    end,
    
    view_queue = function()
        return {success = true, queue = requestQueue}
    end,
    
    process_queue = function(point)
        local success, message = processRequestQueue(point)
        return {success = success, message = message}
    end,
    
    clear_queue = function()
        requestQueue = {}
        return {success = true, message = "Queue cleared"}
    end,

    list_points = function()
        local points = warpDrive.points()
        return {
            success = true,
            points = points,
            message = #points > 0 and "Points retrieved" or "No points saved"
        }
    end
}

-- Main loop
print("Turtle ID: " .. os.getComputerID())
print("Accepting commands...")

while true do
    local sender, message = rednet.receive(CONFIG.PROTOCOL)
    warpDrive.savePoint("start")
    if type(message) == "table" and message.type then
        local handler = commands[message.type]
        if handler then
            local response = handler(message.data)
            rednet.send(sender, response, CONFIG.PROTOCOL)
        else
            rednet.send(sender, {
                success = false,
                message = "Unknown command: " .. message.type
            }, CONFIG.PROTOCOL)
        end
    end
end