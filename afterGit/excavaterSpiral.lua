Config = {
    distance = nil,
    height = nil,
    fuel = turtle.getFuelLevel()
}

if not Config.distance then
    print("Please enter a distance:")
    Config.distance = tonumber(read())
end
if not Config.height then
    print("Please enter a height:")
    Config.height = tonumber(read())
end

function move()
    turtle.dig()
    turtle.forward()
end

function spiral_in()
    -- First two sides at full length
    for i = 1, Config.distance - 1 do move() end
    turtle.turnLeft()
    for i = 1, Config.distance - 1 do move() end
    turtle.turnLeft()
    
    -- Second two sides at full length
    for i = 1, Config.distance - 1 do move() end
    turtle.turnLeft()
    
    -- Start decreasing pattern
    local current_side = Config.distance - 2
    while current_side > 0 do
        -- Do two sides of same length
        for i = 1, current_side do move() end
        turtle.turnLeft()
        for i = 1, current_side do move() end
        turtle.turnLeft()
        current_side = current_side - 1
    end
    
    -- Final positioning
    turtle.turnLeft()
    turtle.turnLeft()
    turtle.digDown()
    turtle.down()
end

function spiral_out()
    local current_side = 1
    while current_side < Config.distance do
        -- Do two sides of same length
        for i = 1, current_side do move() end
        turtle.turnRight()
        for i = 1, current_side do move() end
        turtle.turnRight()
        current_side = current_side + 1
    end
    
    -- Final three sides at full length
    for i = 1, Config.distance - 1 do move() end
    turtle.turnRight()
    for i = 1, Config.distance - 1 do move() end
    turtle.turnRight()
    for i = 1, Config.distance - 1 do move() end
    
    -- Final positioning
    turtle.turnRight()
    turtle.turnRight()
    turtle.digDown()
    turtle.down()
end

function excavate_spiral()
    for level = 1, Config.height do
        if level % 2 == 1 then
            spiral_in()
        else
            spiral_out()
        end
    end
end

excavate_spiral()