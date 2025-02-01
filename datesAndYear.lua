-- Get only monitors connected to left modem
-- Get only monitors connected to left modem
-- Get only monitors connected to left modem-- Get only monitor_1 from left modem
local function getMonitors()
    return {peripheral.wrap("monitor_1")}
end
-- Speaker configuration
local SPEAKER_CONFIG = {
    SIDE = "top",
    MELODIES = {
        -- Different chimes for each hour
        hourChimes = {
            [1] = {{note = "harp", volume = 1.0, length = 0.4}},
            [2] = {{note = "basedrum", volume = 1.0, length = 0.4}},
            [3] = {{note = "snare", volume = 1.0, length = 0.4}},
            [4] = {{note = "hat", volume = 1.0, length = 0.4}},
            [5] = {{note = "bass", volume = 1.0, length = 0.4}},
            [6] = {{note = "flute", volume = 1.0, length = 0.4}},
            [7] = {{note = "bell", volume = 1.0, length = 0.4}},
            [8] = {{note = "guitar", volume = 1.0, length = 0.4}},
            [9] = {{note = "chime", volume = 1.0, length = 0.4}},
            [10] = {{note = "xylophone", volume = 1.0, length = 0.4}},
            [11] = {{note = "iron_xylophone", volume = 1.0, length = 0.4}},
            [12] = {{note = "cow_bell", volume = 1.0, length = 0.4}},
            [13] = {{note = "didgeridoo", volume = 1.0, length = 0.4}},
            [14] = {{note = "bit", volume = 1.0, length = 0.4}},
            [15] = {{note = "banjo", volume = 1.0, length = 0.4}},
            [16] = {{note = "pling", volume = 1.0, length = 0.4}}
        },
        nightTime = {
            {note = "pling", volume = 0.8, length = 0.3},
            {note = "pling", volume = 0.8, length = 0.3},
            {note = "pling", volume = 0.8, length = 0.6}
        }
    }
}

-- Function to calculate time units from days
local function getTimeUnits(days)
   local daysPerYear = 365
   local DAYS_PER_MONTH = 28
   local DAYS_PER_WEEK = 7
   
   local years = math.floor(days / daysPerYear)
   local isLeapYear = (years % 4 == 3)
   
   local remainingDays = days % daysPerYear
   local months = math.floor(remainingDays / DAYS_PER_MONTH)
   local daysIntoMonth = remainingDays % DAYS_PER_MONTH
   
   local weeks = math.floor(daysIntoMonth / DAYS_PER_WEEK)
   local dayOfWeek = daysIntoMonth % DAYS_PER_WEEK
   
   dayOfWeek = dayOfWeek >= 0 and dayOfWeek <= 6 and dayOfWeek or 0
   
   local dayNames = {
       [0] = "Day 1: Sunday",
       [1] = "Day 2: Monday",
       [2] = "Day 3: Tuesday", 
       [3] = "Day 4: Wednesday",
       [4] = "Day 5: Thursday",
       [5] = "Day 6: Friday",
       [6] = "Day 7: Sluturday"
   }
   
   return years, months, weeks, dayNames[dayOfWeek], isLeapYear, daysIntoMonth
end

-- Display time on a single monitor
local function displayTimeOnMonitor(monitor, time, ampm)
   monitor.clear()
   
   local years, months, weeks, dayName, isLeapYear, daysIntoMonth = getTimeUnits(os.day())
   
   local line = 1
   
   monitor.setCursorPos(1, line)
   monitor.write("Time: " .. (time >= 12 and (time-12 == 0 and "12" or time-12) or (time == 0 and "12" or time)) .. " " .. ampm)
   line = line + 1
   
   if years > 0 then
       monitor.setCursorPos(1, line)
       monitor.write(isLeapYear and "Leap Year: " .. years or "Year: " .. years)
       line = line + 1
   end
   
   monitor.setCursorPos(1, line)
   monitor.write(string.format("Month: %d", months))
   line = line + 1
   
   monitor.setCursorPos(1, line)
   monitor.write(string.format("Day: %d of 28", daysIntoMonth + 1))
   line = line + 1
   
   monitor.setCursorPos(1, line)
   monitor.write("Week: " .. weeks)
   line = line + 1
   
   monitor.setCursorPos(1, line)
   monitor.write(dayName)
   line = line + 1
   
   monitor.setCursorPos(1, line)
   if time >= 19 then
       monitor.write("~~~bed time~~~")
   elseif time >= 12 then
       monitor.write("~~~afternoon~~~")
   else
       monitor.write("~~~day time~~~")
   end
end

-- Function to play a melody
local function playMelody(melody)
    local speaker = peripheral.wrap(SPEAKER_CONFIG.SIDE)
    if not speaker then return end
    
    for _, note in ipairs(melody) do
        speaker.playNote(note.note, note.volume, 1)
        os.sleep(note.length)
    end
end

-- Main loop
while true do
   local monitors = getMonitors()
   
   if #monitors == 0 then
       print("No monitors found! Please connect monitors.")
       os.sleep(5)
   else
       while os.time() >= 19 do
           for _, monitor in pairs(monitors) do
               displayTimeOnMonitor(monitor, os.time(), "PM")
           end
           playMelody(SPEAKER_CONFIG.MELODIES.nightTime)
           os.sleep(1)
       end

       while os.time() <= 19 do
           local time = os.time()
           local timeA = math.floor(time)
           local ampm = time >= 12 and "PM" or "AM"
           
           for _, monitor in pairs(monitors) do
               displayTimeOnMonitor(monitor, time, ampm)
           end
           
           os.sleep()
           local timeB = math.floor(os.time())
           
           if timeB > timeA then
               if time <= 12 then
                   for i = 1, timeB do
                       playMelody(SPEAKER_CONFIG.MELODIES.hourChimes[time] or SPEAKER_CONFIG.MELODIES.hourChimes[1])
                       for _, monitor in pairs(monitors) do
                           displayTimeOnMonitor(monitor, time, "AM")
                       end
                       os.sleep(0.2)
                       for _, monitor in pairs(monitors) do
                           monitor.clear()
                       end
                       os.sleep(0.2)
                   end
               else
                   local pmHour = math.floor(time - 12)
                   for i = 1, pmHour+1 do
                       playMelody(SPEAKER_CONFIG.MELODIES.hourChimes[time] or SPEAKER_CONFIG.MELODIES.hourChimes[1])
                       for _, monitor in pairs(monitors) do
                           displayTimeOnMonitor(monitor, time, "PM")
                       end
                       os.sleep(0.2)
                       for _, monitor in pairs(monitors) do
                           monitor.clear()
                       end
                       os.sleep(0.2)
                   end
               end
           end
       end
   end
end