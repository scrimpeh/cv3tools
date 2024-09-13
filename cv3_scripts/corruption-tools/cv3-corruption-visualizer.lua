--|-------------------------------------|--
--|   CV3 Memory Corruption Visualizer  |--
--|           For BizHawk 2.9.1         |--
--|             NesHawk Core            |--
--|-------------------------------------|--
--| ROMs supported:                     |--
--|-------------------------------------|--
--| Akumajou Densetsu (J)               |--
--| Castlevania 3 - Dracula's Curse (U) |--
--|-------------------------------------|--

-- Visualizes Camera-Based Memory Corruption as it happens
--  - Whenever the OBJ spawner code is executed, output a log message with the important parameters and the effects on memory
--  - Visualizes corruptions in memory using a heatmap
--  - Visualizes the chain of indirection the game goes through to find the values to write into the heatmap
--  - Shows the game's tiles to aid with glitched world navigation

-- Usage note - this script assumes that you run BizHawk in fullscreen mode and have 
-- a large display with a reasonably large amount of space in the margins to either side of the screen.
-- In my case, the script runs on a 1080p display, with the NES display stretched to the top and bottom
-- borders of the screen.
-- If this does not work for you, adjust the values in the display class until it looks right.

-- On notation and addresses:
-- This script juggles several different kinds of values with different properties.
-- To (hopefully) reduce confusion, some naming conventions are used to clarify what we are dealing with:

-- pointers / addresses into the 6502 address space end with '_adr'
-- pointers / addresses into the game's PRG rom end with '_rom'

-- This is important because the script fetches some static data from ROM, but it is only actually
-- loaded into the game's address space during certain times. since we want to be able to access this
-- data at any time though, we need to differentiate between the two

-- Tables can also be somewhat arbitrarily mixed between being 0-indexed or 1-indexed, depending on what is more convenient
-- If in doubt, look at their creation or their usage to find out

-- Start point - Executed before any other modules are loaded

console.clear()
print("Starting CV3 Memory Corruption Visualizer...")

gui.clearGraphics("client")
gui.clearGraphics("emucore")
gui.cleartext()

gui.use_surface("client")

-- Get Game Type

GAME_TYPES = {
	["ExROM"] = "us",
	["VRC6"] = "jp"
}
game_type = GAME_TYPES[gameinfo.getboardtype()]
if not game_type then
	error("Cannot determine game type " .. gameinfo.getboardtype())
end

print("Game type is " .. game_type .. ".")

function val(us, jp)
	if game_type == "jp" then
		return jp
	else
		return us
	end
end

-- Utilities 

require("util/address")
require("util/draw")
require("util/event")

-- Components

local osd = require("util/osd")
local mouse = require("util/mouse")

-- Static data collected at the game start.
-- Files named "info" contain properties about the game that are statically defined the in the script
-- Files named "data" are read from the current ROM
-- There can be dependencies in the order of execution between these files

local block_info = require("static/block-info")
local obj_spawner_data = require("static/obj-spawner-data")
local obj_idx_data = require("static/obj-idx-data")
local ram_map_data = require("static/ram-map-data")

-- Different modules, which are responsible for handling and visualizing different components of the wrong warp
-- See the respective files for more information

local map_viewer = require("modules/map-viewer")
local mod_6_table = require("modules/mod-6-table")
local obj_val = require("modules/object-data-values")
local memory_writes = require("modules/memory-writes")
local ram_map = require("modules/ram-map")
local write_log = require("modules/write-log")
local obj_spawner_pointers = require("modules/obj-spawner-pointers")
local obj_idx_range = require("modules/obj-idx-range")
local obj_table = require("modules/obj-table")

-- Initialization

local show_extended_info_params = {
	x = client.screenwidth() - 64,
	y = client.screenheight() - 80,
	w = 32,
	h = 32,
	label = "Show extended\ninformation",
	value = false
}
show_extended_info_checkbox = osd.checkbox(show_extended_info_params, nil)

local show_map_viewer_params = {
	x = client.screenwidth() - 64,
	y = client.screenheight() - 128,
	w = 32,
	h = 32,
	label = "Show Map Viewer",
	value = false
}
show_map_viewer_checkbox = osd.checkbox(show_map_viewer_params, nil)

-- Main script loop, execute every frame
while true do
	mouse.update()

	obj_val.get()

	if show_map_viewer_checkbox.value then
		map_viewer.show()
	end


	obj_val.show()
	ram_map.show()
	write_log.show()

	if show_extended_info_checkbox.value then
		mod_6_table.show()
		obj_spawner_pointers.show()
		obj_idx_range.show()
		obj_table.show()
	end

	osd.update()

	-- We need yield() to interact with the dynamic elements on the screen
	-- Since it's too slow with the extended HUD active, if the emu is unpaused, 
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
