local function wrapComputer(computerId)
    local computer = peripheral.wrap("computer_" .. computerId)
    if not computer then
        return nil, "Computer " .. computerId .. " not found or not connected"
    end
    
    return {
        isOn = function()
            return computer.isOn() -- Returns true if running
        end,
        
        getRunningPrograms = function()
            if computer.isOn() then
                return computer.list() -- Returns list of running programs
            end
            return {}
        end
    }
end

-- Example usage:
local computer1 = wrapComputer(1)
if computer1 then
    print("Computer 1 is " .. (computer1.isOn() and "on" or "off"))
    print("Running programs:")
    for _, program in ipairs(computer1.getRunningPrograms()) do
        print(program)
    end
end