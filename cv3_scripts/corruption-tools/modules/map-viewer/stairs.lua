# Manages information about stairs

-- Stair entrance format
-- 
-- Pointed to by $69 (U) / $66 (J)
-- 
-- Address Translation ADR - ROM:
-- $B88F -> $1F88F
-- 
-- Horizontal
-- aa__ yyyy: direction (UR, UL, DL, DR), Y tile
-- xxxx xxxx: X px
-- XXXX XXXX: X high
-- 
-- Vertical
-- aa__ YYYY: direction (UR, UL, DL, DR), Y high
-- yyyy yyyy: Y px
-- xxxx xxxx: X px
-- 
-- $FF as the first byte indicates sequence end
-- 
-- -- The game uses the camera position to find stairs in both horizontal and vertical rooms

local stairs = {}

UP_RIGHT = 0
UP_LEFT = 1
DOWN_LEFT = 2
DOWN_RIGHT = 3

STAIR_PROPERTIES = { 
	[UP_RIGHT]   = { dx =  1, dy = -1, x_offs =  0, y_offs =  0, marker = { { 1, 1 }, { 6, 1 }, { 6, 6 } } },
	[UP_LEFT]    = { dx = -1, dy = -1, x_offs = -8, y_offs =  0, marker = { { 2, 1 }, { 7, 1 }, { 2, 6 } } },
	[DOWN_LEFT]  = { dx = -1, dy =  1, x_offs = -8, y_offs =  8, marker = { { 1, 6 }, { 6, 6 }, { 1, 1 } } },
	[DOWN_RIGHT] = { dx =  1, dy =  1, x_offs =  0, y_offs =  8, marker = { { 1, 6 }, { 6, 6 }, { 6, 1 } } }
}

local function read_byte(adr) 
	if adr < 0x8000 or adr >= 0xC000 then
		return memory.readbyte(adr)
	else
		return memory.readbyte(0x1C000 | (adr & 0x3FFF), "PRG ROM")
	end
end

function stairs.read(vertical)
	-- See https://github.com/vinheim3/castlevania3-disasm/blob/main/code/bank0f.s#L264
	local stairs = {}
	local stair_data_adr = memory.read_u16_le(val(0x69, 0x66))
	if stair_data_adr >= 0x2000 and stair_data_adr < 0x8000 then
		-- Stair Pointer points into open bus, no way to predict this
		return stairs
	end

	-- In invalid rooms, the stair pointer may point to invalid stair data, which can cause the game to keep reading
	-- the entire range accesssed by the pointer, and then wrap around, reading the whole range again, but offset by 1
	-- After three loops through the whole sequence, a failsafe in the game kicks in, keeping the game from locking up

	local offs = 0
	while read_byte(stair_data_adr + (offs & 0xFF)) ~= 0xFF and offs < 768 do
		local byte_0 = read_byte(stair_data_adr + (offs & 0xFF))
		local byte_1 = read_byte(stair_data_adr + ((offs + 1) & 0xFF))
		local byte_2 = read_byte(stair_data_adr + ((offs + 2) & 0xFF))

		local staircase = {
			flags = (byte_0 & 0xC0) >> 6,
			byte_0 = byte_0,
			byte_1 = byte_1,
			byte_2 = byte_2,
			offs = offs & 0xFF
		}
		staircase.down = staircase.flags == DOWN_LEFT or staircase.flags == DOWN_RIGHT
		staircase.right = staircase.flags == UP_RIGHT or staircase.flags == DOWN_RIGHT
		staircase.up = not staircase.down
		staircase.left = not staircase.right

		if vertical then
			-- The screen is only 15 tiles tall, the camera skips pixels 240 - 256
			-- Because of this, subtract 16 pixels for every full byte
			staircase.y = ((byte_0 & 0x3F) * 240) + byte_1 + 51
			staircase.x = byte_2
		else
			staircase.y = (byte_0 & 0x0F) * 16
			staircase.x = byte_2 * 256 + byte_1
		end

		table.insert(stairs, staircase)

		offs = offs + 3
	end
	return stairs
end

return stairs