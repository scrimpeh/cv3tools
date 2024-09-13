-- Provides a RAM map for the game, so that important values are monitored
-- You can set specific values to "important" so that you are notified when the game
-- clobbers them

-- When displaying, the game distinguishes 3 types of values
-- - bytes (1 byte)
-- - words (2 bytes)
-- - tables (n bytes)
-- bytes and words are both considered to be singular values, with tables, individual values will
-- be displayed

local ram_map_data = {}

-- Definitions / Configuration

-- First off, types, these determine how the memory values and highlights to them are displayed

local GAME_VALUE_TYPES = {
	-- Unclassified values
	["unknown"]         = { fg = 0x00000000, bg = 0x00000000 },
	-- Do not highlight these values, they are never interesting
	["ignore"]          = { fg = 0x00000000, bg = 0x00000000 },
	-- Technical values involved in the working of the wrong warp itself
	-- OBJ table values loaded from the static OBJ data
	["technical_obj_1"] = { fg = 0xFF00CCCC, bg = 0x50FFFFFF },
	-- OBJ table values not loaded from the static obj data
	["technical_obj_2"] = { fg = 0xFFFF00FF, bg = 0x50FFFFFF },
	-- Used when determining the current object to load
	["technical_read"] =  { fg = 0xFFFF0000, bg = 0x50FFFFFF },
	-- Used when writing the object to memory
	["technical_write"] = { fg = 0xFF00CCCC, bg = 0x50FFFFFF },
	-- Regular game value, print its name when hovering, but do not hover over it
	["value"]           = { fg = 0x00000000, bg = 0x00000000 },
	-- Highlight these game values, we want to be informed when they change
	["highlight"]       = { fg = 0xFFFF0000, bg = 0x50FFFFFF },
	-- These values are the most interesting
	["target"]          = { fg = 0xFFFFC000, bg = 0x50FFFFFF }
}

local function unknown_value(adr) 
	return {
		desc = "?",
		u = adr,
		j = adr,
		adr = adr,
		size = 1,
		type_desc = "unknown"
	}
end

-- This attempts to be a mostly complete RAM map of the game
-- Most values are courtesy of https://datacrystal.tcrf.net/wiki/Castlevania_III:_Dracula%27s_Curse/RAM_map
-- The values are ordered by their U address
-- Note that a * indicates that the description was copied over, but I don't quite understand
-- the meaning yet.
local game_values = {
	-- $000 - $03F
	{ desc = "Dynamic OBJ PTR",   u = 0x00, j = 0x00, size =  2, type_desc = "technical_write" },
	{ desc = "Temp memory",       u = 0x02, j = 0x02, size =  7, type_desc = "ignore"          },
	{ desc = "OBJ Camera Offset", u = 0x09, j = 0x09, size =  1, type_desc = "technical_write" },
	{ desc = "OBJ Camera Hi",     u = 0x0A, j = 0x0A, size =  1, type_desc = "technical_write" },
	{ desc = "Temp memory",       u = 0x0B, j = 0x0B, size = 12, type_desc = "ignore"          },
	{ desc = "Gamestate",         u = 0x18, j = 0x18, size =  1, type_desc = "target"          },
	{ desc = "PRNG",              u = 0x1F, j = 0x20, size =  1, type_desc = "value"           },
	{ desc = "ROM Bank",          u = 0x21, j = 0x23, size =  1, type_desc = "highlight"       },
	{ desc = "Prev ROM Bank",     u = 0x22, j = 0x24, size =  1, type_desc = "highlight"       },
	{ desc = "Buttons Pressed",   u = 0x26, j = 0x28, size =  2, type_desc = "value"           },
	{ desc = "Buttons Held",      u = 0x28, j = 0x2A, size =  2, type_desc = "value"           },
	{ desc = "Sub State",         u = 0x2A, j = 0x2C, size =  1, type_desc = "highlight"       },
	{ desc = "Is Paused",         u = 0x2B, j = 0x2D, size =  1, type_desc = "value"           },
	{ desc = "Boss Defeated",     u = 0x2C, j = 0x2E, size =  1, type_desc = "value"           },
	{ desc = "Block",             u = 0x32, j = 0x34, size =  1, type_desc = "target"          },
	{ desc = "Sublevel",          u = 0x33, j = 0x35, size =  1, type_desc = "target"          },
	{ desc = "Room",              u = 0x34, j = 0x36, size =  1, type_desc = "target"          },
	{ desc = "Lives",             u = 0x35, j = 0x37, size =  1, type_desc = "value"           },
	{ desc = "Score",             u = 0x36, j = 0x44, size =  3, type_desc = "value"           },
	{ desc = "Player",            u = 0x39, j = 0x47, size =  1, type_desc = "highlight"       },
	{ desc = "Partner",           u = 0x3A, j = 0x48, size =  1, type_desc = "highlight"       },
	{ desc = "Partner Active",    u = 0x3B, j = 0x49, size =  1, type_desc = "value"           },
	{ desc = "Health",            u = 0x3C, j = 0x4A, size =  1, type_desc = "value"           },
	{ desc = "Boss Health",       u = 0x3D, j = 0x4B, size =  1, type_desc = "value"           },
	{ desc = "Next Life PTS",     u = 0x3E, j = 0x4C, size =  1, type_desc = "value"           },
	-- $040 - $07F
	{ desc = "CHR Banks",         u = 0x46, j = 0x38, size =  8, type_desc = "value"           },
	{ desc = "Camera",            u = 0x56, j = 0x53, size =  2, type_desc = "highlight"       },
	{ desc = "Camera Subpixel",   u = 0x58, j = 0x55, size =  1, type_desc = "value"           },
	{ desc = "Load Column L",     u = 0x59, j = 0x56, size =  1, type_desc = "value"           },
	{ desc = "Load Column R",     u = 0x5A, j = 0x57, size =  1, type_desc = "value"           },
	{ desc = "Tiles Loaded L",    u = 0x5B, j = 0x58, size =  1, type_desc = "value"           },
	{ desc = "Tiles Loaded R",    u = 0x5C, j = 0x59, size =  1, type_desc = "value"           },
	{ desc = "Tile Load PTR",     u = 0x5D, j = 0x5A, size =  2, type_desc = "value"           },
	{ desc = "Palette PTR",       u = 0x5F, j = 0x5C, size =  2, type_desc = "value"           },
	{ desc = "Nametable Wrt PTR", u = 0x61, j = 0x5E, size =  2, type_desc = "value"           },
	{ desc = "Tile Load ID",      u = 0x63, j = 0x60, size =  1, type_desc = "value"           },
	{ desc = "Char Switch Timer", u = 0x64, j = 0x61, size =  1, type_desc = "value"           },
	{ desc = "Scroll Direction",  u = 0x65, j = 0x62, size =  1, type_desc = "value"           },
	{ desc = "View Refreshed*",   u = 0x66, j = 0x63, size =  1, type_desc = "value"           },
	{ desc = "Update View*",      u = 0x67, j = 0x64, size =  1, type_desc = "value"           },
	{ desc = "Room Orientation",  u = 0x68, j = 0x65, size =  1, type_desc = "value"           },
	{ desc = "Stair PTR",         u = 0x69, j = 0x66, size =  2, type_desc = "value"           },
	{ desc = "Misc (Menu/Door)",  u = 0x6B, j = 0x68, size =  1, type_desc = "value"           },
	{ desc = "X Backup*",         u = 0x6C, j = 0x69, size =  1, type_desc = "value"           },
	{ desc = "Drawing State*",    u = 0x6D, j = 0x6A, size =  1, type_desc = "value"           },
	{ desc = "View Speed*",       u = 0x6E, j = 0x6B, size =  1, type_desc = "value"           },
	{ desc = "PPU Scroll",        u = 0x6F, j = 0x6C, size =  2, type_desc = "value"           },
	{ desc = "Room Size",         u = 0x71, j = 0x6E, size =  1, type_desc = "value"           },
	{ desc = "64 Pixel Block",    u = 0x76, j = 0x73, size =  1, type_desc = "technical_read"  },
	{ desc = "1st OBJ Block",     u = 0x77, j = 0x74, size =  1, type_desc = "value"           },
	{ desc = "Boss Room",         u = 0x78, j = 0x75, size =  1, type_desc = "value"           },
	{ desc = "Timer",             u = 0x7E, j = 0x7B, size =  2, type_desc = "highlight"       },
	-- $080 - $0FF
	{ desc = "Hit Invincibility", u = 0x80, j = 0x7D, size =  1, type_desc = "value"           },
	{ desc = "Damage Received",   u = 0x81, j = 0x7E, size =  1, type_desc = "value"           },
	{ desc = "PC Height",         u = 0x82, j = 0x7F, size =  1, type_desc = "value"           },
	{ desc = "Hearts",            u = 0x84, j = 0x81, size =  1, type_desc = "highlight"       },
	{ desc = "Main Subweapon",    u = 0x85, j = 0x82, size =  1, type_desc = "highlight"       },
	{ desc = "Alt Subweapon",     u = 0x86, j = 0x83, size =  1, type_desc = "highlight"       },
	{ desc = "Main Shot Multi",   u = 0x87, j = 0x84, size =  1, type_desc = "value"           },
	{ desc = "Alt Shot Multi",    u = 0x88, j = 0x85, size =  1, type_desc = "value"           },
	{ desc = "On Moving Platf.",  u = 0x8B, j = 0x88, size =  1, type_desc = "value"           },
	{ desc = "Whip Spark Timer",  u = 0x8C, j = 0x89, size =  1, type_desc = "value"           },
	{ desc = "Whip Level",        u = 0x8E, j = 0x8B, size =  1, type_desc = "value"           },
	{ desc = "Partner Weapon LV", u = 0x8E, j = 0x8C, size =  1, type_desc = "value"           },
	{ desc = "Room Spawner PTR",  u = 0x98, j = 0x95, size =  2, type_desc = "technical_read"  },
	{ desc = "Room Tile PTR",     u = 0x9A, j = 0x97, size =  2, type_desc = "value"           },
	{ desc = "Multiplier Drop",   u = 0x9C, j = 0x99, size =  1, type_desc = "value"           },
	{ desc = "Partner State",     u = 0xAA, j = 0xA7, size =  1, type_desc = "target"          },
	{ desc = "Stopwatch Active",  u = 0xAB, j = 0xA8, size =  1, type_desc = "value"           },
	{ desc = "Stopwatch Timer",   u = 0xAC, j = 0xA9, size =  1, type_desc = "value"           },
	{ desc = "Potion Timer",      u = 0xAD, j = 0xAA, size =  1, type_desc = "value"           },
	-- $700 - $7FF
	{ desc = "OBJ Type",    u = 0x7C2, j = 0x7C2, size = 6, type_desc = "technical_obj_1" },
	{ desc = "OBJ State",   u = 0x7C8, j = 0x7C8, size = 6, type_desc = "technical_obj_2" },
	{ desc = "OBJ Timer",   u = 0x7CE, j = 0x7CE, size = 6, type_desc = "technical_obj_1" },
	{ desc = "OBJ Y",       u = 0x7D4, j = 0x7D4, size = 6, type_desc = "technical_obj_1" },
	{ desc = "OBJ X",       u = 0x7DA, j = 0x7DA, size = 6, type_desc = "technical_obj_1" },
	{ desc = "OBJ X Hi",    u = 0x7E0, j = 0x7E0, size = 6, type_desc = "technical_obj_2" },
	{ desc = "OBJ 7",       u = 0x7E6, j = 0x7E6, size = 6, type_desc = "technical_obj_1" },
	{ desc = "Hard Mode",   u = 0x7F6, j = 0x7F6, size = 1, type_desc = "technical_read"  },
	{ desc = "Player Name", u = 0x7F8, j = 0x7F8, size = 8, type_desc = "value"           }
}

-- Initialization

local ram_values = {}

for _, val in pairs(game_values) do
	local adr = val.u
	if game_type == 'jp' then
		adr = val.j
	end
	for i = 0, val.size - 1, 1 do
		ram_values[adr + i] = val

		-- Set some extra properties
		val.adr = adr
		val.value_type = GAME_VALUE_TYPES[val.type_desc]
	end
end

function ram_map_data.get_value(adr)
	local value = ram_values[adr]
	return value or unknown_value(adr)
end

function ram_map_data.read_value(adr)
	local value = ram_map_data.get_value(adr)
	if value.size == 2 then
		return memory.read_u16_le(value.adr)
	else
		return memory.readbyte(adr)
	end
end

ram_map_data.values = ram_values

return ram_map_data