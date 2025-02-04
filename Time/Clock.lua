while true do
while os.time() >= 19 do
    redstone.setAnalogOutput("left", 15)
    print(os.time())
    os.sleep(0.5)
    redstone.setAnalogOutput("left", 0)
    os.sleep(0.5)
    term.clear()
    term.setCursorPos(1,1)
end

while os.time() <= 19 do
term.clear()
term.setCursorPos(1,1)
    time = os.time()
    local timeA = math.floor(time)
    -- Add AM/PM to the display
    local ampm = time >= 12 and "PM" or "AM"
	-- Replace the two if clauses with:
if time >= 12 then
    print("time: ", time-12 == 0 and "12" or time-12 .. " " .. ampm)
else 
    print("time: ", time == 0 and "12" or time .. " " .. ampm)
end
	
    os.sleep()
    local timeB = math.floor(os.time())
    
    if timeB > timeA then
        if time <= 12 then
            print(time .. " AM")
            for i = 1, timeA do
                print(i)
                redstone.setAnalogOutput("left",15)
                print(time .. " AM")
                
                os.sleep(0.2)
                
                redstone.setAnalogOutput("left",0)
                term.clear()
                term.setCursorPos(1,1)
                
                os.sleep(0.2)
            end
        else if time >= 12 then
            local pmHour = math.floor(time - 12)
            print(time .. " PM")
            
            for i = 1, pmHour do
                print(i)
                redstone.setAnalogOutput("left",15)
                print(time .. " PM")
                
                os.sleep(0.2)
                
                redstone.setAnalogOutput("left",0)
                term.clear()
                term.setCursorPos(1,1)
                
                os.sleep(0.2)
            end
        end
        end
    end
end

term.clear()
term.setCursorPos(1,1)

end