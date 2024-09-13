-- This module handles all game values related to tile and staircase loading
-- in one place, so they can be accessed by other parts of the script.

local stair_data = require("modules/map-viewer/stairs")

local tile_val = {}

function tile_val.get()
	tile_val.gamestate = memory.readbyte(0x18)
	tile_val.substate = memory.readbyte(val(0x2A, 0x2C))
	tile_val.vertical = memory.readbyte(val(0x68, 0x65)) ~= 0
	tile_val.horizontal = not tile_val.vertical
	tile_val.camera = memory.read_u16_le(val(0x56, 0x53))

	tile_val.tile_buffer = {}
	if tile_val.vertical then
		tile_val.tile_buffer = { w = 16, h = 15, start_adr = 0x6E0, end_adr = 0x760 - 1 }
	else
		tile_val.tile_buffer = { w = 24, h = 12, start_adr = 0x6E0, end_adr = 0x770 - 1 }
	end
	local size = tile_val.tile_buffer.w * tile_val.tile_buffer.h
	tile_val.tile_buffer.tiles = memory.read_bytes_as_dict(tile_val.tile_buffer.start_adr, size)

	-- Stair data
	tile_val.stair_ptr = memory.read_u16_le(val(0x69, 0x66))
	if show_stair_data then
		tile_val.stair_data = stair_data.read(tile_val.vertical)
	end
	tile_val.stair_v_offs = 0
	if tile_val.vertical then
		-- For some reason, the game adds 51 pixels to the Y position of a stair case in vertical room
		-- but then, stairs are also placed one tile lower than expected. Don't ask me.
		tile_val.stair_v_offs = -35
	end
	return 0
end

return tile_val

