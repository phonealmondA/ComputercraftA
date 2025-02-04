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
for z = 1,Config.hight+1 do
local a = 0
local i = 0
while i<=Config.distance do

	if a == Config.distance then
	if Config.distance%2~=0 then
	print("right")
	turtle.turnRight()
	--turtle.forward()
	else if Config.distance%2==0 then
	print("left")
	turtle.turnLeft()
	--turtle.forward()
	end
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

backingAB(z)

turtle.digDown()
turtle.down()
end
end


function backingAB(y)
if y==1 then
if Config.distance%2==0 then
print("right")
turtle.back()
--turtle.back()
turtle.turnRight()
else if Config.distance%2~=0 then
print("left")
turtle.back()
--turtle.back()
turtle.turnLeft()
end
end
else if true then
if Config.distance%2==0 then
print("right")
turtle.back()
turtle.turnRight()
else if Config.distance%2~=0 then
print("left")
turtle.back()
turtle.turnLeft()
end
end
end
end

end
level()

