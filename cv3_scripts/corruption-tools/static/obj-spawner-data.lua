-- Collects static information from the ROM about OBJ Spawners for each room
-- This information is collected once at the start of the script and available
-- to the script at runtime.
-- The game has three levels of indirection from block to sublevel to room,
-- and the information is divided into two chunks in the ROM, making it 
-- quite complicated

local block_info = require("static/block-info")

local obj_spawner_data = {}

-- Definitions

-- This is the entry point at the block level

BLK_OBJ_SPAWNERS_ROM = val(0x2937F, 0x292AE)
BLK_OBJ_SPAWNERS_ADR = prg_bank(BLK_OBJ_SPAWNERS_ROM)

-- Initialization Functions

local function get_room_data(block, sublevel, sublevel_rom)
	-- Third level, rooms for sublevel
	local rooms = {}
	local first_room_adr = memory.read_u16_le(sublevel_rom, "PRG ROM")
	for i = 0, block_info[block].rooms[sublevel] - 1 do
		rooms[i] = {
			adr = first_room_adr + i * 2,
			count = block_info[block].rooms[sublevel]
		}
	end
	return rooms
end

local function get_sublevel_data(block, block_rom)
	-- Second level, sublevels for block
	local sublevels = {}
	local first_sublevel_adr = memory.read_u16_le(block_rom, "PRG ROM")
	for i = 0, block_info[block].sublevels - 1, 1 do
		local sublevel_rom = prg_rom(first_sublevel_adr) + i * 2
		sublevels[i] = {
			adr = prg_bank(sublevel_rom),
			count = block_info[block].sublevels,
			rooms = get_room_data(block, i, sublevel_rom)
		}
	end
	return sublevels
end

local function get_block_data()
	-- First level, blocks
	local blocks = {}
	for i = 0, block_info.count - 1, 1 do
		local block_rom = BLK_OBJ_SPAWNERS_ROM + i * 2
		blocks[i] = {
			adr = prg_bank(block_rom),
			sublevels = get_sublevel_data(i, block_rom)
		}
	end
	return blocks
end

local block_data = get_block_data()

-- Functions

function obj_spawner_data.get_block(i_room)
	return block_data[i_room.block]
end

function obj_spawner_data.get_sublevel(i_room)
	return obj_spawner_data.get_block(i_room).sublevels[i_room.sublevel]
end

function obj_spawner_data.get_room(i_room)
	return obj_spawner_data.get_sublevel(i_room).rooms[i_room.room]
end


local function create_range(i_room, adr)
	return {
		i_room_start = i_room,
		start_adr = adr,
		count = 1
	}
end

-- Breaks up ranges into contiguous blocks of ROM space
local function get_ranges(i_room_get_func, iterator_func)
	local ranges = {}

	local i_cur = iterator_func(nil)
	local start_adr = i_room_get_func(i_cur).adr
	local cur_range = create_range(i_cur, start_adr)

	while true do
		local i_next = iterator_func(i_cur)

		local adr = i_room_get_func(i_cur).adr
		local next_adr = nil
		if i_next ~= nil then
			next_adr = i_room_get_func(i_next).adr
		end

		if adr + 2 ~= next_adr then
			cur_range.i_room_end = i_cur
			cur_range.end_adr = adr
			table.insert(ranges, cur_range)
			if i_next ~= nil then
				cur_range = create_range(i_next, next_adr)
			else
				return ranges
			end
		else
			cur_range.count = cur_range.count + 1
		end

		i_cur = i_next
	end
end

local function get_block_ranges()
	return get_ranges(obj_spawner_data.get_sublevel, block_info.next_sublevel)
end

local function get_room_ranges()
	return get_ranges(obj_spawner_data.get_room, block_info.next_room)
end

obj_spawner_data.sublevel_ranges = get_block_ranges()
obj_spawner_data.room_ranges = get_room_ranges()

return obj_spawner_data