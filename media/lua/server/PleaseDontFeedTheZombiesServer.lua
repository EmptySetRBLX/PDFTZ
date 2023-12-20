require "DeadBodyUtils"

function MINS_TO_WAIT_BEFORE_CORPSE_DELETION_WHEN_EATEN()
	return getSandboxOptions():getOptionByName("PDFTZ.MaxTimeToEatBody"):getValue()
end
local MAX_TICKS_TO_WAIT_FOR_CORPSE = 400

local ZOMBIE_KILLED_CORPSE_SEARCH_RANGE = 3
local ZOMBIE_KILLED_CORPSE_SEARCH_DEPTH = 1

function DRAW_AREA_PER_NEARBY_CORPSE()
	return getSandboxOptions():getOptionByName("PDFTZ.CorpseDrawWeight"):getValue()
end

function MIN_HORDE_DRAW()
	return getSandboxOptions():getOptionByName("PDFTZ.MinHordeDrawWeight"):getValue()
end

local NEARBY_CORPSE_HORDE_SEARCH_RANGE = 7
local NEARBY_CORPSE_HORDE_SEARCH_DEPTH = 1

local NEARBY_CORPSE_AI_SEARCH_RANGE = 7
local NEARBY_CORPSE_AI_SEARCH_DEPTH = 0

function MIN_MINUTES_BETWEEN_SUMMONS()
	return getSandboxOptions():getOptionByName("PDFTZ.HordeGlobalCooldown"):getValue()
end

function MIN_MINUTES_BEFORE_HOARD()
	return getSandboxOptions():getOptionByName("PDFTZ.MinHordeDrawWaitTime"):getValue()
end
function MAX_MINUTES_BEFORE_HOARD()
	return getSandboxOptions():getOptionByName("PDFTZ.MaxHordeDrawWaitTime"):getValue()
end

function ARE_HORDES_ON()
	return getSandboxOptions():getOptionByName("PDFTZ.HordesEnabled"):getValue()
end
function SPOOKY_SCARY_SKELETONS()
	return getSandboxOptions():getOptionByName("PDFTZ.SpookyScarySkeletons"):getValue()
end

local deferedDeadBodyChecks = {}
local deferedDeadBodyDeletions = {}

function OnZombieKilled(zombie)
	if not ARE_HORDES_ON() then
		return
	end
	local square = zombie:getCurrentSquare()
	deferedDeadBodyChecks[#deferedDeadBodyChecks+1] = {
		squares = bodyUtils.getSurroundingSquares(square, ZOMBIE_KILLED_CORPSE_SEARCH_RANGE, ZOMBIE_KILLED_CORPSE_SEARCH_DEPTH),
		attemptsLeft = MAX_TICKS_TO_WAIT_FOR_CORPSE
	}
end

local function sendDeleteBodyEvent(objectId)
	sendServerCommand("PDFTZ", "DeleteBody", {id = objectId})
end

local function drawZombiesToBody(body)
	local square = body:getSquare()
	local squaresToCheck = bodyUtils.getSurroundingSquares(square, NEARBY_CORPSE_HORDE_SEARCH_RANGE, NEARBY_CORPSE_HORDE_SEARCH_DEPTH)
	local bodies = bodyUtils.getDeadBodiesInSquares(squaresToCheck)

	local area = #bodies * DRAW_AREA_PER_NEARBY_CORPSE()
	local radius = math.sqrt(a/math.pi)

	if radius < MIN_HORDE_DRAW() then
		return false
	end

	local volume = radius

	local x = body:getX()
	local y = body:getY()
	local z = body:getZ()

	local worldSoundManager = getWorldSoundManager()
	worldSoundManager:addSound(nil, x, y, z, radius, volume)
	return true
end

local bodyIds = {}

local function isBodyInWorld(body)
	local square = body ~= nil and body:getSquare()

	if square ~= nil then
		return square:getDeadBodys() ~= nil and square:getDeadBodys():contains(body)
	end

	return false
end

local function runDeferedBodyChecks()
	local newChecks = {}

	for _, bodyCheckData in pairs(deferedDeadBodyChecks) do
		local foundNewBodies = false

		if bodyCheckData.attemptsLeft % 100 == 0 then
			local squares = bodyCheckData.squares
			local bodies = bodyUtils.getDeadBodiesInSquares(squares)

			if #bodies > 0 then
				for k=1, #bodies do
					local body = bodies[k]

					if not bodyIds[body:getObjectID()] then
						foundNewBodies = true
						bodyIds[body:getObjectID()] = {
							body = body,
							minutesToHoard = ZombRand(MIN_MINUTES_BEFORE_HOARD(), MAX_MINUTES_BEFORE_HOARD)
						}
						print("Found a new body")
						break
					end
				end
			end
		end

		if not foundNewBodies then
			bodyCheckData.attemptsLeft = bodyCheckData.attemptsLeft - 1
			if bodyCheckData.attemptsLeft > 0 then
				newChecks[#newChecks + 1] = bodyCheckData
			else
				print("A body check completely failed (someone picked up and dropped a skeleton probably)")
			end
		end
	end
	
	deferedDeadBodyChecks = newChecks
end

local lastSummonTime = 0

local lastRunTime = getGameTime():getMinutesStamp()

local function attemptToDrawZombiesToCorpses()
	currentTime = getGameTime():getMinutesStamp()
	
	local deltaTime = currentTime - lastRunTime
	lastRunTime = currentTime

	if currentTime < lastSummonTime + MIN_MINUTES_BETWEEN_SUMMONS() then
		return
	end

	local idsToDrawHordeTo = {}
	for objectId, bodyData in pairs(bodyIds) do
		bodyData.minutesToHoard = bodyData.minutesToHoard - deltaTime
		if bodyData.minutesToHoard <= 0 then
			bodyData.minutesToHoard = ZombRand(MIN_MINUTES_BEFORE_HOARD(), MAX_MINUTES_BEFORE_HOARD)
			idsToDrawHordeTo[#idsToDrawHordeTo+1] = objectId
		end
	end

	if #idsToDrawHordeTo > 0 then
		for i=1, #idsToDrawHordeTo do
			local idToTry = idsToDrawHordeTo[i]
			local body = bodyIds[idToTry].body
			if not isBodyInWorld(body) then
				print("Tried to draw horde but could not find body of id " .. idToTry)
				bodyIds[idToTry] = nil
			elseif body:isSkeleton() then
				print("Tried to draw horde to skeleton, skipping")
				bodyIds[idToTry] = nil
			else
				if drawZombiesToBody(body) then
					print("horde drawn to body")
					drawZombiesToBody(body)
					lastSummonTime = currentTime
					break
				else
					print("Tried to draw a horde but not enough corpses nearby")
				end
			end
		end		
	end
end

local function makeSkeleton(body)
	local square = body:getSquare()
	local direction = body:getDir()
	local fallOnFront = body:isFallOnFront()

	local skeletonTemplate = addZombiesInOutfit(square:getX(), square:getY(), square:getZ(), 1, nil, 0, false, fallOnFront, false, true, 0.5)
	skeletonTemplate = skeletonTemplate:get(0)
	skeletonTemplate:setSkeleton(true)
	skeletonTemplate:setCurrent(square)
	skeletonTemplate:setDir(direction)

	return skeletonTemplate
end

local function makeSkeletonBody(body)
	local square = body:getSquare()
	local direction = body:getDir()
	local fallOnFront = body:isFallOnFront()

	local skeletonTemplate = addZombiesInOutfit(square:getX(), square:getY(), square:getZ(), 1, nil, 0, false, fallOnFront, false, true, 0.5)
	skeletonTemplate = skeletonTemplate:get(0)
	skeletonTemplate:setSkeleton(true)
	skeletonTemplate:setCurrent(square)
	skeletonTemplate:setDir(direction)
	skeletonTemplate:removeFromWorld()

	return IsoDeadBody.new(skeletonTemplate, false)
end

local lastBodyDeletionTick = getGameTime():getMinutesStamp()

local function runDeferedBodyDeletions()
	local remainingDeferedDeletions = {}
	local time = getGameTime():getMinutesStamp()
	local dt = time - lastBodyDeletionTick
	lastBodyDeletionTick = time

	for body, deferedDeletion in pairs(deferedDeadBodyDeletions) do
		if deferedDeletion.eatTimeRemaining > 0 then
			if body:getEatingZombies() ~= nil and body:getEatingZombies():size() > 0 then
				deferedDeletion.eatTimeRemaining = deferedDeletion.eatTimeRemaining - (dt * body:getEatingZombies():size())
			end
			remainingDeferedDeletions[body] = deferedDeletion
		else
			if isBodyInWorld(body) and body:getEatingZombies():size() > 0 then
				local newContainer = nil
				if not SPOOKY_SCARY_SKELETONS() then
					local newBody = makeSkeletonBody(body)
					newContainer = newBody:getContainer()
				else
					local newSkeleton = makeSkeleton(body)
					newSkeleton:setSpeedMod(3)
					newSkeleton:setKnockedDown(true)
					newContainer = newSkeleton:getInventory()
				end

				local container = body:getContainer()
				if container ~= nil and container:getItems() ~= nil and container:getItems():size() > 0 then
					local items = container:getItems()
					local itemsToAdd = {} --Directly adding items into the container fucks with items:size()
					for i=0, items:size()-1 do
						itemsToAdd[#itemsToAdd+1] = items:get(i)
					end
					for i=1, #itemsToAdd do
						newContainer:addItem(itemsToAdd[i])
					end
					container:clear()
				end

				sendDeleteBodyEvent(body:getObjectID())
				bodyIds[body:getObjectID()] = nil
				body:removeFromWorld()
				body:removeFromSquare()
			end
		end
	end

	deferedDeadBodyDeletions = remainingDeferedDeletions
end

function OnTick(ticks)
	runDeferedBodyDeletions()
	if not ARE_HORDES_ON() then
		return
	end
	runDeferedBodyChecks()
	attemptToDrawZombiesToCorpses()
end

local commands = {}

function commands.PickupBodyId(args)
	if not ARE_HORDES_ON() then
		return
	end
	bodyIds[args.id] = nil
	print("Someone picked up a zombie")
end

function commands.PlaceDeadBody(args)
	if not ARE_HORDES_ON() then
		return
	end
	local x = args.x
	local y = args.y
	local z = args.z

	local square = getCell():getGridSquare(x, y, z)

	if square == nil then
		print("Failed to find a square :(")
	else
		deferedDeadBodyChecks[#deferedDeadBodyChecks+1] = {
			squares = bodyUtils.getSurroundingSquares(square, ZOMBIE_KILLED_CORPSE_SEARCH_RANGE, ZOMBIE_KILLED_CORPSE_SEARCH_DEPTH),
			attemptsLeft = MAX_TICKS_TO_WAIT_FOR_CORPSE
		}
	end
end

local function onClientCommand(module, command, player, args)
    if module == "PDFTZ" then
        commands[command](args)
    end
end

local function onAIStateChange(character, newState, oldState)
	if istype(character, "IsoZombie") then
		if oldState ~= nil and (istype(newState, "ZombieIdleState")) and character:getEatBodyTarget() == nil then
			local x = character:getX()
			local y = character:getY()
			local z = character:getZ()

			local square = getCell():getGridSquare(x, y, z)

			if not square then return end

			local squaresToCheck = bodyUtils.getSurroundingSquares(square, NEARBY_CORPSE_AI_SEARCH_RANGE, NEARBY_CORPSE_AI_SEARCH_DEPTH)
			local bodies = bodyUtils.getDeadBodiesInSquares(squaresToCheck)

			if #bodies >= 1 then
				local pathableBodies = {}

				for i=1, #bodies do
					local body = bodies[i]
					if body:getEatingZombies():size() <= 2 and character:CanSee(body) then
						pathableBodies[#pathableBodies+1] = body
					end
				end

				if #pathableBodies > 0 then
					local body = pathableBodies[ZombRand(1, #pathableBodies)]
					character:setBodyToEat(body)
					if deferedDeadBodyDeletions[body] == nil then
						print("Scheduled a body deletion")
						deferedDeadBodyDeletions[body] = {
							eatTimeRemaining = MINS_TO_WAIT_BEFORE_CORPSE_DELETION_WHEN_EATEN()
						}
					end
				end
			end
		end
	end
end

local function ReuseGridsquare(square)
	if not ARE_HORDES_ON() then
		return
	end
	local bodies = square:getDeadBodys()

	if bodies == nil or bodies:size() == 0 then
		return
	end

	for i=0, bodies:size() - 1 do
		local body = bodies:get(i)
		bodyIds[body:getObjectID()] = nil
	end
end

local function LoadGridsquare(square)
	if not ARE_HORDES_ON() then
		return
	end
	local bodies = square:getDeadBodys()

	if bodies == nil or bodies:size() == 0 then
		return
	end

	for i=0, bodies:size() - 1 do
		local body = bodies:get(i)
		
		if not body:isSkeleton() then
			print("Found a new body")

			bodyIds[body:getObjectID()] = {
				body = body,
				minutesToHoard = ZombRand(MIN_MINUTES_BEFORE_HOARD(), MAX_MINUTES_BEFORE_HOARD)
			}
		end
	end
end

Events.ReuseGridsquare.Add(ReuseGridsquare)
Events.OnClientCommand.Add(onClientCommand)
Events.OnAIStateChange.Add(onAIStateChange)
Events.OnZombieDead.Add(OnZombieKilled)
Events.OnTick.Add(OnTick)
Events.LoadGridsquare.Add(LoadGridsquare)

