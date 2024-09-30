-- The OBJ Index Range shows where obj_idx_ptr ($98) points to. Ordinarily, the value of the pointer is
-- determined by the current room index, but going to an invalid room or corrupting the value using memory
-- corruption can set the pointer to any value. We therefore show the entire 6502 address range.
-- The range is compressed and specifically highlights the important areas, i.e. the usual PRG ROM space
-- where the pointer is intended to point, and zero page, since that is also very common

local block_info = require("static/block-info")
local obj_spawner_data = require("static/obj-spawner-data")

local obj_idx_data = {}

-- Initialization

-- Initialization function - there's some valid ranges that obj_idx_pointer can point to
-- Gather them from the ROM using the previously calculated room info
local function get_valid_ranges()
	local i_room = block_info.next_room(nil)
	local groups = {}
	while i_room do
		local room_adr = obj_spawner_data.get_room(i_room).adr
		local ptr = memory.read_u16_le(prg_rom(room_adr), "PRG ROM")
		-- Each room occupies multiple indices
		-- We don't know exactly how large each room is (and I don't care to write it down manually)
		-- so we just use a heuristic to divide the pointers into groups

		-- We first get all groups and then successively try to merge adjacent ones until we can't anymore
		-- This is quadratic, but we only have to do this once
		table.insert(groups, { min_value = ptr, max_value = ptr, count = 1 })
		i_room = block_info.next_room(i_room)
	end

	local read_groups = groups
	local write_groups = {}
	local merged_any = true
	while merged_any do
		merged_any = false
		for i = 1, #read_groups, 1 do
			local cur_read = read_groups[i]
			if cur_read then
				table.insert(write_groups, cur_read)
				for j = i + 1, #read_groups, 1 do
					if read_groups[j] then
						-- Merge nearby groups - we expect to only have 2 at the end
						local start_diff = math.abs(cur_read.min_value - read_groups[j].max_value)
						local end_diff = math.abs(cur_read.max_value - read_groups[j].min_value)
						if start_diff < 256 or end_diff < 256 then
							cur_read.min_value = math.min(cur_read.min_value, read_groups[j].min_value)
							cur_read.max_value = math.max(cur_read.max_value, read_groups[j].max_value)
							cur_read.count = cur_read.count + 1
							read_groups[j] = nil
							merged_any = true
						end
					end
				end
			end
		end

		-- Swap write and read groups
		read_groups = write_groups
		write_groups = {}
	end
	-- TODO: Add a static offset to the highest value in each group to account for the size of the room
	return read_groups
end

obj_idx_data.ranges = get_valid_ranges()

-- Functions

return obj_idx_data