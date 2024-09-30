--|-------------------------------------|--
--|       CV3 Fast Charswitch           |--
--|         For BizHawk 2.9.1           |--
--|       NesHawk / QuickNES Core       |--
--|-------------------------------------|--
--| ROMs supported:                     |--
--|-------------------------------------|--
--| Akumajou Densetsu (J)               |--
--| Castlevania 3 - Dracula's Curse (U) |--
--| Castlevania 3 - Dracula's Curse (E) |--
--|-------------------------------------|--

-- Enables fast character switching by capping the character switch timer to a maximum value

-- This script works by monitoring the character switch timer in memory. If the script detects that a character
-- switch is active, it reduces the value of the switch timer to shorten the character switch.
-- It would theoretically also be possible to hook into the game's code at the right moment, but this should
-- be simpler over all.

-- Configuration --

-- How long you want each stage of the character switch to last. Minimum is 0 frames (instant),
-- maximum is the regular time of the char switch. A value of 'nil' disables the script.
-- CAUTION: If you intend to record a movie with this script, make sure that the script is also running
-- while playing back the movie. Also make sure that the value is the same that you recorded with!
switch_timer = 0

-- Utility Functions --

local function get_game_type()
	-- Gets the game type. Note that US and EU are equivalent for this script
	local board = gameinfo.getboardtype()
	if board == "ExROM" then
		return "us"
	elseif board == "VRC6" or board == "vrc6a" then
		return "jp"
	else
		error("Cannot determine game type " .. board)
	end
end

function val(us, jp)
	if game_type == "jp" then
		return jp
	else
		return us
	end
end

-- Start point --

console.clear()
print("Starting CV3 Fast Charswitch Mod...")

while true do
	game_type = get_game_type()

	-- Important addresses
	SUBSTATE_ADR = val(0x2A, 0x2C)
	CHAR_SWITCH_TIMER_ADR = val(0x30, 0x32)

	-- Only act while ingame
	local gamestate = memory.readbyte(0x18)
	if type(switch_timer) == "number" and gamestate == 4 then
		-- Check if we are actually in character switch mode. Other things, like the whip upgrade
		-- also use the same address. You could in theory disable this condition to speed up those things too.
		local substate = memory.readbyte(SUBSTATE_ADR)
		local is_switching = substate == 11 or substate == 12

		local char_switch_time = memory.read_u16_le(CHAR_SWITCH_TIMER_ADR)
		local desired_switch_time = math.max(1, math.ceil(switch_timer) + 1)
		if is_switching and char_switch_time > desired_switch_time then
			memory.write_u16_le(CHAR_SWITCH_TIMER_ADR, desired_switch_time)
		end
	end
	emu.frameadvance()
end