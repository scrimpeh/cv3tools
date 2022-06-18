-- OK, the Idea is basically to have some sort of decision tree
-- There's 4 _states, ground (pause/unpause) and air (pause/unpause)
-- In each state, there's a number of actions that can be performed
-- The iteration ends when all decisions have been exhausted
-- Successful attempts are stored as a sequence of inputs and/or save_states
-- Finally, there should be a cutoff, if an attempt takes significantly longer than desired, kill it
-- Finally, there's some other conditions, like if we've been paused for more than two frames, also kill the attempt (or four, at worst, to counter dropped input thanks to DMC)

-- Okay, I think this is the data structure for my tree node
-- * Current State
-- * Savestate
-- * Depth
-- * Parent
-- * Children

-- 14084
-- 14762
-- 14574
-- -188 frames
-- 14118
-- basically, if the attempt takes more than ~220 frames, I can can it
-- We jump from the final frame possible

-- _states
STATE_GROUND = 0
STATE_GROUND_JUMP = 1
STATE_GROUND_PAUSE = 2
STATE_AIR = 3
STATE_AIR_PAUSE = 4

TIME_CUTOFF = 225

_successful_attempts = {}	-- I'm not sure what the best data structure for this is yet
_states = {}

-- Stats

_total_attempts = 0
_rejected_attempts = 0
_fastest_successful_attempt = 9999999
_table_attempts = 0

-- Version Specific Values --

ADDR_TILE_LOAD_L_COL = 0x59
ADDR_TILE_LOAD_L_COUNT = 0x5B
ADDR_TILE_LOAD_R_COL = 0x5A
ADDR_TILE_LOAD_R_COUNT = 0x5C
ADDR_XS = 0x6E
ADDR_FRAMECOUNTER = 0x1A


-- Functions --

function set_inputs(input_value)
	-- We're using the NES's controller pinout, so
	-- 01 : A -- 10 : U
	-- 02 : B -- 20 : D
	-- 04 : s -- 40 : L
	-- 08 : S -- 80 : R
	local inputs = {}
	inputs["P1 A"]      = bit.band(input_value, 0x01) ~= 0
	inputs["P1 B"]      = bit.band(input_value, 0x02) ~= 0
	inputs["P1 Select"] = bit.band(input_value, 0x04) ~= 0
	inputs["P1 Start"]  = bit.band(input_value, 0x08) ~= 0
	inputs["P1 Up"]     = bit.band(input_value, 0x10) ~= 0
	inputs["P1 Down"]   = bit.band(input_value, 0x20) ~= 0
	inputs["P1 Left"]   = bit.band(input_value, 0x40) ~= 0
	inputs["P1 Right"]  = bit.band(input_value, 0x80) ~= 0
	joypad.set(inputs)
end


function reject_state(state)
	if state.depth >= TIME_CUTOFF then
		return true
	end
	
	local tile_load_l_count = memory.readbyte(ADDR_TILE_LOAD_L_COUNT)
	local tile_load_l_col = memory.readbyte(ADDR_TILE_LOAD_L_COL)
	local tile_load_r_count = memory.readbyte(ADDR_TILE_LOAD_R_COUNT)
	local tile_load_r_col = memory.readbyte(ADDR_TILE_LOAD_R_COL)
	
	if tile_load_l_col == 1 and tile_load_l_count > 1 then
		return true
	elseif tile_load_l_col >= 2 then
		return true
	end
		
	return false
end

function accept_state(state)
	-- We rely on a state not having been rejected before	
	local tile_load_l_col = memory.readbyte(ADDR_TILE_LOAD_L_COL)
	if tile_load_l_col == 0 then
		return true
	end
	
	return false
end


function create_state(state_type, input_value, parent_state)
	new_state = {
		state = state_type,
		save = memorysavestate.savecorestate(),
		depth = 0,
		input = input_value,
		time_in_state = 0,
		parent = parent_state
	}
	if parent_state ~= nil then
		new_state.depth = parent_state.depth + 1
		if parent_state.state == state_type then
			new_state.time_in_state = parent_state.time_in_state + 1
		end
	end
	return new_state
end

function perform_action(state, input_value, next_state)
	set_inputs(input_value)
	emu.frameadvance()
	table.insert(_states, create_state(next_state, input_value, state))
	memorysavestate.loadcorestate(state.save)
end

function can_pause()
	local fc = memory.readbyte(ADDR_FRAMECOUNTER)
	return bit.band(fc, 0x01) == 1
end

function process_state(state)
	function perform(input, next_state)
		perform_action(state, input, next_state)
	end
	
	memorysavestate.loadcorestate(state.save)

	if reject_state(state) then
		_rejected_attempts = _rejected_attempts + 1
		return
	end
	
	if accept_state(state) then
		table.insert(_successful_attempts, state)
		print_successful_attempt(#_successful_attempts, state)
		return
	end

	-- enumerate all possible decisions here
	-- for each decision
	--- perform the input corresponding to that decision
	--- frameadvance
	--- savestate
	-- create a new state and add it to the table
	
	-- one problem I have is that there is no way for the state to change based
	-- on the actions ingame right now - this is ok for now
	local framecounter = memory.readbyte(ADDR_FRAMECOUNTER)
	if state.state == STATE_GROUND then
		perform(0x00, STATE_GROUND)	    	-- Idle
		perform(0x01, STATE_GROUND_JUMP)  	-- Jump
		perform(0x40, STATE_GROUND)  		-- Walk Left
		perform(0x80, STATE_GROUND) 		-- Walk Right
		if can_pause() then
			perform(0x08, STATE_GROUND_PAUSE) -- Pause
		end
	elseif state.state == STATE_GROUND_JUMP then
		perform(0x40, STATE_AIR)	    	-- Jump Left
		perform(0x00, STATE_AIR)	    	-- Jump Straight - should hopefully never need this
		-- perform(0x80, STATE_AIR)	    	-- Jump Right - this is never wqhat I want
	elseif state.state == STATE_GROUND_PAUSE then
		if state.time_in_state < 4 then
			perform(0x00, STATE_GROUND_PAUSE)	-- Idle
			if state.time_in_state > 1 then
				perform(0x08, STATE_GROUND)	-- Unpause
				perform(0x48, STATE_GROUND)
				perform(0x88, STATE_GROUND)
			end
		else 
			_rejected_attempts = _rejected_attempts + 1
		end
	elseif state.state == STATE_AIR then
		perform(0x00, STATE_AIR)
		local xs = memory.readbyte(ADDR_XS)
		if xs ~= 0 and can_pause() then
			perform(0x08, STATE_AIR_PAUSE)
		end
	elseif state.state == STATE_AIR_PAUSE then
		if state.time_in_state < 4 then
			perform(0x00, STATE_AIR_PAUSE)	-- Idle
			if state.time_in_state > 1 then
				perform(0x08, STATE_AIR)	-- Unpause
			end
		else 
			_rejected_attempts = _rejected_attempts + 1
		end
	end
end

function print_successful_attempt(i, attempt)
	console.log("=> Successful attempt @ " .. attempt.depth .. " @ frames")
	
	local filename = "cv3_brute_force_" .. i .. ".txt"
	file = io.open(filename, "a");
	
	file:write("[DEPTH] " .. attempt.depth .. "\n\n")
	
	if attempt.depth < _fastest_successful_attempt then
		console.log("New Winner! -> " .. attempt.depth .. " frames!")
		_fastest_successful_attempt = attempt.depth
		savestate.save("cv3_brute_force")
	end
	
	while attempt.parent ~= nil do
		file:write(string.format("%X\n", attempt.input))
		attempt = attempt.parent
	end
	file:close()
	
end

-- Script Start --

console.clear()
console.log("Starting CV3 Brute Forcer")

emu.limitframerate(false)

table.insert(_states, create_state(STATE_GROUND, 0, nil))

local attempt_counter = 0
local i, state = next(_states, nil)
while i do
	_total_attempts = _total_attempts + 1
	process_state(state)
	_states[i] = nil
	i, state = next(_states, nil)     
	attempt_counter = attempt_counter + 1
	if attempt_counter == 100 then
		console.log("Attempts [ Total: " .. _total_attempts .. ", Left: " .. #_states .. ", Rejected: " .. _rejected_attempts .. ", Successful: " .. #_successful_attempts .. " ]")
		attempt_counter = 0
	end
end

console.log("Finished")
console.log("Attempts [ Total: " .. _total_attempts .. ", Left: " .. #_states .. ", Rejected: " .. _rejected_attempts .. ", Successful: " .. #_successful_attempts .. " ]")

if #_successful_attempts == 0 then
	console.log("No successful attempts :(")
end

emu.limitframerate(true)
console.log("Done.")
