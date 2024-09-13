--|-------------------------------------|--
--|       CV3 On-Screen Map Viewer      |--
--|          For BizHawk 2.9.1          |--
--|            NesHawk Core             |--
--|-------------------------------------|--
--| ROMs supported:                     |--
--|-------------------------------------|--
--| Akumajou Densetsu (J)               |--
--| Castlevania 3 - Dracula's Curse (U) |--
--|-------------------------------------|--

-- This is the stand-alone map viewer script. Displays the contents
-- of the tile buffer at 0x6E0, as well on-screen tiles and staircases.

-- This script shares a lot of components with the corruption visualizer script in the same
-- directory. Do not run both scripts together, instead, enable the map viewer functionality
-- in the corruption visualizer script.

-- Functions

local function get_game_type()
	local board = gameinfo.getboardtype()
	if board == "ExROM" then
		game_type = "us"
	elseif board == "VRC6" then
		game_type = "jp"
	else
		error("Cannot determine game type" .. board)
	end
	print("Game type is " .. game_type .. ".")
end

function val(us, jp)
	if game_type == "jp" then
		return jp
	else
		return us
	end
end

-- Imports

local map_viewer = require("modules/map-viewer")

-- Configuration - this overrides the configuration in the map viewer module

show_tiles_onscreen = true
show_tile_buffer = true
show_replaced_tiles = true
show_stair_data = true

tile_w = 10
tile_h = 10
tile_origin_x = -24
tile_origin_y = 384

-- Game Values

local game_type = nil

-- Start Execution --

console.clear()

gui.clearGraphics("client")
gui.clearGraphics("emucore")
gui.cleartext()

print("Starting CV3 Map viewer...")

get_game_type()
gui.use_surface("client")

-- Main script loop, execute every frame --
while true do
	map_viewer.show()

	-- We need yield() to interact with the dynamic elements on the screen
	-- Since it can cause a measurable performance impact if the emu is unpaused, 
	-- we make sure to only run the script loop once per frame,
	-- just as if you would use emu.frameadvance()
	local cur_framecount = emu.framecount()
	repeat
		emu.yield()
	until cur_framecount ~= emu.framecount() or client.ispaused()

	gui.clearGraphics("client")
	gui.clearGraphics("emucore")
	gui.cleartext()
end