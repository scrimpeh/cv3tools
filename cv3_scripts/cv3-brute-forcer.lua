--[[
Basic brute forcing engine for simple inputs
--]]

-- Configuration --

repeatCount = 4
frameLenMin = 3
frameLenMax = 5

-- Version Specific Values --

addrRightScrollMtb = 0x59
addrCameraPos = 0x53

-- Globals --

initialCameraPos = memory.read_u16_le(addrCameraPos)
attemptInitialScrollValue = 0
attemptCameraPos = initialCameraPos

-- Functions --

function setNesInputs(inputValue)
	-- We're using the NES's controller pinout, so
	-- 01 : A -- 10 : U
	-- 02 : B -- 20 : D
	-- 04 : s -- 40 : L
	-- 08 : S -- 80 : R
	local inputs = {}
	--[[ inputs["P1 A"]      = bit.band(inputValue, 0x01) ~= 0
	inputs["P1 B"]      = bit.band(inputValue, 0x02) ~= 0
	inputs["P1 Select"] = bit.band(inputValue, 0x04) ~= 0
	inputs["P1 Start"]  = bit.band(inputValue, 0x08) ~= 0
	inputs["P1 Up"]     = bit.band(inputValue, 0x10) ~= 0
	inputs["P1 Down"]   = bit.band(inputValue, 0x20) ~= 0
	inputs["P1 Left"]   = bit.band(inputValue, 0x40) ~= 0
	inputs["P1 Right"]  = bit.band(inputValue, 0x80) ~= 0
	--]]
	
	inputs["P1 Left"]  = bit.band(inputValue, 0x01) ~= 0
	inputs["P1 Right"] = bit.band(inputValue, 0x02) ~= 0
	inputs["P1 Start"] = bit.band(inputValue, 0x04) ~= 0
	joypad.set(inputs)
end

function checkAttempt(inputs)
	local cameraPos = memory.read_u16_le(addrCameraPos)
	if cameraPos > attemptCameraPos then
		attemptCameraPos = cameraPos
		print("got new max: " .. cameraPos)
		print(inputs)
	end
end

function checkAttemptRejection(inputs)
	-- If any tile was loaded during this time, reject the attempt
	if bit.band(inputs, 0x01) ~= 0 and bit.band(inputs, 0x02) ~= 0 then
		return true
	end
	local currentScrollValue = memory.readbyte(addrRightScrollMtb)
	if currentScrollValue ~= attemptInitialScrollValue then
		return true
	end
	if memory.read_u16_le(addrCameraPos) < initialCameraPos - 3 then	
		return true
	end
	return false
end

function startAttempt()
	attemptInitialScrollValue = memory.readbyte(addrRightScrollMtb)
end

function tryInput(inputs)
	memorysavestate.loadcorestate(savestate)
	startAttempt()
	local count = 0
	for iteration = 1, repeatCount do
		for i, currentInput in ipairs(inputs) do
			setNesInputs(currentInput)
			emu.frameadvance()
			if checkAttemptRejection(currentInput) then
				if iteration == 1 then
					return i
				else 
					return count
				end
			end
			count = i
		end
	end
	checkAttempt(inputs)
	return count
end

failedAfter = 0

function generateInputsInternal(inputs, current, maxDepth)
	for i = 0, 7 do
		inputs[current] = i
		if current == maxDepth then
			failedAfter = tryInput(inputs)
		elseif failedAfter >= current then
			failedAfter = maxDepth
			generateInputsInternal(inputs, current + 1, maxDepth)
		end
	end
end

function generateInputs(inputs, maxDepth)
	failedAfter = maxDepth
	generateInputsInternal(inputs, 1, maxDepth)
end


-- Script Start --

console.clear()
console.log("Starting CV3 Brute Forcer")

emu.limitframerate(false)
savestate = memorysavestate.savecorestate()

console.log("Brute forcing " .. frameLenMin .. " - " .. frameLenMax .. " frames.")
for length = frameLenMin, frameLenMax do
	console.log("Brute forcing inputs of " .. length .. " frames...")

	-- Generate the input
	local inputs = {}
	for i = 1, length do
		table.insert(inputs, 0)
	end
	generateInputs(inputs, length)
end

emu.limitframerate(true)
console.log("Done.")
