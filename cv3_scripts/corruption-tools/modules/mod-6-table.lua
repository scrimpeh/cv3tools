-- The Mod 6 Table is one of the most important parts of CV3 memory corruption --

-- It is located at $2840C (U) or $28410 (J) and normally is indexed by $76 (U), which
-- is the index of the 64-pixel wide strip the camera is currently scrolling into. 

-- Normally, the value is used to index one of the 6-byte enemy data tables starting at
-- $7C2 in RAM. However, if the camera is above the maximum valid camera position, some random
-- index from after the table is fetched, which is what enables memory corruption

local obj_val = require("modules/object-data-values")

local mod_6_table = {}

-- Configuration

local x_offs = 24
local y_offs = -172
local v_scale = 1

-- Definitions

MOD_6_TABLE_ROM = val(0x2840C, 0x28410)
MOD_6_TABLE_ADR = prg_bank(MOD_6_TABLE_ROM)
MOD_6_TABLE_SIZE = 48

-- Initialization

MOD_6_TABLE_DATA = memory.read_bytes_as_array(MOD_6_TABLE_ROM, 256, "PRG ROM")

-- Functions

function mod_6_table.show()
	local h = 256 * v_scale
	local draw_x, draw_y = draw_get_pos(x_offs, y_offs, 256, h)

	gui.drawString(draw_x + 12, draw_y - 20, string.format("Enemy Data Write Offsets: $%04X", MOD_6_TABLE_ADR))
	gui.drawRectangle(draw_x - 1, draw_y - 1, 257, h + 1, 0xFF999999, 0)
	-- Draw OOB zone
	gui.drawRectangle(draw_x + MOD_6_TABLE_SIZE, draw_y, 256 - MOD_6_TABLE_SIZE, h, 0x80FF8080, 0x80FF8080)
	-- Draw contents of table
	for i = 0, 255, 1 do
		local value = MOD_6_TABLE_DATA[i + 1] 
		gui.drawLine(draw_x + i, draw_y + h, draw_x + i, (draw_y + h - value) * v_scale, 0xFFFFFFFF)
	end

	-- Show camera offset
	local read_offset_x = draw_x + obj_val.room_read_64
	gui.drawLine(read_offset_x, draw_y - 1, read_offset_x, draw_y + h + 1, 0xC000FFFF)
	gui.drawRectangle(read_offset_x - 3, draw_y - 6, 6, 6, 0xC000FFFF, 0xC000FFFF)
	gui.drawRectangle(read_offset_x - 3, draw_y + h, 6, 6, 0xC000FFFF, 0xC000FFFF)
end

return mod_6_table