
-- Get all connected monitors
local function getMonitors()
    local monitors = {}
    local names = peripheral.getNames()
    for _, name in pairs(names) do
        if peripheral.getType(name) == "monitor" then
            monitors[#monitors + 1] = peripheral.wrap(name)
        end
    end
    return monitors
end

-- Display time on a single monitor
local function displayTimeOnMonitor(monitor, time, ampm)
    monitor.clear()
    monitor.setCursorPos(1,1)
    
    if time >= 12 then
		monitor.setCursorPos(1,1)
        monitor.write("Time: " .. (time-12 == 0 and "12" or time-12) .. " " .. ampm)
        monitor.setCursorPos(1,2)
        monitor.write("it is the ")
        monitor.setCursorPos(1,3)
        monitor.write(os.day().."th day")
        monitor.setCursorPos(1,4)
        monitor.write("of the server")
		monitor.setCursorPos(1,5)
		monitor.write("~~~afterNoon~~~")
        
    else 
		monitor.setCursorPos(1,1)
        monitor.write("Time: " .. (time == 0 and "12" or time) .. " " .. ampm)
        monitor.setCursorPos(1,2)
        monitor.write("it is the ")
        monitor.setCursorPos(1,3)
        monitor.write(os.day().."th day")
        monitor.setCursorPos(1,4)
        monitor.write("of the server")
		monitor.setCursorPos(1,5)
		monitor.write("~~~day time~~~")
        
    end
end

-- Main loop
while true do
    local monitors = getMonitors()
    
    -- Check if any monitors were found
    if #monitors == 0 then
        print("No monitors found! Please connect monitors.")
        os.sleep(5)
    else
        while os.time() >= 19 do
            for _, monitor in pairs(monitors) do
                monitor.clear()
                monitor.setCursorPos(1,1)
                monitor.write(os.time())
			monitor.setCursorPos(1,2)
			monitor.write("it is the ")
			monitor.setCursorPos(1,3)
			monitor.write(os.day().."th day")
			monitor.setCursorPos(1,4)
			monitor.write("of the server")
			monitor.setCursorPos(1,5)
			monitor.write("~~~bed time~~~")
				
            end
            redstone.setAnalogOutput("right", 15)
            os.sleep(0.5)
            redstone.setAnalogOutput("right", 0)
            os.sleep(0.5)
        end

        while os.time() <= 19 do
            local time = os.time()
            local timeA = math.floor(time)
            local ampm = time >= 12 and "PM" or "AM"
            
            -- Update all monitors
            for _, monitor in pairs(monitors) do
                displayTimeOnMonitor(monitor, time, ampm)
            end
            
            os.sleep()
            local timeB = math.floor(os.time())
            
            if timeB > timeA then
                if time <= 12 then
                    for i = 1, timeB do
                        redstone.setAnalogOutput("right",15)
                        -- Update all monitors during chimes
                        for _, monitor in pairs(monitors) do
                            displayTimeOnMonitor(monitor, time, "AM")
                        end
                        
                        os.sleep(0.2)
                        redstone.setAnalogOutput("right",0)
                        
                        -- Clear all monitors
                        for _, monitor in pairs(monitors) do
                            monitor.clear()
                            monitor.setCursorPos(1,1)
                        end
                        
                        os.sleep(0.2)
                    end
                elseif time >= 12 then
                    local pmHour = math.floor(time - 12)
                    
                    for i = 1, pmHour+1 do
                        redstone.setAnalogOutput("right",15)
                        -- Update all monitors during chimes
                        for _, monitor in pairs(monitors) do
                            displayTimeOnMonitor(monitor, time, "PM")
                        end
                        
                        os.sleep(0.2)
                        redstone.setAnalogOutput("right",0)
                        
                        -- Clear all monitors
                        for _, monitor in pairs(monitors) do
                            monitor.clear()
                            monitor.setCursorPos(1,1)
                        end
                        
                        os.sleep(0.2)
                    end
                end
            end
        end
    end
end