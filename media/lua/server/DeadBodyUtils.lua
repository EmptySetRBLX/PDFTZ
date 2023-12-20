bodyUtils = {}

function bodyUtils.getSurroundingSquares(square, checkSize, depth)
	local cell = square:getCell()
	local centerX = square:getX()
	local centerY = square:getY()
	local centerZ = square:getZ()
	
	local corner1 = {
		x = centerX - checkSize,
		y = centerY - checkSize,
		z = math.max(0, centerZ - depth)
	}
	local corner2 = {
		x = centerX + checkSize,
		y = centerY + checkSize,
		z = math.min(8, centerZ + depth)
	}
	
	local squares = {}
	
	for x=corner1.x, corner2.x do
		for y=corner1.y, corner2.y do
			for z=corner1.z, corner2.z do
				local currentSquare = cell:getGridSquare(x, y, z)
				if currentSquare ~= nil then
					squares[#squares+1] = currentSquare
				end
			end
		end
	end
	
	
	return squares
end

function bodyUtils.getDeadBodiesInSquares(squares)
	local bodies = {}
	
	for i=1, #squares do
		local bodyList = squares[i]:getDeadBodys()
		if bodyList ~= nil and bodyList:size() > 0 then
			for i=0, bodyList:size() -1 do
				local body = bodyList:get(i)
				if not body:isSkeleton() then
					bodies[#bodies+1] = bodyList:get(i)
				end
			end
		end
	end
	
	return bodies
end