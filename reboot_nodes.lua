-- Find all computers on the network
local computers = {peripheral.find("computer")}

if #computers == 0 then
    print("No computers found!")
    return
end

-- List available computers
print("Available computers:")
for i, computer in ipairs(computers) do
    print(i .. ": " .. peripheral.getName(computer))
end

-- Get user selection
print("\nEnter number of computer to reboot:")
local choice = tonumber(read())

if not choice or not computers[choice] then
    print("Invalid selection!")
    return
end

-- Get the selected computer's name and wrap it
local computerName = peripheral.getName(computers[choice])
print("Rebooting " .. computerName .. "...")
local selectedComputer = peripheral.wrap(computerName)
selectedComputer.reboot()