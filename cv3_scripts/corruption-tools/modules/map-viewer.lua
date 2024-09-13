-- This module holds the code for the map viewer. It is accessed by both the corruption visualizer and the
-- (stand-alone) map viewer

local map_viewer = {}

require("util/table-util")

local stair_data = require("modules/map-viewer/stairs")
local on_screen_tiles = require("modules/map-viewer/on-screen-tiles")
local tile_buffer = require("modules/map-viewer/tile-buffer")
local tile_val = require("modules/map-viewer/tile-values")

-- Configuration

show_tiles_onscreen = true
show_tile_buffer = true
show_replaced_tiles = true
show_stair_data = true

tile_w = 10
tile_h = 10
tile_origin_x = -24
tile_origin_y = 368

-- Static Data

-- See https://datacrystal.tcrf.net/wiki/Castlevania_III:_Dracula%27s_Curse/RAM_map
-- The other game states don't show the map or do not align the scroll with the camera
local GAMEPLAY_SUBSTATES = table_key_set({ 0x03, 0x05, 0x0A, 0x0B, 0x0C, 0x10, 0x11, 0x13, 0x16, 0x19, 0x1A, 0x1B, 0x1C })

-- Game Values

local replaced_tiles_cb_registered = false

local function is_in_game()
	if tile_val.gamestate ~= 4 then
		return false
	end
	return GAMEPLAY_SUBSTATES[tile_val.substate] == true
end

-- Main script loop, execute every frame --
function map_viewer.show()
	tile_val.get()

	if not is_in_game() then
		return
	end

	if show_tiles_onscreen then
		on_screen_tiles.show()
		on_screen_tiles.show_stairs()
	end

	if show_tile_buffer then
		tile_buffer.show()
	end

	if show_replaced_tiles then
		if not replaced_tiles_cb_registered then
			event.onmemoryexecute(tile_buffer.get_replaced, val(0xD29E, 0xD273), "cv3_map_viewer_tile_buffer_show_replaced")
			replaced_tiles_cb_registered = true
		end
		tile_buffer.show_new_tiles()
	else
		event.unregisterbyname("cv3_map_viewer_tile_buffer_show_replaced")
		replaced_tiles_cb_registered = false
	end
end

return map_viewer