Config = {
distance = nil,
hight = nil,
fuel = turtle.getFuelLevel
}

if distance == nil then
print("please enter a distance")
Config.distance = tonumber(read())
end
if distance == nil then
print("please enter a hight")
Config.hight = tonumber(read())
end

function line()
for i = 1,(Config.distance-1) do
turtle.dig()
turtle.forward()
end
end

function turnA()
turtle.turnRight()
turtle.dig()
turtle.forward()
end

function turnB()
turtle.turnLeft()
turtle.dig()
turtle.forward()
end


function lineA()
	line()
	turnA()
	turtle.turnRight()
end
function lineB()
	line()
	turnB()
	turtle.turnLeft()
end
function level()
a = 1

for z = 1,Config.hight do
i = 1
while i <= Config.distance+1 do
	if a == Config.distance+1 then
	if Config.distance%2~=0 then
	print("right")
	turtle.turnRight()
	turtle.forward()
	break
	end
	if Config.distance%2==0 then
	print("left")
	turtle.turnLeft()
	turtle.forward()
	break
	end
	else if a%2 == 0 then
	lineB()
	else if a%2 ~= 0 then
	lineA()
	end
	end
	end
	a = a+1
	i = i+1
end
	
	
if Config.distance%2==0 then
print("right")
turtle.turnRight()
end
if Config.distance%2~=0 then
print("left")
turtle.turnLeft()
end
turtle.digDown()
turtle.down()
end
end

level()

