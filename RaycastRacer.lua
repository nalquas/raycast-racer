-- title:  Raycast Racer
-- author: Nalquas
-- desc:   A raycasting-based racing game
-- script: lua
-- input:  gamepad
-- saveid: raycastracer



-- ============LICENSE=============
-- Raycast Racer - A raycasting-based racing game
-- Copyright (C) 2018-2019  Niklas 'Nalquas' Freund
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
-- =========END OF LICENSE=========






-- ===================================================================================================================================
-- INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO INFO
-- ===================================================================================================================================
-- Controls:
--	Up    Forward
--	Down  Backward
--	Left  TurnLeft
--	Right TurnRight
--	A (Z) Forward (Alternative)
--	B (X) Backward (Alternative)
--	X (A) UNASSIGNED
--	Y (S) UNASSIGNED

-- Sides:
-- +1+
-- 4+2
-- +3+

-- Corners:
-- 1-2
-- |-|
-- 4-3

-- Rotation:
--	---270---
--  180   000
--  ---090---

-- 1UPS=0.016666s (~Length of a frame at exactly 60fps)

-- PMEM-Layout:
-- 000 Track-0 best time
-- 001 Track-1 best time
-- UNASSIGNED
-- 010 lineSkipFactor
-- 011 distance
-- 012 baseFOV
-- 013 fisheyeCompensation
-- 014 heightFactor
-- 015 initialHitStepSize
-- 016 betterSky
-- 017 showProps
-- 018 showFPS
-- UNASSIGNED
-- 255 saveVersion


versionNr="1.1.0"
releaseDate="19.05.2019"
savefileVersion=2

-- ===================================================================================================================================
-- VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES VARIABLES
-- ===================================================================================================================================
--Options (Should be available in a menu in a proper game):
baseFOV=65 --Field of view
heightFactor=20 --Factor that influences the size of everything
distance=500 --View distance
overhead=false --Bird's-eye view?
doSound=false --Sound?
fisheyeCompensation=1.16 --Originally 1.4, but people say that's still fisheye. 1.16 seems to be stable.
initialHitStepSize=8 --Size of the steps used to detect blocks during raycasting. Low values lead to very accurate projection at low performance, high values lead to very unconsistent projection at excellent performance.
betterSky=true --Apply sky gradient?
gifRecorderMode=false
doCorrectFPS=false
renderCockpit=true
indexesBiggerThan=15
indexesSmallerThan=24
wayIndexesBiggerThan=143
wayIndexesSmallerThan=188
spriteCentering=false
classicRender=false --Render every pixel in a texture as a seperate line or every line in a texture as a textri?
--showDebug=false
showFPS=true
showProps=true
lineSkipFactor=1 --Every xth line will be rendered
lineSkipFighter=false --Correct for skipped lines (double or triple line width etc.)
collisionSoftness=0.997
waypointRadius=64
numberOfCars=8 --Number of cars (including player, minimum of 1; Crashes at 32 (out of memory))
numberOfLapsToComplete=5 --Number of laps to complete. Current lap is displayed, not how many you've done.
soundThreshold=0.02857 --If tDiff gets larger than this, sound is disabled

fpsFactor=1
fov=baseFOV
currentTrack=0
state=0
menuState=1
menuSubState=1
currentMaxSubState=4
loadingSuccessful=false
didReset=false
doResetConfirm=false

-- Memory of last actions performed, and when (For making gameplay fps-independent)
last={t=time(),btn={}}
for i=0,7 do last.btn[i]=false end
now=last

t=0
wheelT=0
--player={}

--Spawn cars, including player
cars={}
player={raceStart=0,raceFinish=2147483647}
finished={}
spriteList={}
waypoints={}
track={}
track[0]={mapX=0,mapY=0,width=131,height=135,baseX=248,baseY=32,maxWaypoint=43,bestTime=2147483647}
track[1]={mapX=132,mapY=0,width=107,height=135,baseX=1304,baseY=32,maxWaypoint=42,bestTime=2147483647}

gameover=false
gameoverState=0
newPersonalBest=false

-- Message in Console:
trace("\n\n-----------------------------\n      Nalquas presents:\n     Raycast Racer V"..versionNr.."\n Version released: "..releaseDate.."\nhttps://nalquas.itch.io/raycast-racer\n-----------------------------\n")

--testNumber=1337
--trace(testNumber)

--[[function traceData()
	for i=0,255 do
		if not (pmem(i)==0) then
			trace(i.." "..pmem(i))
		end
	end
end--]]

-- ===================================================================================================================================
-- FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS FUNCTIONS
-- ===================================================================================================================================
-- FPS function:
local FPS={value =0,frames =0,lastTime=-1000}
function FPS:getValue()
  if (time()-self.lastTime <= 1000) then
    self.frames=self.frames+1
  else
    self.value=self.frames
    self.frames=0
    self.lastTime=time()
  end
  return self.value
end

-- Load palette string
function loadPalette(pal)
	for i=0,15 do
	 r=tonumber(string.sub(pal,i*6+1,i*6+2),16)
	 g=tonumber(string.sub(pal,i*6+3,i*6+4),16)
	 b=tonumber(string.sub(pal,i*6+5,i*6+6),16)
	 poke(0x3FC0+(i*3)+0,r)
	 poke(0x3FC0+(i*3)+1,g)
	 poke(0x3FC0+(i*3)+2,b)
	end
end

-- set spritesheet pixel
function sset(x,y,c)
    local addr=0x4000+(x//8+y//8*16)*32 -- get sprite address
    poke4(addr*2+x%8+y%8*8,c) -- set sprite pixel
end

-- get spritesheet pixel
function sget(x,y)
    local addr=0x4000+(x//8+y//8*16)*32 -- get sprite address
    return peek4(addr*2+x%8+y%8*8) -- get sprite pixel
end

-- Set background color
function background(bgrValue)
	poke(0x03FF8, bgrValue) -- Set Background
end

function printCenter(text,x,y,color,fixed,smallfont)
	scale=1
	width=print(text,0,-12,15,fixed,1,smallfont)
	print(text,(((x*2)-width)//2)+1,y,color,fixed,scale,smallfont)
end

-- Round stuff
function round(x)
	if x<0 then return math.ceil(x-0.5) end
	return math.floor(x+0.5)
end

-- Generates all the parameters used in lineMemory
function generateLine(x1,y1,x2,y2,c,distance)
	return {x1=x1,y1=y1,x2=x2,y2=y2,c=c,distance=distance}
end

function scaledSpr(id,x,y,x2,y2,colorKey,width,height)
	-- A B
	--
	-- D C
	-- ax ay bx by cx cy au av bu bv cu cv

	ax=x
	ay=y

	bx=x2
	by=y

	cx=x2
	cy=y2

	dx=x
	dy=y2

	uFactor=((id%16)*8)
	vFactor=math.floor(id/16)*8

	au=uFactor
	av=vFactor

	bu=uFactor+width
	bv=vFactor

	cu=uFactor+width
	cv=vFactor+height

	du=uFactor
	dv=vFactor+height

	textri(ax,ay,bx,by,cx,cy,au,av,bu,bv,cu,cv,false,colorKey)
	textri(ax,ay,dx,dy,cx,cy,au,av,du,dv,cu,cv,false,colorKey)
end

function minimap(x,y,mapX,mapY,width,height,sizeReduce)
	for i=0,width,sizeReduce do
		for j=0,height,sizeReduce do
			if not (mget(mapX+i,mapY+j)==0 or mget(mapX+i,mapY+j)>indexesBiggerThan and mget(mapX+i,mapY+j)<indexesSmallerThan) then
				pix(x+(i/sizeReduce),y+(j/sizeReduce),15)
			end
		end
	end
	--pix(((player.x/8)/sizeReduce)+x,((player.y/8)/sizeReduce)+y,6)
	for i=#cars,1,-1 do
		if i==1 then
			c=6
		else
			c=13
		end
		circ((((cars[i].x/8)-mapX)/sizeReduce)+x,(((cars[i].y/8)-mapY)/sizeReduce)+y,1,c)
	end
end

--Save data
function makeSave()
	for i=0,255 do pmem(i,0) end --Wipe data
	pmem(0,track[0].bestTime)
	pmem(1,track[1].bestTime)
	pmem(10,lineSkipFactor)
	pmem(11,distance)
	pmem(12,baseFOV)
	pmem(13,round(fisheyeCompensation*100.0))
	pmem(14,heightFactor)
	pmem(15,initialHitStepSize)
	if betterSky then pmem(16,1) end
	if showProps then pmem(17,1) end
	if showFPS then pmem(18,1) end
	pmem(255,savefileVersion)
end
--makeSave()
--traceData()

--Reset settings to default
function resetSettings()
	baseFOV=65 --Field of view
	heightFactor=20 --Factor that influences the size of everything
	distance=500 --View distance
	overhead=false --Bird's-eye view?
	doSound=false --Sound?
	fisheyeCompensation=1.16 --Originally 1.4, but people say that's still fisheye. 1.16 seems to be stable.
	initialHitStepSize=8 --Size of the steps used to detect blocks during raycasting. Low values lead to very accurate projection at low performance, high values lead to very unconsistent projection at excellent performance.
	betterSky=true --Apply sky gradient?
	gifRecorderMode=false
	doCorrectFPS=false
	renderCockpit=true
	indexesBiggerThan=15
	indexesSmallerThan=24
	wayIndexesBiggerThan=143
	wayIndexesSmallerThan=188
	spriteCentering=false
	--showDebug=false
	showFPS=true
	showProps=true
	lineSkipFactor=1 --Every xth line will be rendered
	lineSkipFighter=false --Correct for skipped lines (double or triple line width etc.)
	collisionSoftness=0.997
	waypointRadius=64
	numberOfCars=8 --Number of cars (including player, minimum of 1; Crashes at 32 (out of memory))
	numberOfLapsToComplete=5 --Number of laps to complete. Current lap is displayed, not how many you've done.
	soundThreshold=0.02857 --If tDiff gets larger than this, sound is disabled

	fpsFactor=1
	fov=baseFOV
	currentTrack=0
	state=0
	menuState=1
	menuSubState=1
	currentMaxSubState=4
	loadingSuccessful=false
	makeSave()
end

-- Load from pmem()
if pmem(255)>0 then
	--Load saved data
	track[0].bestTime=pmem(0)
	track[1].bestTime=pmem(1)
	if pmem(255)==1 then
		--Values higher than 4 tend to crash in this version (engine is reaching memory limits...)
		if pmem(10)>4 then
			lineSkipFactor=4
		end
	else
		lineSkipFactor=pmem(10)
	end
	distance=pmem(11)
	baseFOV=pmem(12)
	if pmem(255)==1 then
		--Could go too low in V1.0, have to fix here
		fisheyeCompensation=1.16
	else
		fisheyeCompensation=pmem(13)/100.0
	end
	heightFactor=pmem(14)
	initialHitStepSize=pmem(15)
	if pmem(16)==1 then betterSky=true else betterSky=false end
	if pmem(17)==1 then showProps=true else showProps=false end
	if pmem(18)==1 then showFPS=true else showFPS=false end
	loadingSuccessful=true
else
	--Format save file
	makeSave()
end

-- ===================================================================================================================================
-- INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT INIT
-- ===================================================================================================================================
--if musicTest then music(7,-1,-1,true) end

-- Automatic sprite placement (based on map)
-- WARNING: Game fails to load when no sprites exist due to index errors!
function autoSprite()
	for xI=track[currentTrack].mapX,track[currentTrack].mapX+track[currentTrack].width do
		for yI=track[currentTrack].mapY,track[currentTrack].mapY+track[currentTrack].height do
			thisI=mget(xI,yI)
			if spriteCentering then
				x=xI+4 --center in block
				y=yI+4 --center in block
			else
				x=xI
				y=yI
			end

			if thisI>=indexesSmallerThan and (thisI>=wayIndexesSmallerThan or thisI<=wayIndexesBiggerThan) then
				if showProps then --Actually show everything
					if thisI==51 then --Finish line
						spriteList[#spriteList+1]={created=false,index=50,ck=0,w3D=4,h3D=3.5,x=x*8,y=y*8,sizeX=9,sizeY=3,firstScreenX=0,lastScreenX=0,firstScreenHeight=0,lastScreenHeight=0,distance=0}
					elseif thisI==39 then --Cone
						spriteList[#spriteList+1]={created=false,index=39,ck=4,w3D=0.325,h3D=0.75,x=x*8,y=y*8,sizeX=1,sizeY=1,firstScreenX=0,lastScreenX=0,firstScreenHeight=0,lastScreenHeight=0,distance=0}
					elseif thisI==24 then --Turn right
						spriteList[#spriteList+1]={created=false,index=24,ck=0,w3D=0.75,h3D=1.75,x=x*8,y=y*8,sizeX=1,sizeY=2,firstScreenX=0,lastScreenX=0,firstScreenHeight=0,lastScreenHeight=0,distance=0}
					else --Unknown
						spriteList[#spriteList+1]={created=false,index=thisI,ck=0,w3D=1,h3D=1,x=x*8,y=y*8,sizeX=1,sizeY=1,firstScreenX=0,lastScreenX=0,firstScreenHeight=0,lastScreenHeight=0,distance=0}
					end
				elseif thisI==51 then --Finish line is important
					spriteList[#spriteList+1]={created=false,index=50,ck=0,w3D=4,h3D=3.5,x=x*8,y=y*8,sizeX=9,sizeY=3,firstScreenX=0,lastScreenX=0,firstScreenHeight=0,lastScreenHeight=0,distance=0}
				end
			end
		end
	end
end
autoSprite()

--Automatic waypoint discovery (based on map)
function autoWaypoint()
	for xI=track[currentTrack].mapX,track[currentTrack].mapX+track[currentTrack].width do
		for yI=track[currentTrack].mapY,track[currentTrack].mapY+track[currentTrack].height do
			thisI=mget(xI,yI)

			if thisI<wayIndexesSmallerThan and thisI>wayIndexesBiggerThan then
				waypoints[thisI-wayIndexesBiggerThan]={track=0,x=xI*8,y=yI*8}
			end
		end
	end
end
autoWaypoint()

--Automatic sprite spawning for cars
function autoCarSprite()
	if #cars>1 then
		for i=2,#cars do
			spriteList[#spriteList+1]={created=false,index=91,ck=5,w3D=1.0,h3D=1.7,x=cars[i].x,y=cars[i].y,sizeX=2,sizeY=2,firstScreenX=0,lastScreenX=0,firstScreenHeight=0,lastScreenHeight=0,distance=0}
			cars[i].spriteListI=#spriteList
		end
	end
end
autoCarSprite()

function reset()
	last={t=time(),btn={}}
	for i=0,7 do last.btn[i]=false end
	now=last
	gameover=false
	gameoverState=0
	newPersonalBest=false
	t=0
	wheelT=0
	background(0)
	player={raceStart=time(),raceFinish=2147483647}
	cars={}
	finished={}
	spriteList={}
	waypoints={}
	for i=1,numberOfCars do
		if i==1 then
			newX=track[currentTrack].baseX
			newY=track[currentTrack].baseY
		elseif i==2 then
			newX=track[currentTrack].baseX
			newY=track[currentTrack].baseY+48
		elseif i==3 then
			newX=track[currentTrack].baseX+48
			newY=track[currentTrack].baseY
		else
			newX=track[currentTrack].baseX+48
			newY=track[currentTrack].baseY+48
		end
		
		--acceleration=0.05+((i-1)*(0.032/numberOfCars))
		trackFactor=1.0
		if currentTrack==0 then
			trackFactor=1.2
		end
		cars[i]={input={},x=newX,y=newY,rot=0,prevX=newX,prevY=newY,prevRot=0,acceleration=0.05+((i-1)*((0.006*trackFactor)/numberOfCars)),steeringInaccuracy=(i-1)*(5/numberOfCars),steeringForce=0.155+((i-1)*(0.08/numberOfCars)),spriteListI=0,speed=0,rotSpeed=0,braking=false,lap=0,zone=4,waypoint=0,lastZone=4,place=1,lastLapCross=time(),lapBest=2147483647}
	end
	spriteList[1]={created=false,index=50,ck=0,w3D=4,h3D=3.5,x=-5,y=-5,sizeX=9,sizeY=3,firstScreenX=0,lastScreenX=0,firstScreenHeight=0,lastScreenHeight=0,distance=0} --dummy
	autoSprite()
	autoWaypoint()
	autoCarSprite()
end
reset()

-- Change palette entry 14 each line to have a good sky gradient
function scanline(row)
	if state==0 then
		--poke(0x3fea,128) --r
		--poke(0x3feb,72) --g
		--poke(0x3fec,(math.sin((row+t)/20)+1)*127.5) --b
		poke(0x3fea,(math.sin((row+t)/20)+1)*63.75) --r
		poke(0x3feb,16) --g
		poke(0x3fec,16) --b
	elseif state==1 then
		if betterSky then

			--Possible colors: (B is always X-row*3)
			--  R   G   B
			-- 000-000-255 Pure blue (looks artificial)
			-- 096-064-255 Sundown, early
			-- 128-064-255 Sundown, mid
			-- 128-096-255 Morning

			-- skygradient (palette position 14)
			poke(0x3fea,128) --r
			poke(0x3feb,64) --g
			poke(0x3fec,255-row*3) --b
		end
	end
end

function TIC()
	if state==0 then
	-- ===================================================================================================================================
	-- MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU MENU
	-- ===================================================================================================================================
		--menuSubState control
		if btnp(0,30,10) then
			--Up
			menuSubState=menuSubState-1
		elseif btnp(1,30,10) then
			--Down
			menuSubState=menuSubState+1
		end
		--menuSubState loop
		if menuSubState<1 then
			menuSubState=currentMaxSubState
		elseif menuSubState>currentMaxSubState then
			menuSubState=1
		end
		
		--General Render
		cls(14)
		background(14)
		
		--Menu Logic and Specific Render
		cList={}
		if menuState==1 then
			--Main Main Menu
			currentMaxSubState=7
			resetMessage=""
			if didReset then
				resetMessage=" (DONE)"
			elseif doResetConfirm then
				resetMessage=" (ARE YOU SURE? PRESS AGAIN)"
			end
			
			--Control
			if menuSubState==1 and btnp(4,30,10) then
				state=1
				reset()
				makeSave()
			elseif menuSubState==2 and btnp(4,30,10) then
				menuState=2
				menuSubState=1
				makeSave()
			elseif menuSubState==3 then
				--Track
				if btnp(2,30,10) or btnp(3,30,10) then
					if currentTrack==0 then
						currentTrack=1
					else
						currentTrack=0
					end
					reset()
					didReset=false
					doResetConfirm=false
				end
			elseif menuSubState==4 then
				--Cars
				if btnp(2,30,10) then
					if numberOfCars>1 then
						numberOfCars=numberOfCars-1
					end
					reset()
					didReset=false
					doResetConfirm=false
				elseif btnp(3,30,10) then
					if numberOfCars<8 then
						numberOfCars=numberOfCars+1
					end
					reset()
					didReset=false
					doResetConfirm=false
				end
			elseif menuSubState==5 then
				--Laps
				if btnp(2,30,10) then
					if numberOfLapsToComplete>1 then
						numberOfLapsToComplete=numberOfLapsToComplete-1
					end
					reset()
					didReset=false
					doResetConfirm=false
				elseif btnp(3,30,10) then
					numberOfLapsToComplete=numberOfLapsToComplete+1
					reset()
					didReset=false
					doResetConfirm=false
				end
			elseif menuSubState==6 and btnp(4,30,10) then
				if (not didReset) and doResetConfirm then
					resetSettings()
					reset()
					didReset=true
				else
					doResetConfirm=true
				end
			elseif menuSubState==7 and btnp(4,30,10) then
				makeSave()
				exit()
			end
			
			print("RaycastRacer",45,16,15,true,3,true)
			printCenter("(C) Nalquas, 2018-2019",119,119,15,true,true)
			printCenter("GNU General Public License Version 3",119,127,15,true,true)
			
			for i=1,7 do
				if (i==menuSubState) and (math.floor(t/10)%2==0) then
					cList[i]=6
				else
					cList[i]=15
				end
			end
			highscoreNote=""
			if not (numberOfLapsToComplete==5) then highscoreNote=" (NO HIGHSCORE TRACKING)" end
			printCenter("Play with current settings",119,48,cList[1],true,true)
			printCenter("Custom Graphical Settings",119,56,cList[2],true,true)
			printCenter("< Track "..currentTrack.." >",119,64,cList[3],true,true)
			printCenter("< Number of Cars "..numberOfCars.." >",119,72,cList[4],true,true)
			printCenter("< Number of Laps "..numberOfLapsToComplete..highscoreNote.." >",119,80,cList[5],true,true)
			printCenter("RESET SETTINGS"..resetMessage,119,88,cList[6],true,true)
			printCenter("Exit to TIC-80",119,96,cList[7],true,true)
			
			--Show selected map on the left
			minimap(2,83,track[currentTrack].mapX,track[currentTrack].mapY,track[currentTrack].width,track[currentTrack].height,3)
			
			
		elseif menuState==2 then
			--Graphical Settings
			currentMaxSubState=10
			
			print("RaycastRacer",45,16,15,true,3,true)
			printCenter("(C) Nalquas, 2018-2019",119,119,15,true,true)
			printCenter("GNU General Public License Version 3",119,127,15,true,true)
			
			for i=1,10 do
				if (i==menuSubState) and (math.floor(t/10)%2==0) then
					cList[i]=6
				else
					cList[i]=15
				end
			end
			printCenter("< Scan Resolution ".. math.floor(100/lineSkipFactor) .."% >",119,40,cList[1],true,true)
			printCenter("< View Distance "..distance.." >",119,48,cList[2],true,true)
			printCenter("< FOV "..baseFOV.." >",119,56,cList[3],true,true)
			printCenter("< fisheyeCompensation "..fisheyeCompensation.." >",119,64,cList[4],true,true)
			printCenter("< heightFactor "..heightFactor.." >",119,72,cList[5],true,true)
			printCenter("< Raycast Inaccuracy "..initialHitStepSize.." >",119,80,cList[6],true,true)
			printCenter("< Sky Gradient "..tostring(betterSky).." >",119,88,cList[7],true,true)
			printCenter("< Show Props "..tostring(showProps).." >",119,96,cList[8],true,true)
			printCenter("< Show FPS "..tostring(showFPS).." >",119,104,cList[9],true,true)
			printCenter("Return",119,112,cList[10],true,true)
			
			--Control
			if menuSubState==1 then
				--Resolution
				if btnp(2,30,10) then
					if lineSkipFactor>1 then
						lineSkipFactor=lineSkipFactor-1
					end
				elseif btnp(3,30,10) then
					if lineSkipFactor<4 then
						lineSkipFactor=lineSkipFactor+1
					end
				end
			elseif menuSubState==2 then
				--View Distance
				if btnp(2,30,10) then
					if distance>50 then
						distance=distance-10
					end
				elseif btnp(3,30,10) then
					distance=distance+10
				end
			elseif menuSubState==3 then
				--FOV
				if btnp(2,30,10) then
					if baseFOV>1 then
						baseFOV=baseFOV-1
					end
				elseif btnp(3,30,10) then
					if baseFOV<175 then
						baseFOV=baseFOV+1
					end
				end
			elseif menuSubState==4 then
				--Fisheye compensation
				if btnp(2,30,10) then
					if fisheyeCompensation>1.0 then
						fisheyeCompensation=fisheyeCompensation-0.01
					end
					fisheyeCompensation=round(fisheyeCompensation*100.0)/100.0
				elseif btnp(3,30,10) then
					fisheyeCompensation=fisheyeCompensation+0.01
					fisheyeCompensation=round(fisheyeCompensation*100.0)/100.0
				end
			elseif menuSubState==5 then
				--heightFactor
				if btnp(2,30,10) then
					if heightFactor>1 then
						heightFactor=heightFactor-1
					end
				elseif btnp(3,30,10) then
					heightFactor=heightFactor+1
				end
			elseif menuSubState==6 then
				--initialHitStepSize
				if btnp(2,30,10) then
					if initialHitStepSize>1 then
						initialHitStepSize=initialHitStepSize-1
					end
				elseif btnp(3,30,10) then
					initialHitStepSize=initialHitStepSize+1
				end
			elseif menuSubState==7 then
				--Sky Gradient
				if btnp(2,30,10) or btnp(3,30,10) then
					betterSky=not betterSky
				end
			elseif menuSubState==8 then
				--showProps
				if btnp(2,30,10) or btnp(3,30,10) then
					showProps=not showProps
				end
			elseif menuSubState==9 then
				--showFPS
				if btnp(2,30,10) or btnp(3,30,10) then
					showFPS=not showFPS
				end
			elseif menuSubState==10 and btnp(4,30,10) then
				menuState=1
				menuSubState=1
				makeSave()
			end
		else
			--Illegal menuState
			menuState=1
			menuSubState=1
		end
		
		print("Version: "..versionNr,2,2,15,true,1,true)
		if loadingSuccessful then
			print("\nSave data successfully loaded!",2,2,15,true,1,true)
		end
		
	elseif state==1 then
		debugMessage=""
	-- ===================================================================================================================================
	-- SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC SYNC
	-- ===================================================================================================================================
		currUPS=FPS:getValue()
		if (gifRecorderMode) then
			tDiff=0.01666
		else
			tDiff=(time()-now.t)/1000.0
		end
		tDiffUPS=tDiff/0.016666 --1UPS~0.016666s
		last=now
		now.t=time()
		for i=0,7 do now.btn[i]=btn(i) end

		--Decide amount of frames to be rendered based on tDiffUPS (Buggy?...)
		if (doCorrectFPS) then
			if (tDiffUPS>=2 and fpsFactor==1) then fpsFactor=2 elseif (tDiffUPS<=1.0 and fpsFactor==2) then fpsFactor=1 end
		end

	-- ===================================================================================================================================
	-- AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI AI
	-- ===================================================================================================================================
		
		for i=1,#cars do
			--What is the next waypoint to reach?
			mW=track[currentTrack].maxWaypoint
			nW=cars[i].waypoint+1
			if nW>mW then
				nW=1
			end
			
			if (not (i==1)) or gameover then
				--Reset input
				for j=0,7 do
					cars[i].input[j]=false
				end
				
				--Accelerate
				cars[i].input[0]=true
				
				--Precalculations for steering
				newrot=math.deg(math.atan(waypoints[nW].y-cars[i].y,waypoints[nW].x-cars[i].x))
				myrot=cars[i].rot
				if myrot>180 then
					myrot=myrot-360
				end
				if waypoints[nW].x<cars[i].x then
					newrot=newrot+360
					if newrot>360 then
						newrot=newrot-360
					end
					if myrot<0 then
						myrot=myrot+360
					end
				end
				
				--Steering
				if math.abs(myrot-newrot)>cars[i].steeringInaccuracy then --Limit on when to start steering again. Set it too low and the AI will slow itself down by constantly taking the wheel, set it too high and the AI can't aim
					if myrot<newrot then
						cars[i].input[3]=true
					elseif myrot>newrot then
						cars[i].input[2]=true
					end
				end
				
			end
			
			--Waypoint reached?
			if (((cars[i].x<waypoints[nW].x+waypointRadius) and (cars[i].x>waypoints[nW].x-waypointRadius)) and ((cars[i].y<waypoints[nW].y+waypointRadius) and (cars[i].y>waypoints[nW].y-waypointRadius))) then
				cars[i].waypoint=nW
			end
		end
		
		for j=1,#cars do
			cars[j].place=0
		end
		ranksGiven=0
		for k=numberOfLapsToComplete+1,0,-1 do
			if ranksGiven>=#cars then
				break
			end
			for i=track[currentTrack].maxWaypoint,1,-1 do
				if ranksGiven>=#cars then
					break
				end
				for j=#cars,1,-1 do
					foundmyself=false
					if ranksGiven>0 then
						if cars[j].place>0 then
							foundmyself=true
						end
					end
					if (ranksGiven==0) or (not foundmyself) then
						if cars[j].lap>=k then
							if (cars[j].waypoint>=i) then
								ranksGiven=ranksGiven+1
								cars[j].place=ranksGiven
							end
							if ranksGiven>=#cars then
								break
							end
						end
					end
				end
			end
		end
		
	-- ===================================================================================================================================
	-- INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT INPUT
	-- ===================================================================================================================================
		--Player control translation
		if not gameover then
			for i=0,7 do
				cars[1].input[i]=(now.btn[i] and last.btn[i])
			end
		end
		
		--Debug overhead view toggle
		--if now.btn[4] and t%10==0 then overhead=not overhead end

	-- ===================================================================================================================================
	-- CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL CONTROL
	-- ===================================================================================================================================
		--Control for all cars, even AI
		for i=1,#cars do
			--Acceleration
			if cars[i].input[0] or cars[i].input[4] then
				cars[i].speed=cars[i].speed+(cars[i].acceleration*tDiffUPS)
			elseif cars[i].input[1] or cars[i].input[5] then
				cars[i].speed=cars[i].speed-(cars[i].acceleration*tDiffUPS)
			end

			--Steering
			if cars[i].input[2] then
				cars[i].rotSpeed=cars[i].rotSpeed-(cars[i].steeringForce*tDiffUPS)
				cars[i].braking=true
			elseif cars[i].input[3] then
				cars[i].rotSpeed=cars[i].rotSpeed+(cars[i].steeringForce*tDiffUPS)
				cars[i].braking=true
			else
				cars[i].braking=false
			end
		end
		if (tDiff<=soundThreshold) and (t%3==0) then
			sfx(1,24+round(cars[1].speed*7),4,0,15,0)
		end
		
	-- ===================================================================================================================================
	-- LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC LOGIC
	-- ===================================================================================================================================
		--Logic for all race cars (including player), mostly physics:
		for i=1,#cars do
			--Limit rotation to avoid unlikely overflows
			if cars[i].rot>=360 then cars[i].rot=cars[i].rot-360 end
			if cars[i].rot<0 then cars[i].rot=cars[i].rot+360 end

			--Rotate car
			calcSpeed=cars[i].speed
			if (calcSpeed<=-2.5) then
				calcSpeed=-1.25
			elseif (calcSpeed<-5) then
				calcSpeed=-1.25+(calcSpeed/10)
			elseif (calcSpeed>=2.5) then
				calcSpeed=1.25
			elseif (calcSpeed>5) then
				calcSpeed=1.25-(calcSpeed/10)
			else
				calcSpeed=0.5*calcSpeed
			end
			cars[i].rot=cars[i].rot+(cars[i].rotSpeed*calcSpeed*tDiffUPS)

			--Move car forward/backward; Wall collision checks
			cars[i].prevX=cars[i].x
			cars[i].prevY=cars[i].y
			cars[i].x=(cars[i].speed*math.cos(math.rad(cars[i].rot))*tDiffUPS)+cars[i].x --Move along x
			if ((mget(cars[i].x/8,cars[i].y/8)>indexesBiggerThan) and (mget(cars[i].x/8,cars[i].y/8)<indexesSmallerThan)) then --X wall collision
				step=(cars[i].x-cars[i].prevX)/20
				while true do
					cars[i].speed=cars[i].speed*collisionSoftness
					cars[i].x=cars[i].x-step
					if not ((mget(cars[i].x/8,cars[i].y/8)>indexesBiggerThan) and (mget(cars[i].x/8,cars[i].y/8)<indexesSmallerThan)) then
						break
					end
				end
			end
			cars[i].y=(cars[i].speed*math.sin(math.rad(cars[i].rot))*tDiffUPS)+cars[i].y --Move along y
			if ((mget(cars[i].x/8,cars[i].y/8)>indexesBiggerThan) and (mget(cars[i].x/8,cars[i].y/8)<indexesSmallerThan)) then --Y wall collision
				step=(cars[i].y-cars[i].prevY)/20
				while true do
					cars[i].speed=cars[i].speed*collisionSoftness
					cars[i].y=cars[i].y-step
					if not ((mget(cars[i].x/8,cars[i].y/8)>indexesBiggerThan) and (mget(cars[i].x/8,cars[i].y/8)<indexesSmallerThan)) then
						break
					end
				end
			end

			--Apply drag/friction
			if (cars[i].speed<0.01 and cars[i].speed>-0.01) then
				cars[i].speed=0.0
			elseif (cars[i].speed<0.25) then --Strong fraction when slow -> Actually stops the vehicle! (Doubles as a reverse speed limit)
				cars[i].speed=cars[i].speed-((cars[i].speed/(20))*tDiffUPS)
			else
				cars[i].speed=cars[i].speed-((cars[i].speed/(100))*tDiffUPS)
			end
			
			--Brake car
			if (cars[i].braking) then
				cars[i].speed=cars[i].speed-((cars[i].speed/(75))*tDiffUPS)
			end

			--Speed limit, just in case
			if cars[i].speed>10.0 then
				cars[i].speed=10.0
			elseif cars[i].speed<-10.0 then
				cars[i].speed=-10.0
			end

			--Steering auto-center friction stuff
			if (cars[i].rotSpeed<0.01 and cars[i].rotSpeed>-0.01) then
				cars[i].rotSpeed=0.0
			else
				cars[i].rotSpeed=cars[i].rotSpeed-((cars[i].rotSpeed/10)*tDiffUPS)
			end

			--After movement is done, check for current zone
			currI=mget(cars[i].x/8,cars[i].y/8) --current index, not curry
			if (currI>0 and currI<5) then
				cars[i].lastZone=cars[i].zone
				cars[i].zone=currI

				--zone changed; lap change?
				if (cars[i].zone==1 and cars[i].lastZone==4) then
					thisLapT=(now.t-cars[i].lastLapCross)/1000.0 --in seconds
					if ((thisLapT<cars[i].lapBest) and (not (cars[i].lap==0))) then
						cars[i].lapBest=thisLapT
					end
					cars[i].lastLapCross=now.t
					cars[i].lap=cars[i].lap+1
					if cars[i].lap>numberOfLapsToComplete then
						--[[if #finished>0 then
							for k=1,#finished do
								if i==finished[k] then
									break
								elseif k==#finished then
									finished[#finished]=i
								end
							end
						else
							finished[1]=i
						end--]]
						if #finished>0 then
							foundmyself=false
							for k=1,#finished do
								if i==finished[k] then
									foundmyself=true
									break
								end
							end
							if not foundmyself then
								finished[#finished+1]=i
							end
						else
							finished[1]=i
						end
						if (i==1) and not gameover then
							player.raceFinish=now.t
							gameover=true
						end
					end
				elseif (cars[i].zone==4 and cars[i].lastZone==1) then
					cars[i].lap=cars[i].lap-1
				end
			end
			
			
			--RENDER PREPARATION FOR AI CARS
			if i>1 then
				spriteList[cars[i].spriteListI].x=cars[i].x
				spriteList[cars[i].spriteListI].y=cars[i].y
			end
		end
		
		--FOV adjust
		fov=baseFOV+((cars[1].speed/2)^4)

	-- ===================================================================================================================================
	-- RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER RENDER
	-- ===================================================================================================================================
		--Only render if supposed to:
		if (t%fpsFactor==0) then
			--background(14)

			--Initialization
			if (betterSky) then
				cls(14) --Sky with gradient
			else
				cls(2) --Sky/Ceiling/Background
			end

			if overhead then
				map(0,0,240,136,-cars[1].x+120,-cars[1].y+68,-1,1) --Map
				circ(120,68,2,6) --Player Marker

				--Sprites:
				for i=1,#spriteList do
					spr(spriteList[i].index,spriteList[i].x-((spriteList[i].sizeX*8)/2)-cars[1].x+120,spriteList[i].y-((spriteList[i].sizeX*8)/2)-cars[1].y+68,0,1,0,0,spriteList[i].sizeX,spriteList[i].sizeY)
				end
			else
				rect(0,66,240,70,4) --Ground
			end

			--RAYCASTING! THIS IS HOW YOU DO IT!
			--0.3125 degrees per pixel->75 degrees
			--0.375 degrees per pixel ->90 degrees
			--rot=-37.5
			--rot=-45
			rot=-(fov/2)
			--lastLine={mapX=-1,mapY=-1,sRight=0}
			renderQueue={[1]=1}
			for i=0,239 do
				if (i%lineSkipFactor==0) then
					--if (i==120) then trace(player.rot+rot) end
					continue=true
					jk=0 --Distance (radius of a circle)
					j=0 --Distance (The one actually used to render stuff)
					side=0 --Side we hit a block on
					initHit=false --Has the first hit of something been done for this iteration?
					initIndex=-1 --Index of the first block we hit
					finalHit=false --Has backwards raycasting been finished to get a precise distance?
					lastX2=-1
					lastY2=-1
					lastMapX=-1
					lastMapY=-1

					while jk<=distance and continue do
						if jk<0 then break end

						--Oh, and iterate j, of cause.
						if not initHit then
							jk=jk+initialHitStepSize
						end

						-- Perspective correction (Not perfect, but reduces fisheye!)
						j=jk/math.cos(math.rad(rot/fisheyeCompensation))

						--Calculate point to check:
						x2=((j/2.0)*math.cos(math.rad(cars[1].rot+rot)))+cars[1].x
						y2=((j/2.0)*math.sin(math.rad(cars[1].rot+rot)))+cars[1].y

						--Check point on map for wall:
						mapX=math.floor(x2/8)
						mapY=math.floor(y2/8)
						index=mget(mapX,mapY)

						spriteWeGot=0
						--Have we hit a sprite? If yes, which one?
						for i=1,#spriteList do
							if ((x2>=spriteList[i].x-4) and (x2<=spriteList[i].x+4) and (y2>=spriteList[i].y-4) and (y2<=spriteList[i].y+4)) then
								spriteWeGot=i
								break;
							end
						end

						--And go on to render...
						if (index>indexesBiggerThan and index<indexesSmallerThan) or (initIndex>indexesBiggerThan and initIndex<indexesSmallerThan) then

							-- Go back a few steps in distance to find the precise wall position and side
							if not initHit then
								initHit=true
								lastX2=x2
								lastY2=y2
								lastMapX=mapX
								lastMapY=mapY
								initIndex=index
							elseif not finalHit then
								if not (mapX==lastMapX) or not (mapY==lastMapY) then--or (isCorner and not (checkCorner(cornerNr,x2,y2))) then
									if index>indexesBiggerThan and index<indexesSmallerThan then
										lastX2=x2
										lastY2=y2
										lastMapX=mapX
										lastMapY=mapY
										initIndex=index
										if overhead then pix(x2-cars[1].x+120,y2-cars[1].y+68,14) end
									else
										x2=lastX2
										y2=lastY2
										mapX=lastMapX
										mapY=lastMapY
										jk=jk+1
										index=initIndex
										finalHit=true
										if overhead then pix(x2-cars[1].x+120,y2-cars[1].y+68,6) end
									end
								else
									lastX2=x2
									lastY2=y2
									lastMapX=mapX
									lastMapY=mapY
									if overhead then pix(x2-cars[1].x+120,y2-cars[1].y+68,13) end
								end
								jk=jk-1
							end

							if finalHit then --Render the line once we know the precise distance
								if overhead then
									continue=false
								else
									--Find out which side we hit the wall on
									jkR=jk
									jR=j
									xR=0
									yR=0
									continueBack=true
									while continueBack do
										jkR=jkR-0.5

										-- Perspective correction (to avoid fisheye!)
										jR=jk/math.cos(math.rad(rot/fisheyeCompensation))

										--Calculate point to check:
										xR=((jR/2.0)*math.cos(math.rad(cars[1].rot+rot)))+cars[1].x
										yR=((jR/2.0)*math.sin(math.rad(cars[1].rot+rot)))+cars[1].y
										--Check point on map for wall:
										mapXR=math.floor(xR/8)
										mapYR=math.floor(yR/8)

										if mapXR<mapX then
											side=4
											continueBack=false
										elseif mapXR>mapX then
											side=2
											continueBack=false
										elseif mapYR<mapY then
											side=1
											continueBack=false
										elseif mapYR>mapY then
											side=3
											continueBack=false
										elseif jR<0 then
											continueBack=false
										end
									end

									--Render wall
									height=136/jkR*heightFactor --Total height of a line
									step=(height*1.5)/8 -- using *1.5 instead of /2*3 increases performance by 3fps --Height of one pixel of a texture on the line
									heightDiff=height/2
									yNow=66-(height/2)
									if not (side==0) then
										indexChange=0
										posInTexture=0
										if side%2==1 then
											indexChange=1
											posInTexture=math.floor(xR%8)
										else
											posInTexture=math.floor(yR%8)
										end
										
										if classicRender then
											-- Render lines with textures based on known side and position
											for k=0,7 do --Increasing k to 15 results in a kind of reflection; Maybe useful later on?
												--lineMemory[#lineMemory+1]=generateLine(i,yNow,i,yNow+step,sget(((index+indexChange)*8)+posInTexture,k),j)
												if not (sget(((index+indexChange)*8)+posInTexture,k)==0) then
													line(i,yNow,i,yNow+step,sget(((index+indexChange)*8)+posInTexture,k)) --Putting all the wall data into lineMemory induces a significant performance drop
												end
												yNow=yNow+step
											end
										else
											texX=(((index+indexChange)%16)*8)+posInTexture
											texY=(math.floor((index+indexChange)/16)*8)
											textri(i,yNow,i+1,yNow,i+1,yNow+(7*step),texX,texY,texX,texY,texX,texY+8,false,0);
										end
									end
									continue=false
								end
							end
						elseif overhead then
							pix(x2-cars[1].x+120,y2-cars[1].y+68,15)
						elseif spriteWeGot>0 then
							--Refresh information on spriteList
							--Raycasten, ersten x merken, zweiten y merken, Differenz->XScale, height=yScale
							heightN=136/jk*heightFactor
							if (spriteList[spriteWeGot].created) then
								spriteList[spriteWeGot].lastScreenX=i
								spriteList[spriteWeGot].lastScreenHeight=heightN

								--Handle renderQueue sorting here?
								if (spriteList[renderQueue[spriteList[spriteWeGot].renderN-1]].distance>spriteList[spriteWeGot].distance) then --If this distance is bigger than on the last sprite...
									renderQueue[spriteList[spriteWeGot].renderN]=renderQueue[spriteList[spriteWeGot].renderN-1]
									renderQueue[spriteList[spriteWeGot].renderN-1]=spriteWeGot
								end
							else
								spriteList[spriteWeGot].firstScreenX=i
								spriteList[spriteWeGot].firstScreenHeight=heightN
								spriteList[spriteWeGot].lastScreenX=i
								spriteList[spriteWeGot].lastScreenHeight=heightN
								renderQueue[#renderQueue+1]=spriteWeGot
								spriteList[spriteWeGot].renderN=#renderQueue
								spriteList[spriteWeGot].distance=jk
								spriteList[spriteWeGot].created=true
							end
						end
					end
				end

				--Iterate rotation
				rot=rot+(fov/240)
			end

		--Render sprites
			for j=#renderQueue,1,-1 do
				i=renderQueue[j]
				if (spriteList[i].created) then
					hNow=(spriteList[i].firstScreenHeight+spriteList[i].lastScreenHeight)/2
					xDiff=(spriteList[i].lastScreenX-spriteList[i].firstScreenX)*spriteList[i].w3D
					xMed=(spriteList[i].lastScreenX+spriteList[i].firstScreenX)/2
					yGround=66+hNow

					scaledSpr(spriteList[i].index,xMed-xDiff,yGround-(hNow*spriteList[i].h3D),xMed+xDiff,yGround,spriteList[i].ck,spriteList[i].sizeX*8,spriteList[i].sizeY*8)
					if (not gameover) and (spriteList[i].index==91) then
						--If it's a car, show its placement above
						if #cars>1 then
							for k=2,#cars do
								if cars[k].spriteListI==i then
									print(cars[k].place.."/"..#cars,xMed-4,66-hNow,15,true,1,true)
									break
								end
							end
						end
					end
					
					--Reset every sprite here!
					spriteList[i].created=false
					spriteList[i].firstScreenX=0
					spriteList[i].firstScreenHeight=0
				end
			end

			--Render Cockpit
			if (renderCockpit and not overhead) then
				--Cockpit (Middle)
				spr(357,32,72,14,2,0,0,11,4)

				--Wheels
				leOffset=0
				if (cars[1].rotSpeed>0.25) then
					leOffset=1
				elseif (cars[1].rotSpeed<-0.25) then
					leOffset=-1
				end
				spr(288+(2*(math.floor(wheelT)%4))-(32*leOffset),0,104,15,2,1,0,2,2) --Left
				spr(288+(2*(math.floor(wheelT)%4))+(32*leOffset),208,104,15,2,0,0,2,2) --Right

				--Speed meter
				piFactor=math.rad(cars[1].speed*72) -- speed/5*360
				--if piFactor>1.0 then piFactor=1.0 elseif piFactor<-1.0 then piFactor=-1.0 end
				for wow=0,1 do
					line(78,122,78+wow+math.sin(piFactor)*6,122-math.cos(piFactor)*6,6)
				end

				--Steering Wheel
				steerOffset=0
				steerFlip=0
				if (now.btn[2]) then
					steerOffset=32
				elseif (now.btn[3]) then
					steerOffset=32
					steerFlip=1
				end

				spr(352+steerOffset,96,104,14,2,steerFlip,0,3,2)
			end

			if not gameover then
				-- Race Statistics
				print("Lap: "..cars[1].lap.."\nZone: "..cars[1].zone,2,2,15,true,1,true) --Top-Left
				print("Position: "..cars[1].place.."/"..#cars,1,130,15,true,1,true) --Bottom-Left
				
				if (cars[1].lapBest==2147483647) then
					bestToBeShown="----------"
				else
					bestToBeShown=cars[1].lapBest
				end
				print(((now.t-cars[1].lastLapCross)/1000.0).."\n"..bestToBeShown,150,2,15,true,1,true) --Top-Right
				print("Current Lap\nFastest Lap",195,2,15,true,1,true) --Top-Right
				
				--Render minimap  minimap(x,y,mapX,mapY,width,height,sizeReduce)
				minimap(2,83,track[currentTrack].mapX,track[currentTrack].mapY,track[currentTrack].width,track[currentTrack].height,3)
			else
				-- ===================================================================================================================================
				-- GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER GAMEOVER
				-- ===================================================================================================================================
				myPlacement=0
				for i=1,#finished do
					if finished[i]==1 then
						myPlacement=i
						break
					end
				end
				print("FINISHED!",61,16,15,true,3,true)
				printCenter("Your placement: "..myPlacement.."/"..#cars,119,36,15,true,true)
				myTime=math.floor(player.raceFinish-player.raceStart)/1000
				highscoreText=""
				if numberOfLapsToComplete==5 then
					if myTime<track[currentTrack].bestTime then
						newPersonalBest=true
						track[currentTrack].bestTime=myTime
						makeSave()
					end
					if newPersonalBest then
						highscoreText=" (New Personal Best!)"
					end
				end
				printCenter("Your time ("..numberOfLapsToComplete.." laps): "..myTime.."s"..highscoreText,119,44,15,true,true)
				if numberOfLapsToComplete==5 then
					printCenter("Personal Best: "..track[currentTrack].bestTime.."s",119,50,15,true,true)
				end
				
				currentMaxSubState=2
				--menuSubState control
				if btnp(0,30,10) then
					--Up
					menuSubState=menuSubState-1
				elseif btnp(1,30,10) then
					--Down
					menuSubState=menuSubState+1
				end
				--menuSubState loop
				if menuSubState<1 then
					menuSubState=currentMaxSubState
				elseif menuSubState>currentMaxSubState then
					menuSubState=1
				end
				
				for i=1,2 do
					if (i==menuSubState) and (math.floor((time())/250)%2==0) then
						cList[i]=6
					else
						cList[i]=15
					end
				end
				printCenter("Retry",119,58,cList[1],true,true)
				printCenter("Return to Main Menu",119,66,cList[2],true,true)
				
				--Control
				if menuSubState==1 and btnp(4,30,10) then
					state=1
					reset()
				elseif menuSubState==2 and btnp(4,30,10) then
					state=0
					menuState=1
					menuSubState=1
				end
			end

			-- ===================================================================================================================================
			-- DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG
			-- ===================================================================================================================================

			-- FPS Display:
			if showFPS then
				print("\n\nFPS: " .. currUPS,2,2,15,true,1,true)
			end
			if tDiff>soundThreshold then
				print("\n\n\nSound disabled (Low FPS)",2,2,15,true,1,true)
			end

			--[[if showDebug then
				-- time() display
				print("\n\n\nnow.t="..now.t.."\nlast.t="..last.t.."\ntDiff="..tDiff.."\nUPS/FPS="..tDiffUPS.."\nfpsFactor="..fpsFactor.."\nplayer.speed="..player.speed.."\nplayer.rotSpeed="..player.rotSpeed.."\nx,y="..player.x.." "..player.y,2,2,15,true,1,true)

				-- FOV Display:
				print("FOV: "..math.floor(fov).."'",2,118,15,true,1,true)
			end--]]
		end

	-- ===================================================================================================================================
	-- ITERATION ITERATION ITERATION ITERATION ITERATION ITERATION ITERATION ITERATION ITERATION ITERATION ITERATION ITERATION ITERATION
	-- ===================================================================================================================================
		if not (cars[1].speed==0) then
			wheelT=wheelT+(0.5*cars[1].speed*tDiffUPS)
		end
		
		--print(debugMessage)
		
		--DEBUG RESET?
		--[[if now.btn[5] and last.btn[5] then
			reset()
			state=1
			if currentTrack==0 then
				currentTrack=1
			else
				currentTrack=0
			end
		end--]]
	else
		state=0
		reset()
	end
	t=t+1
end

-- <TILES>
-- 000:4444444444444444444444444444444444444444444444444444444444444444
-- 001:555555555555f555555ff5555555f5555555f5555555f555555fff5555555555
-- 002:cccccccccc000cccccccc0ccccccc0ccccc00ccccc0ccccccc0000cccccccccc
-- 003:222ff22222222f2222222f22222ff22222222f2222222f22222ff22222222222
-- 004:9999999999099999990999999909099999000999999909999999099999999999
-- 005:1116611111611611111116111111611111166111111111111116611111166111
-- 006:1116611111611611111116111111611111166111111111111116611111166111
-- 007:1116611111611611111116111111611111166111111111111116611111166111
-- 008:1116611111611611111116111111611111166111111111111116611111166111
-- 009:1116611111611611111116111111611111166111111111111116611111166111
-- 010:1116611111611611111116111111611111166111111111111116611111166111
-- 011:1116611111611611111116111111611111166111111111111116611111166111
-- 012:1116611111611611111116111111611111166111111111111116611111166111
-- 013:1116611111611611111116111111611111166111111111111116611111166111
-- 014:1116611111611611111116111111611111166111111111111116611111166111
-- 015:1116611111611611111116111111611111166111111111111116611111166111
-- 016:7777777733373337777777777333733377777777333733377777777733733373
-- 017:3333333300030003333333333000300033333333000300033333333303000300
-- 018:7b7b7777b33733377777b7b77b33733377b7b77b333b33b77b77b77737b33733
-- 019:3555333350030003333353533500300033535335000500533533533303500300
-- 020:0700070007070707777777776666ffff6666ffff6666ffff6666ffff6666ffff
-- 021:0300030003030303333333331111aaaa1111aaaa1111aaaa1111aaaa1111aaaa
-- 022:9679967996799679679967996799679979967996799679969967996799679967
-- 023:4134413441344134134413441344134434413441344134414413441344134413
-- 024:000f700066f66f66f66f66f66f66f66ff66f66f666f66f66000f7000000f7000
-- 025:000fa00066f66f666f66f66ff66f66f66f66f66f66f66f66000fa000000fa000
-- 026:1116611111611611111116111111611111166111111111111116611111166111
-- 027:1116611111611611111116111111611111166111111111111116611111166111
-- 028:1116611111611611111116111111611111166111111111111116611111166111
-- 029:1116611111611611111116111111611111166111111111111116611111166111
-- 030:1116611111611611111116111111611111166111111111111116611111166111
-- 031:1116611111611611111116111111611111166111111111111116611111166111
-- 032:00000005000000bb000005550000bb5b00005535000bbbbb00055553000bbb5b
-- 033:50000000530000005550000057b3000055550000533b300055b5500053573000
-- 034:000600005005b00555b50560b6b0b555505005b000b50b00000bbb0001555110
-- 035:000000aa000aa7a700aaaaa700a77a770aaaa7770aa77717aaaa7771a7a77711
-- 036:a7000000777700007777000017110000711710001111100071111a771111a711
-- 037:4444444444aaa4444a777344a7777734a7737734a77777344a77730044333004
-- 038:4444444444411444443331444137304414333014333033313730373033303330
-- 039:44499444444ff4444449944444f99f44449ff9444f9999f499ffff9949999994
-- 040:000f7000000f7000000f7000000f7000000f7000000f7000000f700000111100
-- 041:000f7000000f7000000f7000000f7000000f7000000f7000000f700000111100
-- 042:1116611111611611111116111111611111166111111111111116611111166111
-- 043:1116611111611611111116111111611111166111111111111116611111166111
-- 044:1116611111611611111116111111611111166111111111111116611111166111
-- 045:1116611111611611111116111111611111166111111111111116611111166111
-- 046:1116611111611611111116111111611111166111111111111116611111166111
-- 047:1116611111611611111116111111611111166111111111111116611111166111
-- 048:0055535500b5bbbb005553550bbbb5b5055335550bb5bb5b55555535bb5bbb5b
-- 049:555b550053535300555bb500b53535305b555550553573305555b5b553b73b33
-- 050:000f7aaa000f7000000f7000000f7000000f7000000f7000000f700a000f70a0
-- 051:aaaaaaaa6f6f6f6ff6f6f6f66f6f6f6ff6f6f6f6a00000000000000000000000
-- 052:aaaaaaaa6f6f6f6ff6f6f6f66f6f6f6ff6f6f6f6000000000000000000000000
-- 053:aaaaaaaa6f6f6f6ff6f6f6f66f6f6f6ff6f6f6f6000000000000000000000000
-- 054:aaaaaaaa6f6f6f6ff6f6f6f66f6f6f6ff6f6f6f6000000000000000000000000
-- 055:aaaaaaaa6f6f6f6ff6f6f6f66f6f6f6ff6f6f6f6000000000000000000000000
-- 056:aaaaaaaa6f6f6f6ff6f6f6f66f6f6f6ff6f6f6f6000000000000000000000000
-- 057:aaaaaaaa6f6f6f6ff6f6f6f66f6f6f6ff6f6f6f60000000a0000000000000000
-- 058:aaaf7000000f7000000f7000000f7000000f7000000f7000a00f70000a0f7000
-- 059:555555555555555555555555555555555555555e5555555f3777755f5537557f
-- 060:55555555555555555555555555555555fff55555ddd55555fff55546fff55546
-- 061:5555555555555555555555555555555555555555555555555555555555555555
-- 062:1116611111611611111116111111611111166111111111111116611111166111
-- 063:1116611111611611111116111111611111166111111111111116611111166111
-- 064:0000004400000094000000440000009900000044000009940000494400094114
-- 065:1100000011000000410000001100000041000000440400001141000044111000
-- 066:000f7a00000f7000000f7000000f7000000f7000000f7000000f7000000f7000
-- 074:00af7000000f7000000f7000000f7000000f7000000f7000000f7000000f7000
-- 075:5537556755375566556666665665555e66550055665000056650000555550055
-- 076:aaaaaa467aaaaa4667aa5546e6665666ee666666eff66fffeee6666655555555
-- 077:6555555566655555666666556555566555005566500005665000056655005555
-- 078:1116611111611611111116111111611111166111111111111116611111166111
-- 079:1116611111611611111116111111611111166111111111111116611111166111
-- 080:1116611111611611111116111111611111166111111111111116611111166111
-- 081:1116611111611611111116111111611111166111111111111116611111166111
-- 082:000f7000000f7000000f7000000f7000000f7000000f7000000f700000111100
-- 090:000f7000000f7000000f7000000f7000000f7000000f7000000f700000111100
-- 091:55555555555555555555555555555555555555555555555555555555555557a5
-- 092:5555555555555555555555555555555555555555555555555555555557a55555
-- 093:5555555555555555555555555555555555555555555555555555555555555555
-- 094:555555555555555555555555555555555555555f5555555d5553775f5555357f
-- 095:55555555555555555555555555555555f5555555d5555555f5455555f5455555
-- 096:1116611111611611111116111111611111166111111111111116611111166111
-- 097:1116611111611611111116111111611111166111111111111116611111166111
-- 098:1116611111611611111116111111611111166111111111111116611111166111
-- 099:1116611111611611111116111111611111166111111111111116611111166111
-- 100:1116611111611611111116111111611111166111111111111116611111166111
-- 101:1116611111611611111116111111611111166111111111111116611111166111
-- 102:1116611111611611111116111111611111166111111111111116611111166111
-- 103:1116611111611611111116111111611111166111111111111116611111166111
-- 104:1116611111611611111116111111611111166111111111111116611111166111
-- 105:1116611111611611111116111111611111166111111111111116611111166111
-- 106:1116611111611611111116111111611111166111111111111116611111166111
-- 107:555557ad555507ad522207a2222277aa111111111101111150005aa150005555
-- 108:d7a5555537a5555507a2222577aa222211111111111110111115000555550005
-- 109:5555555555555555555555555555555555555555555555555555555555555555
-- 110:5555356a55553567555566665555655e5556505e5556500e5556500e55555055
-- 111:aa465555aa466655a54666656566555666655056f6f50006e665000655555055
-- 112:1116611111611611111116111111611111166111111111111116611111166111
-- 113:1116611111611611111116111111611111166111111111111116611111166111
-- 114:1116611111611611111116111111611111166111111111111116611111166111
-- 115:1116611111611611111116111111611111166111111111111116611111166111
-- 116:1116611111611611111116111111611111166111111111111116611111166111
-- 117:1116611111611611111116111111611111166111111111111116611111166111
-- 118:1116611111611611111116111111611111166111111111111116611111166111
-- 119:1116611111611611111116111111611111166111111111111116611111166111
-- 120:1116611111611611111116111111611111166111111111111116611111166111
-- 121:1116611111611611111116111111611111166111111111111116611111166111
-- 122:1116611111611611111116111111611111166111111111111116611111166111
-- 123:1116611111611611111116111111611111166111111111111116611111166111
-- 124:1116611111611611111116111111611111166111111111111116611111166111
-- 125:1515166111611611111116111111611111166111111111111116611111166111
-- 126:1111166111611611111116111111611111166111111111111116611111166111
-- 127:1111661111611611111116111111611111166111111111111116611111166111
-- 128:1116611111611611111116111111611111166111111111111116611111166111
-- 129:1116611111611611111116111111611111166111111111111116611111166111
-- 130:1116611111611611111116111111611111166111111111111116611111166111
-- 131:1116611111611611111116111111611111166111111111111116611111166111
-- 132:1116611111611611111116111111611111166111111111111116611111166111
-- 133:1116611111611611111116111111611111166111111111111116611111166111
-- 134:1116611111611611111116111111611111166111111111111116611111166111
-- 135:1116611111611611111116111111611111166111111111111116611111166111
-- 136:1116611111611611111116111111611111166111111111111116611111166111
-- 137:1116611111611611111116111111611111166111111111111116611111166111
-- 138:1116611111611611111116111111611111166111111111111116611111166111
-- 139:1116611111611611111116111111611111166111111111111116611111166111
-- 140:1116611111611611111116111111611111166111111111111116611111166111
-- 141:1116611111611611111116111111611111166111111111111116611111166111
-- 142:1116611111611611111116111111611111166111111111111116611111166111
-- 143:1116611111611611111116111111611111166111111111111116611111166111
-- 144:fffffffff000ff00f0f0f0f0f0f0fff0f0f0fff0f0f0fff0f000fff0ffffffff
-- 145:fffffffff000f000f0f0fff0f0f0ff0ff0f0f0fff0f0f0fff000f000ffffffff
-- 146:fffffffff000f000f0f0fff0f0f0fff0f0f0f000f0f0fff0f000f000ffffffff
-- 147:fffffffff000ff0ff0f0f0fff0f0f0f0f0f0ff00f0f0fff0f000fff0ffffffff
-- 148:fffffffff000f000f0f0f0fff0f0f000f0f0fff0f0f0fff0f000f000ffffffff
-- 149:fffffffff000f0fff0f0f0fff0f0f0fff0f0f000f0f0f0f0f000f000ffffffff
-- 150:fffffffff000f000f0f0fff0f0f0ff00f0f0fff0f0f0fff0f000fff0ffffffff
-- 151:fffffffff000f000f0f0f0f0f0f0f0f0f0f0f000f0f0f0f0f000f000ffffffff
-- 152:fffffffff000f000f0f0f0f0f0f0f000f0f0fff0f0f0fff0f000fff0ffffffff
-- 153:ffffffffff00f000f0f0f0f0fff0f0f0fff0f0f0fff0f0f0fff0f000ffffffff
-- 154:ffffffffff00ff00f0f0f0f0fff0fff0fff0fff0fff0fff0fff0fff0ffffffff
-- 155:ffffffffff00f000f0f0fff0fff0ff00fff0f0fffff0f0fffff0f000ffffffff
-- 156:ffffffffff00f000f0f0fff0fff0ff00fff0fff0fff0fff0fff0f000ffffffff
-- 157:ffffffffff00ff0ff0f0f0fffff0f0f0fff0f000fff0fff0fff0fff0ffffffff
-- 158:ffffffffff00f000f0f0f0fffff0f000fff0fff0fff0fff0fff0f000ffffffff
-- 159:ffffffffff00f0fff0f0f0fffff0f0fffff0f000fff0f0f0fff0f000ffffffff
-- 160:ffffffffff00f000f0f0fff0fff0ff00fff0fff0fff0fff0fff0fff0ffffffff
-- 161:ffffffffff00f000f0f0f0f0fff0f000fff0f0f0fff0f0f0fff0f000ffffffff
-- 162:ffffffffff00f000f0f0f0f0fff0f000fff0fff0fff0fff0fff0f000ffffffff
-- 163:fffffffff000f000fff0f0f0ff00f0f0f0fff0f0f0fff0f0f000f000ffffffff
-- 164:fffffffff000ff00fff0f0f0ff00fff0f0fffff0f0fffff0f000fff0ffffffff
-- 165:fffffffff000f000fff0fff0ff00f000f0fff0fff0fff0fff000f000ffffffff
-- 166:fffffffff000f000fff0fff0ff00f000f0fffff0f0fffff0f000f000ffffffff
-- 167:fffffffff000f0fffff0f0f0ff00f000f0fffff0f0fffff0f000fff0ffffffff
-- 168:fffffffff000f000fff0f0ffff00f000f0fffff0f0fffff0f000f000ffffffff
-- 169:fffffffff000f0fffff0f0ffff00f0fff0fff000f0fff0f0f000f000ffffffff
-- 170:fffffffff000f000fff0fff0ff00ff00f0fffff0f0fffff0f000fff0ffffffff
-- 171:fffffffff000f000fff0f0f0ff00f000f0fff0f0f0fff0f0f000f000ffffffff
-- 172:fffffffff000f000fff0f0f0ff00f000f0fffff0f0fffff0f000fff0ffffffff
-- 173:fffffffff000f000fff0f0f0f000f0f0fff0f0f0fff0f0f0f000f000ffffffff
-- 174:fffffffff000ff00fff0f0f0f000fff0fff0fff0fff0fff0f000fff0ffffffff
-- 175:fffffffff000f000fff0fff0f000f000fff0f0fffff0f0fff000f000ffffffff
-- 176:fffffffff000f000fff0fff0f000f000fff0fff0fff0fff0f000f000ffffffff
-- 177:fffffffff000f0fffff0f0f0f000f0f0fff0f000fff0fff0f000fff0ffffffff
-- 178:fffffffff000f000fff0f0fff000f000fff0fff0fff0fff0f000f000ffffffff
-- 179:fffffffff000f0fffff0f0fff000f0fffff0f000fff0f0f0f000f000ffffffff
-- 180:fffffffff000f000fff0fff0f000f000fff0fff0fff0fff0f000fff0ffffffff
-- 181:fffffffff000f000fff0f0f0f000f000fff0f0f0fff0f0f0f000f000ffffffff
-- 182:fffffffff000f000fff0f0f0f000f000fff0fff0fff0fff0f000f000ffffffff
-- 183:fffffffff0fff000f0f0f0f0f0f0f0f0f000f0f0fff0f0f0fff0f000ffffffff
-- 184:fffffffff0ffff00f0f0f0f0f0f0fff0f000fff0fff0fff0fff0fff0ffffffff
-- 185:fffffffff0fff000f0f0fff0f0f0f000f000f0fffff0f0fffff0f000ffffffff
-- 186:fffffffff0fff000f0f0fff0f0f0f000f000fff0fff0fff0fff0f000ffffffff
-- 187:fffffffff0fff0fff0f0f0f0f0f0f0f0f000f000fff0fff0fff0fff0ffffffff
-- 188:1116611111611611111116111111611111166111111111111116611111166111
-- 189:1116611111611611111116111111611111166111111111111116611111166111
-- 190:1116611111611611111116111111611111166111111111111116611111166111
-- 191:1116611111611611111116111111611111166111111111111116611111166111
-- 192:1333333171333317771331777771177777711777771331777133331713333331
-- 193:555555555555555555555566555556ff555556ff555566ff500666f150064411
-- 194:555555555555555566555555ff655555ff655555ff6655551f66600511446005
-- 195:5555555555555555555555555555555555555555555555555555552d555527a2
-- 196:555555555555555555555555555555555555555555555555d255555527a25555
-- 197:1116611111611611111116111111611111166111111111111116611111166111
-- 198:1116611111611611111116111111611111166111111111111116611111166111
-- 199:1116611111611611111116111111611111166111111111111116611111166111
-- 200:1116611111611611111116111111611111166111111111111116611111166111
-- 201:1116611111611611111116111111611111166111111111111116611111166111
-- 202:1116611111611611111116111111611111166111111111111116611111166111
-- 203:1116611111611611111116111111611111166111111111111116611111166111
-- 204:1116611111611611111116111111611111166111111111111116611111166111
-- 205:1116611111611611111116111111611111166111111111111116611111166111
-- 206:1116611111611611111116111111611111166111111111111116611111166111
-- 207:1116611111611611111116111111611111166111111111111116611111166111
-- 208:1333333171333317771331777771177777711777771331777133331713333331
-- 209:5566441155666641556666415566666456666666066666660666666600055555
-- 210:1144665514666655146666554666665566666665666666606666666055555000
-- 211:555227ad552207ad522207a2222277aa111111111101111150005aa150005555
-- 212:d7a2255537a2225507a2222577aa222211111111111110111115000555550005
-- 213:1116611111611611111116111111611111166111111111111116611111166111
-- 214:1116611111611611111116111111611111166111111111111116611111166111
-- 215:1116611111611611111116111111611111166111111111111116611111166111
-- 216:1116611111611611111116111111611111166111111111111116611111166111
-- 217:1116611111611611111116111111611111166111111111111116611111166111
-- 218:1116611111611611111116111111611111166111111111111116611111166111
-- 219:1116611111611611111116111111611111166111111111111116611111166111
-- 220:1116611111611611111116111111611111166111111111111116611111166111
-- 221:1116611111611611111116111111611111166111111111111116611111166111
-- 222:1116611111611611111116111111611111166111111111111116611111166111
-- 223:1116611111611611111116111111611111166111111111111116611111166111
-- 224:3333333377777777333333337777777733333333777777773333333377777777
-- 225:1161111111661111116661111166661111666661116666111166611111661111
-- 226:1111111111111111111111116666666666666666111111111111111111111111
-- 227:7777777773373373777777773733733777777777733733737777777733733733
-- 228:7777777733373337777777777333733377777777333733377777777733733373
-- 229:1116611111611611111116111111611111166111111111111116611111166111
-- 230:1116611111611611111116111111611111166111111111111116611111166111
-- 231:1116611111611611111116111111611111166111111111111116611111166111
-- 232:1116611111611611111116111111611111166111111111111116611111166111
-- 233:1116611111611611111116111111611111166111111111111116611111166111
-- 234:1116611111611611111116111111611111166111111111111116611111166111
-- 235:1116611111611611111116111111611111166111111111111116611111166111
-- 236:1116611111611611111116111111611111166111111111111116611111166111
-- 237:1116611111611611111116111111611111166111111111111116611111166111
-- 238:1116611111611611111116111111611111166111111111111116611111166111
-- 239:1116611111611611111116111111611111166111111111111116611111166111
-- 240:7a7a7777a33733737777a7a73a33733777a7a77a733a33a37a77a77733a33733
-- 241:1116611111611611111116111111611111166111111111111116611111166111
-- 242:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
-- 243:1116611111611611111116111111611111166111111111111116611111166111
-- 244:1116611111611611111116111111611111166111111111111116611111166111
-- 245:1116611111611611111116111111611111166111111111111116611111166111
-- 246:1116611111611611111116111111611111166111111111111116611111166111
-- 247:1116611111611611111116111111611111166111111111111116611111166111
-- 248:1116611111611611111116111111611111166111111111111116611111166111
-- 249:1116611111611611111116111111611111166111111111111116611111166111
-- 250:1116611111611611111116111111611111166111111111111116611111166111
-- 251:1116611111611611111116111111611111166111111111111116611111166111
-- 252:1116611111611611111116111111611111166111111111111116611111166111
-- 253:1116611111611611111116111111611111166111111111111116611111166111
-- 254:1116611111611611111116111111611111166111111111111116611111166111
-- 255:1116611111611611111116111111611111166111111111111116611111166111
-- </TILES>

-- <SPRITES>
-- 000:ff00000022200000222220032222222022222222222222222222222222222222
-- 001:000000ff00000000000003003000003000000000200000002200000022200000
-- 002:ff30003022200003222220002222222022222222222222222222222222222222
-- 003:000000ff00000000000000000000000000000000200300002200300022200000
-- 004:ff30000022230000222220002222222022222222222222222222222222222222
-- 005:000000ff03000000003000000000003000000003200000002200000022203000
-- 006:ff00030022200030222220002222222022222222222222222222222222222222
-- 007:000000ff00000000000000000000000000000000230000002230300022200300
-- 008:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 009:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 010:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 011:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 012:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 013:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 014:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 015:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 016:2222222222222222112222221112222211112222111112221111112211111112
-- 017:2222000022222000222222002222222022222222222222222222222222222222
-- 018:2222222222222222112222221112222211112222111112221111112211111112
-- 019:2222000022222030222222032222222022222222222222222222222222222222
-- 020:2222222222222222112222221112222211112222111112221111112211111112
-- 021:2222030022222000222222002222222022222222222222222222222222222222
-- 022:2222222222222222112222221112222211112222111112221111112211111112
-- 023:2222000022222030222222032222222022222222222222222222222222222222
-- 024:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 025:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 026:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 027:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 028:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 029:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 030:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 031:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 032:0000000022200000222220032222222022222222222222222222222222222222
-- 033:0000ffff000000ff0000030f3000003f00000000200000002200000022200000
-- 034:0030003022200003222220002222222022222222222222222222222222222222
-- 035:0000ffff000000ff0000000f0000000f00000000200300002200300022200000
-- 036:0030000022230000222220002222222022222222222222222222222222222222
-- 037:0000ffff030000ff0030000f0000003f00000003200000002200000022203000
-- 038:0300030022200030222220002222222022222222222222222222222222222222
-- 039:0000ffff000000ff0000000f0000000f00000000230000002230300022200300
-- 040:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 041:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 042:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 043:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 044:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 045:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 046:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 047:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 048:2222222222222222112222221112222211112222111112221111112211111112
-- 049:2222000022222000222222002222222022222222222222222222222222222222
-- 050:2222222222222222112222221112222211112222111112221111112211111112
-- 051:2222000022222030222222032222222022222222222222222222222222222222
-- 052:2222222222222222112222221112222211112222111112221111112211111112
-- 053:2222030022222000222222002222222022222222222222222222222222222222
-- 054:2222222222222222112222221112222211112222111112221111112211111112
-- 055:2222000022222030222222032222222022222222222222222222222222222222
-- 056:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 057:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 058:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 059:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 060:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 061:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 062:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 063:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 064:0000000022200000222220032222222022222222222222222222222222222222
-- 065:00ffffff0000ffff00000fff30000fff000000ff2000000f2200000f2220000f
-- 066:0030003022200003222220002222222022222222222222222222222222222222
-- 067:00ffffff0000ffff00000fff00000fff000000ff2003000f2200300f2220000f
-- 068:0030000022230000222220002222222022222222222222222222222222222222
-- 069:00ffffff0300ffff00300fff00000fff000000ff2000000f2200000f2220300f
-- 070:0300030022200030222220002222222022222222222222222222222222222222
-- 071:00ffffff0000ffff00000fff00000fff000000ff2300000f2230300f2220030f
-- 072:1116611111611611111116111111611111166111111111111116611111166111
-- 073:1116611111611611111116111111611111166111111111111116611111166111
-- 074:1116611111611611111116111111611111166111111111111116611111166111
-- 075:1116611111611611111116111111611111166111111111111116611111166111
-- 076:1116611111611611111116111111611111166111111111111116611111166111
-- 077:1116611111611611111116111111611111166111111111111116611111166111
-- 078:1116611111611611111116111111611111166111111111111116611111166111
-- 079:1116611111611611111116111111611111166111111111111116611111166111
-- 080:2222222222222222112222221112222211112222111112221111112211111112
-- 081:2222000f2222200f2222220f2222222f22222222222222222222222222222222
-- 082:2222222222222222112222221112222211112222111112221111112211111112
-- 083:2222000f2222200f2222220f2222222f22222222222222222222222222222222
-- 084:2222222222222222112222221112222211112222111112221111112211111112
-- 085:2222030f2222200f2222220f2222222f22222222222222222222222222222222
-- 086:2222222222222222112222221112222211112222111112221111112211111112
-- 087:2222000f2222200f2222220f2222222f22222222222222222222222222222222
-- 088:1116611111611611111116111111611111166111111111111116611111166111
-- 089:1116611111611611111116111111611111166111111111111116611111166111
-- 090:1116611111611611111116111111611111166111111111111116611111166111
-- 091:1116611111611611111116111111611111166111111111111116611111166111
-- 092:1116611111611611111116111111611111166111111111111116611111166111
-- 093:1116611111611611111116111111611111166111111111111116611111166111
-- 094:1116611111611611111116111111611111166111111111111116611111166111
-- 095:1116611111611611111116111111611111166111111111111116611111166111
-- 096:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee33eeeee377eeee3777eeee3777
-- 097:eeeeeeeeeeeeeeeeeeeeeeee3333333377777777733773373ee33ee33ee33ee3
-- 098:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee33eeeeee773eeeee7773eeee7773eeee
-- 099:1116611111611611111116111111611111166111111111111116611111166111
-- 100:1116611111611611111116111111611111166111111111111116611111166111
-- 101:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 102:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 103:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 104:eeeeeeeeeeeeeeefeeeeeffeeeeefeeeeeefeeeeeefeeeeeeefeeeeeefeeeeee
-- 105:effffffffeeeeeeeeeeeeeeeeeeefeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 106:ffffffffeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 107:fffffffeeeeeeeefeeeeeeeeeeeeeeeeeeeeeeeeeeefeeeeeeeeeeeeeeeeeeee
-- 108:eeeeeeeefeeeeeeeeffeeeeeeeefeeeeeeeefeeeeeeeefeeeeeeefeeeeeeeefe
-- 109:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 110:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 111:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 112:eee37777eee37333ee373eeeee373eeee3777333e3777777e3777777e3777777
-- 113:3ee33ee3eee33eeeeee33eeeeee33eee33377333777777777773377777333377
-- 114:77773eee33373eeeeee373eeeee373ee3337773e7777773e7777773e7777773e
-- 115:1116611111611611111116111111611111166111111111111116611111166111
-- 116:1116611111611611111116111111611111166111111111111116611111166111
-- 117:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee222ee222222
-- 118:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee222222222222222222222
-- 119:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee22222222222222f2222222f2222222f
-- 120:efeeeeeefeeeeeeefeeeeeeefeefeeeefeeeeeee22eeeeee2222eeee22222eee
-- 121:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 122:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 123:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeefeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 124:eeeeeefeeeeeeeefeeeeeeefeeeeeeefeeeeeeefeeeeee22eeee2222eee22222
-- 125:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee2222222ef2222222f2222222f2222222
-- 126:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee22222eee2222222222222222
-- 127:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee222eeeee222222ee
-- 128:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee33eeeee377eeee3777eeee3773
-- 129:eeeeeeeeeeeeeeeeeeeeeeee33333333777733777773ee377773ee373773ee33
-- 130:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee33eeeeee773eeeee7773eeee3333eeee
-- 131:1116611111611611111116111111611111166111111111111116611111166111
-- 132:1116611111611611111116111111611111166111111111111116611111166111
-- 133:2222222222222222222222222222222222222222222222222222221122221111
-- 134:2222222222222222222222222222222022211103211111031111103311111033
-- 135:2222200022000333003333333333334433344444344444443444440344444003
-- 136:0000000033333333333333334444444444494444444944440444944400444447
-- 137:0000000033333333333333334444444444444444444444440000004400000004
-- 138:0000000033333333333333334444444444494444444944444444944444444449
-- 139:0000000033333333333333334444444444444444444494444444494444444944
-- 140:0000000033333333333333334444444444444444444494444444494444444944
-- 141:0002222233300022333333004433333344444333444444439444444394444944
-- 142:2222222222222222222222220222222230111222301111123301111133011111
-- 143:2222222222222222222222222222222222222222222222221122222211112222
-- 144:eee3773eeee3773eee37773eee37773ee377333ee373eeeee373eee3e3773337
-- 145:e3773eeee3773eeee3773eeeee377333ee377777ee3777773377337777733337
-- 146:eee33eeeeee33eee333773ee777773ee7777773e7777773e7777773e7777773e
-- 147:1116611111611611111116111111611111166111111111111116611111166111
-- 148:1116611111611611111116111111611111166111111111111116611111166111
-- 149:2211111111111111111111111111111111111111111111111111111111111111
-- 150:1111103311110333111103341111033411110334111103341111033411110334
-- 151:4444000344440003494400004944400044944400444444444444444444444444
-- 152:0004444000044447000494400044494704444940944444479444444444444444
-- 153:0777000407777004070707040770770407070709077777040000004444444444
-- 154:4444444944444444444494444444494444444944944444449444444444444444
-- 155:4444444494444444444444444494444444494449444944444444444444444444
-- 156:4444444944444444444494444444494444444944944444449444444444444444
-- 157:4444494444444494444444444444944444444944444449444444444444444444
-- 158:3301111133301111433011114330111143301111433011114330111143301111
-- 159:1111112211111111111111111111111111111111111111111111111111111111
-- 160:bbbffffbbbffffffbbffffffbfffbbbfbffbbbbbfffbbbbbfffbbbbfffffffff
-- 161:bbbbbbbbfbbbbbbbfbbbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbf
-- 162:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbfbbbbbbb
-- 163:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbffbbbbb
-- 164:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 165:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 166:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbfffbbbb
-- 167:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbfffffbbffffffbbfffbbbbb
-- 168:bffbbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbbfffbbbbbffffffb
-- 169:bbffffffbfffffffbfffbbfffffbbbbfffbbbbbbffbbbbbbffbbbbbfffffffff
-- 170:bbbbbbbbfbbbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbb
-- 171:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbf
-- 172:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbfffbbbbffffbbbb
-- 173:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbfffbbbbffffffb
-- 174:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbffbbbbbbffbbfff
-- 175:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 176:ffffffffffbffbbbffbfffbbffbbffbbffbbfffbffbbfffbffbbbfffffbbbbff
-- 177:fbbbbfffbbbbffffbbbbfffbbbbbfffbbbbbfffbbbbbbffffbbbbffffbbbbbff
-- 178:ffffbbbbffffbbbbbbfffbbbbbfffbbbbbffbbbbbffffbbbffffffbbffbfffbb
-- 179:bfffbbbbbbffbbbbbbfffbbbbbbfffbbbbbbfffbbbbbfffbbbbbbfffbbbbbfff
-- 180:bffbbbbfbffbbbffbffbbbfffffbbbffffbbbbffffbbbbffffbbbbfffbbbbbff
-- 181:ffbbbbbbffffbbbfbbffbbffbbbbbbffbbbbbbffbbbbbbffffffbbffffffbbbf
-- 182:fffffbbbfffffbbbfbbfffbbfbbfffbbbbbfffbbffffffbbffffffffffbbbfff
-- 183:bffbbbbbbffbbbbbbfffbbbbbbfffbbbbbbfffbbbbbfffbbffffffbbffffbbbb
-- 184:bbfffffbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbbbbfffbbbbbfffbb
-- 185:ffffffffffffbbbbfffffbbbffbfffbbffbbffbbffbbfffbffbbbfffffbbbbff
-- 186:bbbbffffbbbbffffbbbfffbbbbbffbbbbbbffbbbbbbffbbbfbbffffffbbfffff
-- 187:fbbbbbfffffbbbffbffbbbffbffbbbffbffbbbffffffbbfffffffbbffbfffbbb
-- 188:fffbbbbbfbbbbbbbbbbbbbbbbbbbbbbbfbbbbbbbfbbbbbbbfffffbbbfffffbbb
-- 189:ffffffffffbbbfffffbbbbfffffffffffffffffbffbbbbbbfffffbbbbffffbbb
-- 190:bfffffffbfffffbbbfffbbbbbfffbbbbbffbbbbbbffbbbbbbffbbbbbbffbbbbb
-- 191:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee222eeeee222222ee
-- 192:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 193:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 194:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 195:bbbbbbffbbbbbfffbbbbffffbbbbfffbbbbfffbbbbfffbbbbbfffbbbbbbbbbbb
-- 196:fbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 197:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 198:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 199:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 200:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 201:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 202:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 203:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 204:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 205:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 206:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 207:2222222222222222222222222222222222222222222222221122222211112222
-- 208:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 209:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 210:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 211:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 212:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 213:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 214:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 215:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 216:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 217:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 218:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 219:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 220:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 221:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 222:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- 223:1111112211111111111111111111111111111111111111111111111111111111
-- 224:1116611111611611111116111111611111166111111111111116611111166111
-- 225:1116611111611611111116111111611111166111111111111116611111166111
-- 226:1116611111611611111116111111611111166111111111111116611111166111
-- 227:1116611111611611111116111111611111166111111111111116611111166111
-- 228:1116611111611611111116111111611111166111111111111116611111166111
-- 229:1116611111611611111116111111611111166111111111111116611111166111
-- 230:1116611111611611111116111111611111166111111111111116611111166111
-- 231:1116611111611611111116111111611111166111111111111116611111166111
-- 232:1116611111611611111116111111611111166111111111111116611111166111
-- 233:1116611111611611111116111111611111166111111111111116611111166111
-- 234:1116611111611611111116111111611111166111111111111116611111166111
-- 235:1116611111611611111116111111611111166111111111111116611111166111
-- 236:1116611111611611111116111111611111166111111111111116611111166111
-- 237:1116611111611611111116111111611111166111111111111116611111166111
-- 238:0000000022200000222220002222222022222222222222222222222222222222
-- 239:0000ffff000003ff0000030f0000000f00000000200000002200000022200000
-- 240:1116611111611611111116111111611111166111111111111116611111166111
-- 241:1116611111611611111116111111611111166111111111111116611111166111
-- 242:1116611111611611111116111111611111166111111111111116611111166111
-- 243:1116611111611611111116111111611111166111111111111116611111166111
-- 244:1116611111611611111116111111611111166111111111111116611111166111
-- 245:1116611111611611111116111111611111166111111111111116611111166111
-- 246:1116611111611611111116111111611111166111111111111116611111166111
-- 247:1116611111611611111116111111611111166111111111111116611111166111
-- 248:1116611111611611111116111111611111166111111111111116611111166111
-- 249:1116611111611611111116111111611111166111111111111116611111166111
-- 250:1116611111611611111116111111611111166111111111111116611111166111
-- 251:1116611111611611111116111111611111166111111111111116611111166111
-- 252:1116611111611611111116111111611111166111111111111116611111166111
-- 253:1116611111611611111116111111611111166111111111111116611111166111
-- 254:2222222222222222222222222222222222222222222222222222222222222222
-- 255:2222000022220000222220002222220022222200222222202222222022222220
-- </SPRITES>

-- <MAP>
-- 000:414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 001:414141414141414141414141414040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 002:414141414141414141404040404040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414040404040404040404040404040404040404040404040404040404040404040101010101010101010101010101010101010101010101010101010101010101010101010414141414141414141414141
-- 003:414141414141414140404040404040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141404040404040404040404040404040404040404040404040404040404040404040404040404040101010101010101010101010101010101010101010101010101010101010101010101010101010104141414141414141
-- 004:414141414141404040404040404040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141404040404040404040404040404040404040404040404040404040404040404040404040404040404040101010101010101010101010101010101010101010101010101010101010101010101010101010101010414141414141
-- 005:4141414141414040404040404040404040404040404040404040404040404040404040404040404010101010101010101010101010101010101010101010101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141404040404040404040404040404040404040408b4040404040404040404040404040404040404040404040101010101010101010101010101010101010101010101010101010101010101010101010101010101010101041414141
-- 006:4141414141404040404040404040404040404040404040404040404040404040404040404040404010101010101010101010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404040404040404040404040404040404040404040404040409b4040404040404040404040330910101010101010101010101010101010101010101010191010101010101010101010101010101010101010414141
-- 007:41414141404040404040404040404040409b40404040404040404040404040ab40404040404040403309101010101010101010101010101010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414040404040404040404040404040404040404040404040404040404040404040404040404040404040404040101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010414141
-- 008:4141414040404040404040404040404040404040404040404040404040404040404040404040404010101010101010101010101010101010101010101010101010101010101910101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414040404040407b4040404040404040404040404040404040404040404040404040404040404040404040404040101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010104141
-- 009:414141404040404040404040404040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010104141
-- 010:414140408140404040404040404040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040101010101010101010101010101010101010101010101010101010101010101010101010291010101010101010104141
-- 011:414140404040404040404040404040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414040404040404040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010101010101010101010101041
-- 012:414140404040404040404040404040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414040404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101010101010101010101041
-- 013:414040404040404040404040404040404040404040404040404040404040404040404040404040401010101010101010101010101010101010101010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141404040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010101041
-- 014:414040404040404040404040404040404040404040404141414141414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010101010101041
-- 015:414040404040404040404040404040404040404141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010101041
-- 016:4140404040408b4040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141404040406b40404040404141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010101041
-- 017:414040404040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141404040404040404040404141414141414141414141414141414141414141411010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010101041
-- 018:414040404040404040404040404040414141414141414141414141414141414141414141414141414141303030303030303030304141414141414141414141414141414141414110101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404040414141414141414141414141414141414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141101010101010391010101041
-- 019:414040404040404040404040404041414141414141414141414141414141414141414141414141413030303030303030303030303030304141414141414141414141414141414141101010101010102910101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404040414141414141414141414141414141414110101010101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101041
-- 020:414040404040404040404040404141414141414141414141414141414141414141414141413030303030303030303030303030303030303041414141414141414141414141414141411010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404040414141414141414141414141414141101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101041
-- 021:414040404040404040404040404141414141414141414141414141414141414141414141303030303030303030303030303030303030303030414141414141414141414141414141414110101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414141414141414110101010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141411010101010101010101041
-- 022:414040404040404040404040414141414141414141414141414141414141414141414130303030303030303030306a30303030303030303030303041414141414141414141414141414110101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414141414141411010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141411010101010101010101041
-- 023:414040404040404040404040414141414141414141414141414141414141414141303030303030303030303030303030303030303030303030303030414141414141414141414141414141101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414141414141101010101010101010101010101010101010101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141411010101010101010101041
-- 024:414040404040404040404040414141414141414141414141414141414141414130303030303030303030303030303030303030303030303030303030304141414141414141414141414141101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414141414110101010101010101010101010101010101010101010101099101010101010101010101041414141414141414141414141414141414141414141414141414141411010101010101010101041
-- 025:414040404040404040404040414141414141414141414141414141414141413030303030303030303030303030303030303030303030303030303030304141414141414141414141414141101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414141411010101010101010101010101010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141411010101010101010101041
-- 026:41404040404040404040404041414141414141414141414141414141414130303030303030303030303030303030303030303030303030305a303030303041414141414141414141414141101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414141101010101010101010101010101010101010101010101010101010101010101010101010101010104141414141414141414141414141414141414141414141414141414110101010101010101041
-- 027:414040404040404040404040414141414141414141414141414141414130303030303030303030303030303030304130303030303030303030303030303041414141414141414141414141101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414141101010101010101010101010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414110101010101010101041
-- 028:4140404040404040404040404141414141414141414141414141414130303030307a303030303030303041414141414141414141303030303030303030303041414141414141414141414110101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414040405b404040404041414141414141414141101010101010a91010101010101010101010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414110101010101010101041
-- 029:414040404040404040404040414141414141414141414141414141303030303030303030303030304141414141414141414141414141303030303030303030304141414141414141414141101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414110101010101010101010101010101010101010101010101010101010101010101010101010101010101010104141414141414141414141414141414141414141414141414110101010101010101041
-- 030:414040404040404040404040414141414141414141414141414130303030303030303030303030414141414141414141414141414141413030303030303030304141414141414141414141101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141414110101010101010101010101010101010101010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414110101010101010101041
-- 031:414040404040404040404040414141414141414141414141414130303030303030303030303041414141414141414141414141414141414130303030303030304141414141414141414141101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141411010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414110101010101010101041
-- 032:414040404040404040404040414141414141414141414141413030303030303030303030304141414141414141414141414141414141414141303030303030303041414141414141414141411010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141411010101010101010101010101010101010414141414141414141414141414141411010101010101089101010101010104141414141414141414141414141414141414141414110101010491010101041
-- 033:414040404040404040404040414141414141414141414141413030303030303030303030414141414141414141414141414141414141414141303030303030303030414141414141414141411010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141411010101010101010101010101010101041414141414141414141414141414141414141101010101010101010101010104141414141414141414141414141414141414141414110101010101010101041
-- 034:414040404040404040404040414141414141414141414141303030303030303030303030414141414141414141414141414141414141414141413030303030303030414141414141414141411010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141101010101010101010101010101010414141414141414141414141414141414141414141411010101010101010101010101041414141414141414141414141414141414141414110101010101010101041
-- 035:414040404040404040404040414141414141414141414141303030303030303030303041414141414141414141414141414141414141414141413030303030303030414141414141414141414110101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141101010101010101010101010101041414141414141414141414141414141414141414141414110101010101010101010101010414141414141414141414141414141414141414110101010101010101041
-- 036:41404040407b404040404040414141414141414141414141303030303030303030303041414141414141414141414141414141414141414141414130303030303030304141414141414141414110101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141101010101010101010101010104141414141414141414141414141414141414141414141414141101010101010101010101010104141414141414141414141414141414141414110101010101010101041
-- 037:4140404040404040404040404141414141414141414141413030303030303030303030414141414141414141414141414141414141414141414141303030304a3030304141414141414141414110101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414141101010101010101010101010104141414141414141414141414141414141414141414141414141411010101010101010101010101041414141414141414141414141414141414110101010101010101041
-- 038:414040404040404040404040414141414141414141414141303030308a30303030304141414141414141414141414141414141414141414141414141303030303030303041414141414141414141101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141411010101010101010101010101010414141414141414141414141414141414110101010101010101041
-- 039:414040404040404040404040414141414141414141414141303030303030303030304141414141414141414141414141414141414141414141414141303030303030303041414141414141414141101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414110101010101010101010101010101041414141414141414141414141414110101010101010101041
-- 040:414040404040404040404040414141414141414141414141303030303030303030304141414141414141414141414141414141414141414141414141303030303030303041414141414141414141101010101039101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414110101010101010101010101010101010414141414141414141414141411010101010101010101041
-- 041:414040404040404040404040414141414141414141414141303030303030303030304141414141414141414141414141414141414141414141414141413030303030303030414141414141414141411010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141101010101010101010101010101010104141414141414141414141411010101010101010101041
-- 042:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141413030303030303030414141414141414141414110101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141101010101010101079101010101010101041414141414141414141101010101010101010101041
-- 043:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141413030303030303030304141414141414141414110101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010101010104141414141411010101010101010591010101041
-- 044:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414130303030303030304141414141414141414141101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010101010101010101010101010101010101010101010101041
-- 045:41404040404040404040404041414141414141414141414130303030303030303041414141414141414141414141414141414141414141414141414141413030303030303030304141414141414141414141411010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414040404b404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141414110101010101010101010101010101010101010101010101010101010101010101010101041
-- 046:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414130303030303030303041414141414141414141414141101010101010101010101049101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141101010101010101010101010101010101010101010101010101010101010101010101041
-- 047:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141303030303030303030414141414141414141414141411010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414140404040404040404041414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010101010101010101010101010101010101010101041
-- 048:4140404040404040404040404141414141414141414141413030303030303030304141414141414141414141414141414141414141414141414141414141413030303030303030304141414141414141414141414141101010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141404040404040404040414141414141101010101010b9101010101010414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010101010691010101010101010101010101010104141
-- 049:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141303030303030303030414141414141414141414141414141411010101010101010101010101010101010101010101010101010101041414141414141414141414141414141414141414141414141414140404040404040404041414141414141101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010101010101010101010101010101010101010101010414141
-- 050:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141303030303030303030304141414141414141414141414141414141411010101010101010101010101010101010101010101010101010104141414141414141414141414141414141414141414141414140404040404040404041414141414141101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101010101010101010101010101010101010101010414141
-- 051:4140404040404040404040404141414141414141414141413030303030303030304141414141414141414141414141414141414141414141414141414141414130303030303a3030304141414141414141414141414141414141414141411010101010101010101010101010101010101010101010101010414141414141414141414141414141414141414141414140404040404040404041414141414141101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010101010101010101010101010101041414141
-- 052:4140404040404040404040404141414141414141414141413030309a3030303030414141414141414141414141414141414141414141414141414141414141413030303030303030303041414141414141414141414141414141414141414141101010101010101010101010101010101059101010101010104141414141414141414141414141414141414141414140404040404040404041414141414141101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010101010101010101010101010101010414141414141
-- 053:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141413030303030303030303041414141414141414141414141414141414141414141414141411010101010101010101010101010101010101010101041414141414141414141414141414141414141414140404040404040404041414141414141411010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010101010101010101010104141414141414141
-- 054:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414130303030303030303030414141414141414141414141414141414141414141414141414141414141414141101010101010101010101010101010414141414141414141414141414141414141414140404040404040404041414141414141411010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101010101010104141414141414141414141
-- 055:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414130303030303030303030414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101010104141414141414141414141414141414141414140404040404040404041414141414141414110101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010414141414141414141414141414141
-- 056:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010101041414141414141414141414141414141414140404040404040404041414141414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 057:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141303030303030303030304141414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101010414141414141414141414141414141414140404040404040404041414141414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 058:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141303030303030303030304141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010414141414141414141414141414141414140404040404040404041414141414141414110101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 059:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141413030303030303030304141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010414141414141414141414141414141414140404040404040404040414141414141414110101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 060:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141413030303030303030303041414141414141414141414141414141414141414141414141414141414141414141414141414110101010101010101010104141414141414141414141414141414140404040403b40404040414141414141414141101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 061:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141413030303030303030303041414141414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101041414141414141414141414141414140404040404040404040404141414141414141101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 062:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141413030303030303030303041414141414141414141414141414141414141414141414141414141414141414141414141414141101010101010101010101041414141414141414141414141414140404040404040404040404141414141414141101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 063:4140404040404040404040404141414141414141414141413030303030303030304141414141414141414141414141414141414141414141414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414141414141411010101010106910101010104141414141414141414141414141414040404040404040404040414141414141414110101010101010c9101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 064:4140404040404040404040404141414141414141414141413030303030303030304141414141414141414141414141414141414141414141414141414141414141414141202020202a2020202041414141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010414141414141414141414141414141404040404040404040404041414141414141411010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 065:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010414141414141414141414141414141414040404040404040404040414141414141414110101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 066:41404040406b404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141411010101010101010101010104141414141414141414141414141414040404040404040404040404141414141414110101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 067:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414140404040404040404040404141414141414141101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 068:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414140404040404040404040404141414141414141411010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 069:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141411010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 070:414040404040404040404040414141414141414141414141303030aa3030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141414110101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 071:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141414110101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 072:4140404040404040404040404141414141414141414141413030303030303030304141414141414141414141414141414141414141414141414141414141414141414141202020202020202020414141414141414141414141414141414141414141414141414141414141414141414141414141414120202020202020202020202041414141414141414141414141414141414040404040402b4040404041414141414141414110101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 073:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141414141101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 074:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141414141411010101010101010d91010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 075:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141414141411010101010101010101010101010101010414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 076:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020201a20202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141414141414110101010101010101010101010101010104141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 077:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020207920202020204141414141414141414141414141414141404040404040404040404041414141414141414141414141101010101010101010101010101010101041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 078:414040404040404040404040414141414141414141414141303030303030303030414141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141414141414141411010101010101010101010101010101020414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 079:414040404040404040404040414141414141414141414141303030303030303030304141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414141404040404040404040404041414141414141414141414141414110101010101010101010101010202020414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 080:414040404040404040404040414141414141414141414141303030303030303030304141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414140404040404040404040404041414141414141414141414141414110101010101010101010101020202020204141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 081:414040404040404040404040414141414141414141414141413030303030303030304141414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414140404040404040404040404041414141414141414141414141414141101010101010101010102020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 082:414040404040404040404040414141414141414141414141413030303030303030303041414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141414040404040404040404040404041414141414141414141414141414141101010101010101020202020202020202020414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 083:414040404040404040404040414141414141414141414141413030303030303030303041414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141404040404040404040404040404141414141414141414141414141414141411010101010102020202020202020202020204141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 084:414040404040404040404040414141414141414141414141413030303030303030303030414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414141404040404040404040404040404141414141414141414141414141414141414110101010202020202020202020202020202020414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 085:4140404040404040404040404141414141414141414141414130303030ba303030303030414141414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141418941414141414141414141412020202020202020202020204141414141414141414141414140404040401b40404040404040414141414141414141414141414141414141414141101020202020202020202020202020202020202020202020202020202020202020202020414141414141414141414141414141414141414141414141414141
-- 086:41404040404040404040404041414141414141414141414141413030303030303030303030414141414141414141414141414141414141414141414141414141414141412020202020202020204141414141414141414141414141414141414141414141414141414141414141414141414141414141202020202020202020202020414141414141414141414141404040404040404040404040404041414141414141414141414141414141414141414141202020202020e920202020202020202020202020202020202020202020202020202020202020414141414141414141414141414141414141414141414141
-- 087:414040404040404040404040414141414141414141414141414130303030303030303030303041414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141414040404040404040404040404041414141414141414141414141414141414141414141414120202020202020202020202020202020202020202020202020202020202020202020202020202020414141414141414141414141414141414141414141
-- 088:414040404040404040404040414141414141414141414141414130303030303030303030303030414141414141414141414141414141414141414141414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141414141303040404040404040404040404141414141414141414141414141414141414141414141414141202020202020202020202020202020202020202020202020202020202020202020202020202020202020414141414141414141414141414141414141
-- 089:4140404040404040404040404141414141414141414141414141413030303030303030303030303030303030303030303030303030303030304141414141414141414141202020202020202020414141414141414141414141414141414141414141414141414141414141414141414141414141414120202020202020202020202041414141414141414141303030304040404040404040404041414141414141414141414141414141414141414141414141414120202020202020202020202020f920202020202020202020200a202020202020202020202020202020202020414141414141414141414141414141
-- 090:414040404040404040404040414141414141414141414141414141413030303030303030303030303030303030303030303030303030303030303030414141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141413030303030304040404040404040414141414141414141414141414141414141414141414141414141414120202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020414141414141414141414141
-- 091:414040405b40404040404040414141414141414141414141414141413030303030303030303030303030303030303030303030303030303030303030304141414141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141413030303030303030404040404041414141414141414141414141414141414141414141414141414141414141202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202041414141414141414141
-- 092:414040404040404040404040414141414141414141414141414141414130303030303030303030303030303030303030303030303030303030303081303030414141414120202020200a20202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020208920202020204141414141414141303030303030303030303040404141414141414141414141414141414141414141414141414141414141414141412020202020202020202020202020202020202020202020202020202020202020202020201a20202020202020202020204141414141414141
-- 093:41404040404040404040404041414141414141414141414141414141414130303030303030ca30303030303030303030303030303030303030303030303030304141414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414141303030303030303030303030414141414141414141414141414141414141414141414141414141414141414141414141202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202041414141414141
-- 094:414040404040404040404040414141414141414141414141414141414141413030303030303030303030303030303030303030303030303030303030303030303041414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414130303030303030303030303030414141414141414141414141414141414141414141414141414141414141414141414141414120202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020414141414141
-- 095:4140404040404040404040404141414141414141414141414141414141414141303030303030303030303030303030303030da303030303030303030303030303041414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141414130303030303030303030303041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414120202020202020202020202020202020202020202020202020202020414141414141
-- 096:414040404040404040404040414141414141414141414141414141414141414141303030303030303030303030303030303030303030303030303030303030303030414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141413030303030303030303030304141414141414141414141414141414141414130303030303030303030303030303030304141414141414141414141414141414141414141414141412020202020202020202020202020202020202020202020202020204141414141
-- 097:414040404040404040404040414141414141414141414141414141414141414141413030303030303030303030303030303030303030303030303030303030303030414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141413030303030303030303030304141414141414141414141414141414130303030303030303030303030303030303030303030304141414141414141414141414141414141414141414141202020202020202020202020202020202020202020202020202041414141
-- 098:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141303030303030303030303030303030414120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141413030303030303030303030414141414141414141414141414141303030303030303030303030303030303030303030303030303041414141414141414141414141414141414141414141412020202020202020202020202020202020202a20202020202041414141
-- 099:41404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030ea3030303030412020202020202020204141414141414141414141414141414141414141414141414141414141414141414141414141414141202020202020202020202020414141414130303030303030303030304141414141414141414141414141303030303030303030303030303030aa30303030303030303030303030414141414141414141414141414141414141414141414120202020202020202020202020202020202020202020202020414141
-- 100:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141303030303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414141303030303030303030303041414141414141414141414141303030303030303030303030303030303030303030303030303030303030304141414141414141414141414141414141414141414141412020202020202020202020202020202020202020202020414141
-- 101:4140404040404040404040404141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030303041202020202020202020414141414141414141414141414141414141414141414141414141414141414141414141414141414120202020202020202020202041414141413030300b3030303030303041414141414141414141414130303030303030303030303030303030303030303030303030303030303030303041414141414141414141414141414141414141414141414120202020202020202020202020202020202020202020204141
-- 102:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141414141413030303030303030303030303030303030303030303030303030303030303030303030414141414141414141414141414141414141414141414141202020202020202020202020202020202020202020204141
-- 103:4140404040404040404040404141414141414141414141414141414141414141414141414141414141414141414141414141414141414141303030303030303030303041202020202020202020414141414141414141414141414141414141414141414141414141414141414141414141414141414120202020202020202020202041414141303030303030303030303041414141414141414141413030303030ba303030303030303030303030303030303030303030303030303030303030414141414141414141414141414141414141414141414141202020202020202020202020202020202020202020204141
-- 104:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141414130303030303030303030303030303030304141414141413030303030303030303030303030304141414141414141414141414141414141414141414141412020202020202020202020202020202020202020204141
-- 105:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141414130303030303030303030303030303030414141414141414141413030303030303030303030304141414141414141414141414141414141414141414141202020202020202020202020202020202020202020204141
-- 106:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020209920202020204141414130303030303030303030304141414141414141413030303030303030303030303030304141414141414141414141414130303030309a30303030303041414141414141414141414141414141414141414141202020202020202020202020202020202020202020204141
-- 107:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303030303030414141414141414141414141414141303030303030303030303041414141414141414141414141414141414141414141202020202020202020202020202020202020202020204141
-- 108:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303030303041414141414141414141414141414141303030303030303030303030414141414141414141414141414141414141414120202020202020202020202020202020202020202020204141
-- 109:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303030304141414141414141414141414141414141413030303030303030303030304141414141414141414141414141414141412020202020202020202020202020202020203a20202020204141
-- 110:41404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030303030412020f920202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303030414141414141414141414141414141414141413030303030303030303030303041414141414141414141414141414141202020202020202020202020202020202020204a20202020204141
-- 111:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030fa3030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303030414141414141414141414141414141414141414130303030303030303030303030414141414141414141414141414120202020202020202020202020202020202020205a20202020204141
-- 112:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303041414141414141414141414141414141414141414130303030303030303030303030303041414141414141414141412020202020202020202020202020202020202020202020202020204141
-- 113:414040404b40404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303041414141414141414141414141414141414141414141303030303030303030303030303030304141414141414130202020202020202020202020202020202020202020202020202020204141
-- 114:41404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030303030412020202020202020204141414141414141414141414141414141414141414141414141414141414141414141414141414141202020202020202020202020414141413030303030303030303030414141414141414141303030ca30303030303041414141414141414141414141414141414141414141413030303030303030303030303030303030303030303030202020202020202020202020202020202020202020202020202020414141
-- 115:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303041414141414141414141414141414141414141414141414130303030303030303030303030303030303030303030202020202020202020202020202020202020202020202020202020414141
-- 116:41404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030303030412020202020202020204141414141414141414141414141414141414141414141414141414141414141414141414141414141202020202020202020202020414141413030fa30303030303030304141414141414141413030303030303030303041414141414141414141414141414141414141414141414141303030303030303030303030303030303030303030202020202020202020202020202020202020202020202020202020414141
-- 117:41404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030303030412020202020202020204141414141414141414141414141414141414141414141414141414141414141414141414141414141202020202020202020202020414141413030303030303030303030414141414141414141303030303030303030304141414141414141414141414141414141414141414141414130303030303030303030303030303030303030303020202020202020202020202020202020206a202020202020202041414141
-- 118:4140404040404040404040404141414141414141414141414141414141414141414141414141414141414141414141414141414141414141303030303030303030303041202020202020202020414141414141414141414141414141414141414141414141414141414141414141414141414141414120202020202020202020202041414141303030303030303030303041414141414141414130303030303030303030414141414141414141414141414141414141414141414141414130303030308a3030303030303030303030303030202020202020202020202020202020202020202020202020204141414141
-- 119:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303041414141414141414141414141414141414141414141414141414130303030303030303030303030303030303030202020202020202020202020202020202020202020202020414141414141
-- 120:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030303030304120202020202020202041414141414141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020204141414130303030303030303030304141414141414141413030303030303030303041414141414141414141414141414141414141414141414141414130303030303030303030303030303030303030202020202020202020202020202020202020202020202041414141414141
-- 121:4140404040404040404040404141414141414141414141414141414141414141414141414141414141414141414141414141414141414130303030303030303030303041202020202020202020204141414141414141414141414141414141414141414141414141414141414141414141414141414120202020202020202020202041414141303030303030303030303030414141414141414130303030303030303030414141414141414141414141414141414141414141414141414141413030303030303030303030303030303030307a2020202020202020202020202020202020202020204141414141414141
-- 122:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141303030303030303030303030304120202020202020202020414141414141414141414141414141414141414141414141414141414141414141414141414141202020202020202020202020204141414130303030303030303030303041414141414141413030303030303030303041414141414141414141414141414141414141414141414141414141414130303030303030303030303030303030202020202020202020202020202020202020204141414141414141414141
-- 123:414040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141414141303030303030303030303030304120202020202020202020204141414141414141414141414141414141414141414141414141414141414141414141414141202020202020202020202020204141414130303030303030303030303030414141414141303030303030303030303041414141414141414141414141414141414141414141414141414141414141413030303030303030303030303030202020202020202020202020202020414141414141414141414141414141
-- 124:41404040404040404040404040414141414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030303030303041412020202020202020202020204141414141414141414141414141414141414141414141414141414141414141414141412020202020202020202020202020414141413030303030303030303030303030414141413030303030da30303030303041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 125:414140404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141414141413030303030303030300b30303030414120202020e920202020202020202041414141414141414141414141414141414141414141414141414141414141414120202020202020a9202020202020204141414141303030303030303030303030303030303030303030303030303030303041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 126:414140404040404040404040404040404041414141414141414141414141414141414141414141414141414141414141414141303030303030303030303030303030414141202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020204141414141303030303030303030303030303030303030303030303030303030303041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 127:414141404040403b40404040404040404040404040404040404040404040404040404040404040404040303030303030303030303030303030303030303030303030414141202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020414141414141303030303030303030303030303030303030303030303030303030303041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 128:414141404040404040404040404040404040404040404040404040404040404040404040404040404040303030303030303030303030303030303030303030303030414141412020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020414141414141413030303030303030303030303030303030303030303030303030304141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 129:414141414040404040404040404040404040404040404040404040404040404040404040404040404040303030303030303030303030303030303030303030303041414141412020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020414141414141413030303030303030303030303030303030303030303030303030304141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 130:4141414140408140404040404040404040404040404040404040404040404040404040404040404040403030303030303030303030303030303030303030303030414141414141202020812020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020812020414141414141414141303030303030303030ea303030303030303030303030303030304141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 131:414141414140404040404040404040404040404040404040404040404040404040404040404040404040303030303030303030303030303030303030303030304141414141414141202020202020202020d92020202020202020202020202020c92020202020202020202020202020b92020202020202020202020202020202041414141414141414141413030303030303030303030303030303030303030303030414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 132:4141414141414040404040404040404040404040402b404040404040404040404040404040404040404030303030301b303030303030303030303030813030414141414141414141414120202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202041414141414141414141414130303030303030303030303030303030303030303041414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 133:414141414141414040404040404040404040404040404040404040404040404040404040404040404040303030303030303030303030303030303030303041414141414141414141414141414120202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020204141414141414141414141414141303030303030303030303030303030303030414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 134:414141414141414141414140404040404040404040404040404040404040404040404040404040404040303030303030303030303030303030303030304141414141414141414141414141414141414141202020202020202020202020202020202020202020202020202020202020202020202020202020202020202041414141414141414141414141414141414141303030303030303030303030414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- 135:414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:0f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f00304000000000
-- 001:0f000f00010000000f0000000f0000000f0000000f0000000f0000000f0000000f0000000f0000000f0000000f0000000f0000000f0000000f000000384003000000
-- 002:020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200b05000000000
-- </SFX>

-- <PATTERNS>
-- 059:dff106dff1086ff1068ff1069ff106100000100000dff1086ff1068ff1069ff106100000dff1086ff1069ff1068ff1066ff1069ff1068ff1066ff1069ff1068ff1066ff1064ff1084ff108dff106100000dff106fff1069ff106bff1068ff106fff1066ff106dff1069ff106bff1068ff106fff1066ff106dff1068ff106fff106fff106dff106dff106dff106dff106dff106dff106dff106dff106dff106dff1060000000000000000000000006ff1068ff1069ff1066ff1069ff1066ff106
-- </PATTERNS>

-- <TRACKS>
-- 007:c30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </TRACKS>

-- <SCREEN>
-- 000:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 001:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 002:88f8888888888888888888ff8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888ff888888ff88888888888888888888888888888888888ff8888888888888888888888f888888f888888888888
-- 003:88f888ff88ff888f88888888f88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888f8f88888f8f8888888888888888888888888888888888f888f8f88ff88ff88ff8ff88fff88888f888ff88ff888
-- 004:88f8888ff8f8f8888888888f888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888f8f88888f8f8888888888888888888888888888888888f888f8f8f888f888f8f8f8f88f888888f8888ff8f8f88
-- 005:88f888f8f8f8f88f888888f8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888f8f88888f8f8888888888888888888888888888888888f888f8f8f888f888ff88f8f88f888888f888f8f8f8f88
-- 006:88fff8fff8ff8888888888fff88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888ff888f88ff888888888888888888888888888888888888ff88ff8f888f8888ff8f8f888f88888fff8fff8ff888
-- 007:8888888888f88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888f8888
-- 008:88fff8888888888888888888888f88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888ff88fff88888ff888ff8fff8fff88ff88f88fff888888fff8888888888f88888888888f888888f888888888888
-- 009:8888f88f88ff888ff88f888888ff8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888f8f8f8888888f8f888f888f8f8f888ff88f8f888888f888ff888ff8fff88ff88ff8fff88888f888ff88ff888
-- 010:888f88f8f8f8f8f8f8888888888f888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888f88fff888888f88fff8ff88fff8fff88f88fff888888ff888ff8ff888f88f8f8ff888f888888f8888ff8f8f88
-- 011:88f888f8f8f8f8ff888f8888888f88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888f888f8f8888888f8f8f888f888f8f8f88f88f8f888888f888f8f88ff88f88ff888ff88f888888f888f8f8f8f88
-- 012:88fff88f88f8f88ff888888888fff8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888fff8fff88f88ff88fff8ff8888f8fff8fff8fff888888f888fff8ff8888f88ff8ff8888f88888fff8fff8ff888
-- 013:8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888f8888
-- 014:88fff8ff888ff8888888888f88ff88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 015:88f888f8f8f8888f888888ff8888f8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 016:88ff88ff888f88888888888f888f88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 017:88f888f88888f88f8888888f88f888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 018:88f888f888ff8888888888fff8fff8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 019:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 020:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 021:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 022:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 023:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 024:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 025:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 026:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 027:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 028:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 029:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 030:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 031:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 032:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 033:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 034:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 035:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 036:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 037:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 038:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 039:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 040:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 041:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 042:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 043:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 044:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 045:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 046:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 047:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 048:7777777777777777777777777777777777777777777777777777777777777777777777777777777777777777fff77777ff77ff777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 049:777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777f777f777f777f77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 050:77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777f777f777f777f777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 051:7777777777777777777777777777777777777777777777777777777777777777777777777777777777777777f777f777f777f7777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 052:7777777777777777777777777777777777777777777777777777777777777777777777777777777777777777f7777777fff7fff77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
-- 053:444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
-- 054:444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444434444334
-- 055:444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444434444334444334
-- 056:444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344443444434444334444334
-- 057:4444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444ff44444ff44ff4444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444434443444344443444434444334444334
-- 058:434443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444f44444f444f444f444444444444444444444444444444444444444444444444444444444444444444444444444444444344344444434443444344443444434444334734334
-- 059:434443443444344444444444444444444444444444444444444444444444444444444444444444444444444444444444444444fff44f444f444f4444444444444444444444444444444444444444444444444444444444444444444444444434344344344344444434443444344443473434434334734334
-- 060:434443443444344444444434444444343443444444444444444444444444444444444444444444444444444444444444444444f4f4f444f444f444444444fff44444ff44ff444444444444444444444444444444444444444434444444444434344344344344447434343434343343473434434334734334
-- 061:434443433434344444444434444444343443434343434344443444444444444444444444444444444444444444444444444444fff44444fff4fff4444444f44444f444f444f44444444444444444444444444433444434444434444444444434344344344343447434343434343343473434434334734334
-- 062:4344434334343434434434334434443334433333434343444434434434444333344334444444444444444444444444444444444444444444444444444444ff444f444f444f444444444444444444444444444433444434344734444444444334344344344343447434343434343343473434434334734334
-- 063:434443433434343443443433443444333443333333333344443343433443433334433344444444444444444444444444444444444444444444444444444444f4f444f444f4444444444444444444444444444433443434344734444444444334344344344343437333333333333333373333333333733333
-- 064:4337333333333333333333333333373333333333333333733333434334434333344333434444444444444444444444444444444444444444444444444444ff444444fff4fff44444444444444444444444444433333333333733333333333333333333333333337333333333333333373333333333733333
-- 065:433733333333333333333333333337333333333333333373333333333333333333333333344444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444433333333333733333333333333333333333333337333333333333333373333333333733333
-- 066:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11a1aa1a11a1a1a1a1a1a11444444444444777aa44444777aa444444444444444444444444447ad7a444444444444444444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa1137333333333333333373333333333733333
-- 067:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11a1aa1a11a1a1a1a1a1a11444444444444777aa4444477aaa4447addd7a44444444444444447ad74444444444444444444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 068:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11a1aa1a11a1a1a1a1a1a11444444444444777aaddddd77aa44407add7aa44444444444422227aa7a222444444444444444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 069:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11a1aa1a11a1a1a1a1a1a11444444444444777aadddd777aa22207a2207a222224444444110111111011444444444444444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 070:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11a1aa1a11a1a1a1a1a1a11444444444400777aaddd3377aaa2277aaa77aa222244444444000aa111400444444444444444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 071:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11a1aa1a11a1a1a1a1a1a11444444444400777aaddd3377aaa1111111111111114444444444444444444444444444444444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 072:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11a1aa1a11a1a1a1a1a4444444222222200777aa2220077affffffffffffffffffffffffffffffffffffffffffff4444444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 073:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11a1aa1a114444444444444444222222200777aa2220077affffffffffffffffffffffffffffffffffffffffffff4444444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 074:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa11a61aa11444444444444444444444222222222277777aaaaa7ffffaaaa2222222224444444444444444444444444444444ffff444444444444444444441a1a11a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 075:4aa61111aaa1111aaa111aaa111aa611aa111aa11aa144444444444444444444444444444222222222277777aaaaa7ffffaaaa2222222224444444444444444444444444444444ffff44444444444444444444444411a1aa1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 076:4aa61111aaa1111aaa111aaa111aa611aa11444444444444444444444444444444444444411111111111111111ffff1111111111111111144444444444444444444444444444444444ffff4444444444444444444444444a1fa11aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 077:4aa61111aaa1111aaa111aaa111a44444444444444444444444444444444444444444444411111111111111111ffff1111111111111111144444444444444444444444444444444444ffff4444444444444444444444444444444aa11aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 078:4aa61111aaa1111aaa1114444444444444444444444444444444444444444444444444444111110001111111ff11111111111111ff01111444444444444444444444444444444444444444ff444444444444444444444444444444444aa11aaa11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 079:4aa61111aaa11444444444444444444444444444444444444444444444444444444444444444000000044aaaff11111111114400ff00044444444444444444444444444444444444444444ff444444444444444444444444444444444444444a11aaa111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 080:4aa6114444444444444444444444444444444444444444444444444444444444444444444444000000044affaa11111111114400000000444444444444444444444444444444444444444444ff444444444444444444444444444444444444444444a111aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 081:44444444444444444444444444444444444444444444444444444444444444444444444444440000000444ff4444444444444400000004444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444aaa111faaa1111aaaa11111faaaaa11111faaaaa
-- 082:444444444444444444444444444444444444444444444444444444444444444444444444444400000004ff444444444444444400000004444444444444444444444444ff444444444444444444ff44444444444444444444444444444444444444444444444441faaa1111aaaa11111faaaaa11111faaaaa
-- 083:444444444444444444444444444444444444444444444444444444444444444444444444444444444444ff444444444444444444444444444444444444444444444444ff444444444444444444ff4444444444444444444444444444444444444444444444444444441111aaaa11111faaaaa11111faaaaa
-- 084:44444ffffffffdfffffdffdfffff44444444444444444444444444444444444444444444444444444444ff44444444444444444444444444444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444444444444444aaaa11111faaaaa11111faaaaa
-- 085:4444ffffdfffddd6ffddddddfdfff4444444444444444444444444444444444444444444444444444444ff44444444444444444444444444444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444444444444444444441111faaaaa11111faaaaa
-- 086:444ffffdddfffd666ffdffdfdddfff4444444444444444444444444444444444444444444444444444ff444444444444444444444444444444444444444444444444444444444444444444444444ff44444444444444444444444444444444444444444444444444444444444444444faaaaa11111faaaaa
-- 087:444fdfffdffffff6fffffffffdffff4444444444444444444444444444444444444444444444444444ff444444444444444444444444444444444444444444444444444444444444444444444444ff444444444444444444444444444444444444444444444444444444444444444444444aa11111faaaaa
-- 088:444dddfff444444444444444ffffff4444444444444444444444444444444444444444444444444444ff444444444444444444444444444444444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444444444444444444444444444444411faaaaa
-- 089:444fdff444444444ffff444444fdfff444444444444444444444444444444444444444444444444444ff444444444444444444444444444444444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444444444444444444444444444444444444aaa
-- 090:444dfff4444444fffffff44444dddff4444444444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444444444444444444444444444444444ff44444444444444444444444444444444444444444444444444444444444444444444444444444444
-- 091:44dddf4444444ffffffffff4444dfff4444444444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444444444444444444444444444444444ff44444444444444444444444444444444444444444444444444444444444444444444444444444444
-- 092:444dff444444fffffffffff4444ffff4444444444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444444444444444444444444444444444ff44444444444444444444444444444444444444444444444444444444444444444444444444444444
-- 093:444fff44444ffff444444fff444ffff4444444444444444444444444444444444444444444444444ff4444444444444444444444444444444444444444444444444444444444444444444444444444ff44444444444444444444444444444444444444444444444444444444444444444444444444444444
-- 094:444fff44444fff4444444fff4444fdf4444444444444444444444444444444444444444444444444ff4444ff444444444444444444444444444444444444444444444444444444ff44444444444444ff44444444444444444444444444444444444444444444444444444444444444444444444444444444
-- 095:444fff4444ffff44444444fff444ddd4444444444444444444444444444444444444444444444444ff4444ff444444444444444444444444444444444444444444444444444444ff44444444444444ff44444444444444444444444444444444444444444444444444444444444444444444444444444444
-- 096:444dff4444ffff44444444fff444fdfff44444444444444444444444444444444422222222222222ff4444444444444444ff4444444444444444444444444444444444444444444444444444444444ff22222222222222444444444444444444444444444444444444444444444444444444444444444444
-- 097:44dddf4444fff4444444444ff4444ffffffff4444444444444444444444444444422222222222222ff4444444444444444ff4444444444444444444444444444444444444444444444444444444444ff22222222222222444444444444444444444444444444444444444444444444444444444444444444
-- 098:444dff4444fff4444444444fff4444ffffffffd444444444444444222222222222222222222222ff22224444444444444444444444444444444444444444444444444444444444444444444444442222ff222222222222222222222222444444444444444444444444444444444444444444444444444444
-- 099:444dff4444fff4444444444fff44444ffffffddd44444444444444222222222222222222222222ff22224444444444444444444444444444444444444444444444444444444444444444444444442222ff222222222222222222222222444444444444444444444444444444444444444444444444444444
-- 100:44dddf4444fff44444444444fff4444444ffffdfff222222222222222222222222222222222222ff22222222444444444444444444444444444444444444444444444444444444444444444422222222ff222222222222222222222222222222222222444444444444444444444444444444444444444444
-- 101:444dff4444fff44444444444fff44444444444fffff22222222222222222222222222222222222ff22222222444444444444444444444444444444444444444444444444444444444444444422222222ff222222222222222222222222222222222222444444444444444444444444444444444444444444
-- 102:444fff4444fff44444444444ffff444444442222ffff2222222222222222222222222222222222ff22222222224444444444444444444444444444444444444444444444444444444444442222222222ff222222222222222222222222222222222222222222444444444444444444444444444444444444
-- 103:444fff4444fff444444444444fff4444444422222ffff222222222222222222222222222222222ff22222222224444444444444444444444444444444444444444444444444444444444442222222222ff222222222222222222222222222222222222222222444444444444444444444444444444444444
-- 104:444dff4400fff000000033000fff3300222222222ffff222222222222222222222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022222222222222222222222222222222222222222200330000003300000000000044444444
-- 105:44dddf4400fff000000033000fff33002222222222ffff22222222222222222222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022222222222222222222222222222222222222222200330000003300000000000044444444
-- 106:444dff0000fff000003300000fff22222222222222ffff22222222222222222222220000003333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333300000022222222222222222222222222222222222222222200000033000000000000004444
-- 107:444fff0000fff000003300000fff22222222222222ffff22222222222222222222220000003333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333300000022222222222222222222222222222222222222222200000033000000000000004444
-- 108:440fff0000fff000000000222fff22222222222222ffff22222222222222222200003333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333300002222222222222222222222222222222222222222220000000000000000000044
-- 109:440dff0000fff000000000222fff22222222222222ffff22222222222222222200003333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333300002222222222222222222222222222222222222222220000000000000000000044
-- 110:44dddf00000fff00002222222fff22222222222222ffff22222222222222220033333333333344444444444444444444444444444444444433333333333333334444444444444444444444444444444444443333333333330022222222222222222222222222222222222222222222000000000000000044
-- 111:440dff00000fff00002222222fff22222222222222ffff22222222222222220033333333333344444444444444444444444444444444444433333333333333334444444444444444444444444444444444443333333333330022222222222222222222222222222222222222222222000000000000000044
-- 112:000dff00000ffff0222222222fff22222222222222ffff22222222111111003333333344444444444444449944444444444444444444333377777777777777773333444444444444444444444444444444444444443333333300111111222222222222222222222222222222222222220000000000000000
-- 113:00dddf000000ffffffffff222fff22222222222222ffff22222222111111003333333344444444444444449944444444444444444444333377777777777777773333444444444444444444444444444444444444443333333300111111222222222222222222222222222222222222220000000000000000
-- 114:000dff000000ffffffffffff2fff22222222222222ffff22221111111111003333444444444444444444449944444444444444444433777777333377773333777777334499444444444444449944444444444444444444333300111111111122222222222222222222222222222222222233000000000000
-- 115:000fff0000003fffffffffff2fff22222222222222ffff22221111111111003333444444444444444444449944444444444444444433777777333377773333777777334499444444444444449944444444444444444444333300111111111122222222222222222222222222222222222233000000000000
-- 116:000fff33003322222222ffffffff22222222222222ffff11111111111100333333444444444400330044444499444444000000003377777733444433334444337777773344994444444444444499444499444444444444333333001111111111111122222222222222222222222222222222330033000000
-- 117:000dff330033222222222fffffff22222222222222ffff11111111111100333333444444444400330044444499444444000000003377777733444433334444337777773344994444444444444499444499444444444444333333001111111111111122222222222222222222222222222222330033000000
-- 118:00dddf000022222222222fffffff22222222222211ffff11111111111100333344444444440000330000444444444477000000003377777733444433334444337777773344994444444444444499444499444444449944443333001111111111111111112222222222222222222222222222220000330000
-- 119:000dff000022222222222fffffff22222222222211ffff11111111111100333344444444440000330000444444444477000000003377777733444433334444337777773344994444444444444499444499444444449944443333001111111111111111112222222222222222222222222222220000330000
-- 120:000fff002222222222222fffffff22222222111111ffff11111111111100333344444444000000330000004444444400007777337777777733444433334444337777777733444444444444444444449944444444449944443333001111111111111111111111222222222222222222222222222200000000
-- 121:000fdf002222222222222fffffff22222222111111ffff11111111111100333344444444000000330000004444444400007777337777777733444433334444337777777733444444444444444444449944444444449944443333001111111111111111111111222222222222222222222222222200000000
-- 122:003ddd222222222222222fffffff22221111111111ffff11111111110033333344444444000006630000004444444477007777337733333344444433334444443333337733444444444444444444444444444444444499443333330011111111111111111111111122222222222222222222222222003300
-- 123:003fdf222222222222222fffffff22221111111111ffff11111111110033333344444444000666330000004444444477007777337733333344444433334444443333337733444444444444444444444444444444444499443333330011111111111111111111111122222222222222222222222222003300
-- 124:330fff22222222222222fffffffff111111111111fffff11111111110033334444994444066600000000004499444400007733773377004444444433334444444444443377334444444444449944444444444444444444444433330011111111111111111111111111112222222222222222222222220033
-- 125:330fffdf2222d2222d2fffff2fffffffffffffffffffff11111111110033334444994444660000000000004499444400007733773377004444444433334444444444443377334444444444449944444444444444444444444433330011111111111111111111111111112222222222222222222222220033
-- 126:0022fdddfffdddffdddfffff22fffffffffffffffffff111111111110033334444994444440000000000444444994477007733773377004444444433339944444444993377334444444444444499444444444444994444444433330011111111111111111111111111111122222222222222222222222200
-- 127:0022ffdfffffdffffdfffff2221ffffffffffffffffff111111111110033334444994444440000000000444444994477007733773377004444444433339944444444993377334444444444444499444444444444994444444433330011111111111111111111111111111122222222222222222222222200
-- 128:222222222222222222222222111111111111111111111111111111110033334444449944444400000044444444994400003377777733333333333377773333333333337777773399444444444499444444444444449944444433330011111111111111111111111111111111222222222222222222222222
-- 129:222222222222222222222222111111111111111111111111111111110033334444449944444400000044444444994400003377777733333333333377773333333333337777773399444444444499444444444444449944444433330011111111111111111111111111111111222222222222222222222222
-- 130:2ff22222222222f222f222f111111111111111111ff11ff111111ff10ff3334444444444444444449944444444444477003377777777777777777777777777777777777777773344994444444444444444444444449944444433330011111111111111111111111111111111112222222222222222222222
-- 131:2f2f22f222ff22222fff221111f11ff111f11111111f111f111f111f003f334444444444444444449944444444444477003377777777777777777777777777777777777777773344994444444444444444444444449944444433330011111111111111111111111111111111112222222222222222222222
-- 132:2ff22f2f2ff222f222f211f11f1f1f1f1111111111f111f111f111f100f3334444444444444444449944444444444444003377777777777777777733337777777777777777773344994444444444444444444444444444444433330011111111111111111111111111111111111122222222222222222222
-- 133:2f222f2f22ff22f222f211f11f1f1f1f11f111111f111f111f111f110f33334444444444444444449944444444444444003377777777777777777733337777777777777777773344994444444444444444444444444444444433330011111111111111111111111111111111111122222222222222222222
-- 134:2f2222f22ff222f2221f11f111f11f1f111111111fff1fff11111fff0fff334444444444444444444444444444444444443377777777777777773333333377777777777777773344444444444444444444444444444444444433330011111111111111111111111111111111111111222222222222222222
-- 135:222222222222222222111111111111111111111111111111111111110033334444444444444444444444444444444444443377777777777777773333333377777777777777773344444444444444444444444444444444444433330011111111111111111111111111111111111111222222222222222222
-- </SCREEN>

-- <PALETTE>
-- 000:140c1c44243430346d4e4a4e854c30346524d04648757161597dced27d2c8595a16daa2cd2aa996dc2cadad45edeeed6
-- </PALETTE>

