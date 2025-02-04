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

function line()
    for i = 1, Config.distance - 1 do
        turtle.dig()
        turtle.forward()
    end
end

function lineA()
    line()
    turtle.turnRight()
    turtle.dig()
    turtle.forward()
    turtle.turnRight()
end

function lineB()
    line()
    turtle.turnLeft()
    turtle.dig()
    turtle.forward()
    turtle.turnLeft()
end

function backingAB(y)
    if y == 1 then
        if Config.distance % 2 == 0 then
            turtle.back()
            turtle.turnRight()
        else
            turtle.back()
            turtle.turnLeft()
        end
    else
        if Config.distance % 2 == 0 then
            turtle.back()
            turtle.turnRight()
        else
            turtle.back()
            turtle.turnLeft()
        end
    end
end

function excavate_level()
    for z = 1, Config.height + 1 do
        local a = 0
        local i = 0
        
        while i <= Config.distance do
            if a == Config.distance then
                if Config.distance % 2 ~= 0 then
                    turtle.turnRight()
                else
                    turtle.turnLeft()
                end
            else
                if a % 2 == 0 then
                    lineB()
                else
                    lineA()
                end
            end
            
            a = a + 1
            i = i + 1
        end
        
        backingAB(z)
        
        turtle.digDown()
        turtle.down()
    end
end

excavate_level()