-- The OBJ Table is a 228 entry table with pointers to the OBJ structs

-- It is located at $2A03F (U) or $29F6E (J) and contains 228 pointers to the 5-byte OBJ structs
-- It is normally indexed through indirectly through obj_idx_ptr. The value in obj_idx_ptr plus the
-- current camera position divided by 128 determine which value of this table to read.

local obj_val = require("modules/object-data-values")

local obj_table = {}

-- Configuration

local y_offs = 30
local col_w = 6
local h = 10

-- Definitions

OBJ_PTR_TABLE_ROM = val(0x2A03F, 0x29F6E)
OBJ_PTR_TABLE_ADR = prg_bank(OBJ_PTR_TABLE_ROM)
OBJ_PTR_TABLE_SIZE = 228

-- Functions

function obj_table.show()
	-- Show the pointer table to the OBJ Info Structs
	local w = OBJ_PTR_TABLE_SIZE * col_w
	local draw_x = client.screenwidth() / 2 - w / 2
	local draw_y = client.screenheight() - y_offs

	gui.text(draw_x - 210, draw_y + 5, string.format("OBJ Pointers   $%04X", OBJ_PTR_TABLE_ADR))
	gui.drawRectangle(draw_x, draw_y, w, h)
	for i = 16, OBJ_PTR_TABLE_SIZE - 1, 16 do
		local line_x = draw_x + i * col_w
		gui.drawLine(line_x, draw_y + 1, line_x, draw_y + h - 1, 0xFFCCCCCC)
	end

	draw_tick(draw_x, draw_y + h, 8)
	for i = 128, OBJ_PTR_TABLE_SIZE - 1, 128 do
		draw_tick(draw_x + i * col_w, draw_y + h, 4)
	end
	draw_tick(draw_x + w, draw_y + h, 8)

	local end_adr = OBJ_PTR_TABLE_ADR + OBJ_PTR_TABLE_SIZE * 2
	gui.text(draw_x + w + 16, draw_y + 5, string.format("$%04X", end_adr))

	-- Show where the game accesses the OBJ Table
	if obj_val.obj_idx < OBJ_PTR_TABLE_SIZE then
		local draw_x_offset = draw_x + obj_val.obj_idx * col_w
		gui.drawRectangle(draw_x_offset, draw_y, col_w, h, 0xFFFF80FF, 0xFFFF0000)
	else
		draw_circle(draw_x + w + 84, draw_y, h, 0xFFFF0000)
	end
end

return obj_table