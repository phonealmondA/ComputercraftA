-- chest_monitor.lua
local CONFIG = {
   MONITOR_SIDE = "monitor_2",
   REFRESH_RATE = 1  -- seconds between updates
}

-- Initialize monitor
local monitor = peripheral.wrap(CONFIG.MONITOR_SIDE)
if not monitor then
   error("No monitor found on " .. CONFIG.MONITOR_SIDE .. " side!")
end

-- Get all chests on the network
local function getNetworkChests()
   local chests = {}
   local names = peripheral.getNames()
   for _, name in ipairs(names) do
       if peripheral.getType(name) == "minecraft:chest" then
           table.insert(chests, peripheral.wrap(name))
       end
   end
   return chests
end

-- Get consolidated inventory from all chests
local function getInventory()
   local items = {}
   local index = 1
   local itemMap = {}
   local chests = getNetworkChests()
   
   for _, chest in ipairs(chests) do
       local inventory = chest.list()
       if inventory then
           for slot, item in pairs(inventory) do
               local detail = chest.getItemDetail(slot)
               if detail then
                   if not itemMap[detail.name] then
                       itemMap[detail.name] = {
                           name = detail.name,
                           displayName = detail.displayName,
                           count = 0
                       }
                   end
                   itemMap[detail.name].count = itemMap[detail.name].count + item.count
               end
           end
       end
   end
   
   for _, itemData in pairs(itemMap) do
       table.insert(items, {
           index = index,
           name = itemData.name,
           displayName = itemData.displayName,
           count = itemData.count
       })
       index = index + 1
   end
   
   -- Sort by display name while preserving original index
   table.sort(items, function(a, b) 
       return a.displayName < b.displayName 
   end)
   
   return items
end

-- Display inventory on monitor
local function displayInventory(items)
   monitor.clear()
   monitor.setCursorPos(1,1)
   monitor.setTextScale(0.5)
   
   local width, height = monitor.getSize()
   monitor.write("=== Storage System Contents ===")
   
   local columnWidth = 30  -- Adjust this number if needed
   local numColumns = math.floor(width / columnWidth)
   local rowsPerColumn = height - 3  -- Account for header and spacing
   
   for i, item in ipairs(items) do
       local column = math.floor((i-1) / rowsPerColumn)
       local row = ((i-1) % rowsPerColumn) + 3  -- Start from row 3 to account for header
       
       local x = 1 + (column * columnWidth)
       monitor.setCursorPos(x, row)
       monitor.write(string.format("%d. %s: %d", item.index, item.displayName, item.count))
   end
end

-- Main loop
while true do
   local items = getInventory()
   displayInventory(items)
   os.sleep(CONFIG.REFRESH_RATE)
end