-- This module handles fetching and displaying the RAM values for the actual enemy data write operation

-- In principle, memory corruption in CV3 is entirely dependent on two RAM values:
-- $76 (U) -  8 Bits - room_read_64    - Current 64-pixel strip in the direction the camera is scrolling
-- $98 (U) - 16 Bits - obj_idx_pointer - Pointer to index of current room object

-- Basically, there exists a "object index pointer" in the game for every room which determines which level
-- object the game tries to load at a given camera position. This pointer is normally static once the room
-- is loaded, but memory corruption can corrupt it just the same.
--
-- This module handles gathering all the involved values from RAM, displaying them, and making them available
-- to other parts of the script so they don't have to be re-fetched over and over again

local obj_val = {}

-- Configuration

local x_offs = -16
local y_offs = -448

-- Definitions

ROOM_READ_64_ADR = val(0x76, 0x73)
OBJ_IDX_PTR_ADR = val(0x98, 0x95)

-- Internal Functions

local function get_u8(adr)
	-- RAM below $8000, fixed bank @ $C000, swappable bank @ $8000
	if adr < 0x8000 or adr >= 0xC000 then
		return memory.read_u8(adr)
	else
		return memory.read_u8(prg_rom(adr), "PRG ROM")
	end
end

local function get_u16(adr)
	if adr < 0x8000 or adr >= 0xC000 then
		return memory.read_u16_le(adr)
	else
		return memory.read_u16_le(prg_rom(adr), "PRG ROM")
	end
end

local function get_bytes(adr, size)
	if adr < 0x8000 or adr >= 0xC000 then
		return memory.read_bytes_as_array(adr, size)
	else
		return memory.read_bytes_as_array(prg_rom(adr), size, "PRG ROM")
	end
end

-- Functions

function obj_val.get()
	-- Gather the values from RAM

	-- First of all, predict where it should be based on the block, sublevel and room indices
	obj_val.block = memory.readbyte(val(0x32, 0x34))
	obj_val.sublevel = memory.readbyte(val(0x33, 0x35))
	obj_val.room = memory.readbyte(val(0x34, 0x36))
	obj_val.cam_pos = memory.read_u16_le(val(0x56, 0x53))
	obj_val.hard_mode = memory.read_u8(0x7F6)

	-- Get the predicted value for the spawner index pointer by running through the block - sublevel - room indirection
	obj_val.block_idx_adr = BLK_OBJ_SPAWNERS_ADR + obj_val.block * 2
	obj_val.block_idx_val = memory.read_u16_le(prg_rom(obj_val.block_idx_adr), "PRG ROM")

	obj_val.sublevel_idx_adr = obj_val.block_idx_val + obj_val.sublevel * 2
	obj_val.sublevel_idx_val = memory.read_u16_le(prg_rom(obj_val.sublevel_idx_adr), "PRG ROM")

	obj_val.room_idx_adr = obj_val.sublevel_idx_val + obj_val.room * 2
	obj_val.room_idx_val = memory.read_u16_le(prg_rom(obj_val.room_idx_adr), "PRG ROM")

	-- Now, check where it actually points based on the memory value 
	-- - it could differ from the "predicted" value due to previous memory corruption
	-- See here for an example: https://github.com/vinheim3/castlevania3-disasm/blob/main/code/bank14.s#L182
	-- For simplicity, all addresses in the following description use the U variants

	-- First, load $76 and multiply it by 2, effectively reading the current 32-byte chunk of the room
	obj_val.room_read_64 = memory.readbyte(ROOM_READ_64_ADR)
	obj_val.room_read_64_offs = (obj_val.room_read_64 * 2) & 0xFF

	-- Load ($98),y where y is room_read_64_offs
	obj_val.obj_idx_pointer = memory.read_u16_le(OBJ_IDX_PTR_ADR)
	obj_val.raw_obj_idx = get_u8(obj_val.obj_idx_pointer + obj_val.room_read_64_offs)

	-- The spawner index is multiplied by 2 to address the OBJ spawner table at $A03F
	-- The table has 228 entries (456 bytes), and they're accessed like this:
	--   - The first 208 (0xD0) entries are used regularly
	--   - The final 20 entries are used only in hard mode (2nd quest).
	--     If hard mode is not active, the values are replaced with 0
	obj_val.obj_idx = obj_val.raw_obj_idx
	if obj_val.hard_mode == 0 and obj_val.obj_idx >= 0xD0 then
		obj_val.obj_idx = 0
	end

	-- Finally, load the object bytes from the OBJ table at $A03F 
	obj_val.obj_pointer = memory.read_u16_le(OBJ_PTR_TABLE_ROM + obj_val.obj_idx * 2, "PRG ROM")
	obj_val.obj_data = get_bytes(obj_val.obj_pointer, 5)
end

function obj_val.show()
	local obj_idx_mismatch = ""
	if obj_val.room_idx_val ~= obj_val.obj_idx_pointer then
		obj_idx_mismatch = " (!)"
	end

	local messages = {
		{
			string.format("BLK %X : %X / Room %d", obj_val.block, obj_val.sublevel, obj_val.room),
			string.format("Cam: $%04X / $%02X: $%02X", obj_val.cam_pos, ROOM_READ_64_ADR, obj_val.room_read_64),
			string.format("Second Quest: %X", obj_val.hard_mode)
		},
		{
			string.format("BLK:  $%04X @ %X > $%04X", BLK_OBJ_SPAWNERS_ADR, obj_val.block, obj_val.block_idx_val),
			string.format("SUB:  $%04X @ %X > $%04X", obj_val.block_idx_val, obj_val.sublevel, obj_val.sublevel_idx_val),
			string.format("ROOM: $%04X @ %X > $%04X", obj_val.sublevel_idx_val, obj_val.room, obj_val.room_idx_val),
		},
		{
			"Index into OBJ Table",
			string.format("$%04X + $%02X -> $%02X%s", obj_val.obj_idx_pointer, obj_val.room_read_64_offs, obj_val.raw_obj_idx, obj_idx_mismatch),
		},
		{
			"OBJ",
			string.format("$%04X + $%02X -> $%04X", OBJ_PTR_TABLE_ADR, obj_val.obj_idx, obj_val.obj_pointer),
			"Data: " .. table.concat(draw_format_hex(obj_val.obj_data), " "),
		},
		{
			"Write to Index",
			string.format("$%04X + $%02X -> $%02X", MOD_6_TABLE_ADR, obj_val.room_read_64, MOD_6_TABLE_DATA[obj_val.room_read_64 + 1])
		}
	}

	local draw_x, draw_y = draw_get_pos(x_offs, y_offs, 256, nil)
	for _, lines in pairs(messages) do
		local message = table.concat(lines, "\n")
		local _, line_count = string.gsub(message, "\n", "\n")
		local message_height = (line_count + 1) * 16 + 16
		-- This function just dumps all the relevant values on screen in a somewhat digestible format
		gui.drawRectangle(draw_x, draw_y, 256, message_height, 0xFFFFFFFF, 0)
		gui.text(draw_x + 8, draw_y + 16, message)
		draw_y = draw_y + message_height
	end
end

return obj_val