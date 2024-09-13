-- Static info about each block in the game
-- Provides utilities for other parts of the script to iterate through each room

local block_info = {}

-- Static Functions

local function zero_index(arr)
	for i = 1, #arr, 1 do
		arr[i - 1] = arr[i]
	end
	arr[#arr] = nil
	return arr
end

local function define_block(letter, name, sublevel_letters, rooms)
	local i = block_info.count or 0
	block_info[i] = {
		name = name,
		letter = letter,
		sublevels = #sublevel_letters,
		sublevel_letters = zero_index(sublevel_letters),
		rooms = zero_index(rooms)
	}
	block_info.count = i + 1
end

define_block("1", "Village",     { "01", "02", "03", "04" },                   { 1, 4, 2, 1 })
define_block("2", "Clock Tower", { "01", "02", "03", "04", "05", "06" },       { 3, 3, 3, 3, 3, 3 })
define_block("3", "Mad Forest",  { "00", "01", "02", "03", "04" },             { 2, 1, 2, 3, 2 })
define_block("4", "Ghost Ship",  { "0A", "0B", "0C", "0D", "0E" },             { 3, 2, 2, 2, 3 })
define_block("5", "Death Tower", { "0A", "0B", "0C" },                         { 3, 3, 3 })
define_block("6", "Bridge",      { "0A", "0B", "0C", "0D" },                   { 1, 1, 2, 2 })
define_block("4", "Swamp",       { "01", "02", "03" },                         { 2, 1, 3 })
define_block("5", "Caves",       { "01", "02", "03", "04", "05", "06", "07" }, { 2, 1, 1, 1, 2, 2, 1 })
define_block("6", "Sunken City", { "01", "02", "03", "04", "05" },             { 2, 1, 2, 1, 1 })
define_block("6", "Crypt",       { "01", "02" },                               { 2, 3 })
define_block("7", "Cliffs",      { "01", "02", "03", "04", "05", "06", "07" }, { 2, 1, 1, 2, 3, 2, 3 })
define_block("7", "Aquarius",    { "0A", "0B", "0C" },                         { 2, 2, 3 })
define_block("8", "Deva Vu",     { "01", "02", "03" },                         { 2, 2, 1 })
define_block("9", "Riddle",      { "01", "02", "03", "04" },                   { 3, 3, 3, 2 })
define_block("A", "Pressure",    { "01", "02", "03" },                         { 3, 2, 2, 2 })

-- Functions

function block_info.get_i_room(block, sublevel, room)
	return {
		block = block,
		sublevel = sublevel,
		room = room
	}
end

function block_info.first_room() 
	return block_info.get_i_room(0, 0, 0)
end

function block_info.last_room() 
	local block = block_info.count - 1
	local sublevel = block_info[block_info.count - 1].sublevels - 1
	local room = block_info[block_info.count - 1].rooms[sublevel]
	return block_info.get_i_room(block, sublevel, room)
end

function block_info.next_block(i_room)
	if i_room == nil then
		return block_info.first_room()
	end

	if i_room.block < block_info.count - 1 then
		room = 0
		sublevel = 0
		block = block + 1
	else
		return nil
	end

	return block_info.get_i_room(block, sublevel, 0)
end


function block_info.next_sublevel(i_sublevel)
	if i_sublevel == nil then
		return block_info.first_room()
	end

	local block = i_sublevel.block
	local sublevel = i_sublevel.sublevel

	local cur_block_info = block_info[i_sublevel.block]

	if sublevel < cur_block_info.sublevels - 1 then
		room = 0
		sublevel = sublevel + 1
	elseif block < block_info.count - 1 then
		room = 0
		sublevel = 0
		block = block + 1
	else
		return nil
	end

	return block_info.get_i_room(block, sublevel, 0)
end

function block_info.next_room(i_room)
	if i_room == nil then
		return block_info.first_room()
	end

	local block = i_room.block
	local sublevel = i_room.sublevel
	local room = i_room.room

	local cur_block_info = block_info[i_room.block]

	if room < cur_block_info.rooms[sublevel] - 1 then
		room = room + 1
	elseif sublevel < cur_block_info.sublevels - 1 then
		room = 0
		sublevel = sublevel + 1
	elseif block < block_info.count - 1 then
		room = 0
		sublevel = 0
		block = block + 1
	else
		return nil
	end

	return block_info.get_i_room(block, sublevel, room)
end

return block_info
