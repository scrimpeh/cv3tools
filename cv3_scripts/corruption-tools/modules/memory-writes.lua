-- This module highlights the (corrupt) memory writes that the game performs
-- during the OBJ loading routine.
-- It manages and saves the writes. The RAM map module is responsible for displaying
-- those writes

local ram_map_data = require("static/ram-map-data")
local obj_val = require("modules/object-data-values")
local write_log = require("modules/write-log")

local memory_writes = {}

-- Configurations

memory_writes.write_ttl = 32
memory_writes.show_corrupted_writes_only = true

-- Definitions

local corrupted_writes_userdata_name = "cv3_corruption_visualizercorrupted_writes"

-- Initialization

memory_writes.recent = {}
memory_writes.corrupted = {}

userdata.set(corrupted_writes_userdata_name, nil)

-- Internal Functions

-- Sync the corrupted writes with the savestate - write them to userdata
local function corrupted_writes_to_string(writes)
	local data = {}
	for adr, cur_write in pairs(writes) do
		-- If the current address is a 2-byte value, read that
		local line = string.format("%d,%d,%d,%d", adr, cur_write.value, cur_write.count, cur_write.full_value)
		table.insert(data, line)
	end
	return table.concat(data, ";")
end

local mem_write_frame = nil

local function corrupted_writes_from_string(data)
	if not data or data == "" then
		return {}
	end
	local writes = {}
	for value in string.gmatch(data, "[^;]*") do
		local _, _, adr, value, count, full_value = string.find(value, "(%d+),(%d+),(%d+),(%d+)")
		writes[tonumber(adr)] = {
			value = tonumber(value),
			count = tonumber(count),
			full_value = tonumber(full_value)
		}
	end
	return writes
end

local function set_corrupted_writes()
	local userdata_str = userdata.get(corrupted_writes_userdata_name)
	memory_writes.corrupted = corrupted_writes_from_string(userdata_str)
end

local function format_value(adr)
	local game_value = ram_map_data.get_value(adr)
	if game_value.type_desc ~= "unknown" and game_value.type_desc ~= "ignore" then
		return string.format("  %s", game_value.desc)
	end
	return ""
end

local function format_value_detailed(adr)
	local game_value = ram_map_data.get_value(adr)
	if game_value.type_desc ~= "unknown" and game_value.type_desc ~= "ignore" then
		local highlight_indicator = ""
		if game_value.type_desc == "target" then
			highlight_indicator = " !!"
		end
		if game_value.size == 1 then
			return game_value.desc .. highlight_indicator
		elseif game_value.size == 2 then
			if game_value.adr ~= adr then
				return game_value.desc ..  " (Hi)" .. highlight_indicator
			end
			return game_value.desc .. " (Lo)" .. highlight_indicator
		else
			return string.format("%s [%d]%s", game_value.desc, adr - game_value.adr, highlight_indicator)
		end
	end
	return "?"
end

-- Hands the current RAM write off to write_log to be output on the screen
local function add_write_message(ram_write)
	if memory_writes.show_corrupted_writes_only and ram_write.mod_6_offs < 6 then
		return
	end

	-- Create a summary showing what got overwritten to immediately display on the screen
	local summary_lines = {
		string.format("[%d]", emu.framecount())
	}
	local important = false
	for _, cur_write in pairs(ram_write.writes) do
		local fmt = "(%03X) %03X = %02X%s"
		local value_name = format_value(cur_write.write_adr)
		local line = string.format(fmt, cur_write.table_adr, cur_write.write_adr, cur_write.value, value_name)
		if ram_map_data.get_value(cur_write.write_adr).type_desc == "target" then
			important = true
		end
		table.insert(summary_lines, line)
	end
	local summary = table.concat(summary_lines, "\n")

	-- And a more in-depth explanation that can be looked at by the user by hovering
	local detail_lines = {
		string.format("[%d]", emu.framecount()),
		"-( Info )--------------------------------------------",
		string.format("Spawner PTR ($%02X): $%04X + Cam Offset ($%02X): $%02X", OBJ_IDX_PTR_ADR, ram_write.obj_idx_ptr, ROOM_READ_64_ADR, ram_write.read_64),
		string.format("Value: %02X, reads OBJ table @ $%04X", ram_write.obj_idx, ram_write.obj_ptr),
		string.format("Data:  %s", table.concat(draw_format_hex(obj_val.obj_data), " ")),
		"-( Writes )------------------------------------------",
	}
	for _, cur_write in pairs(ram_write.writes) do
		local fmt = "(%03X,%02X) %03X = %02X : %s"
		local value_name = format_value_detailed(cur_write.write_adr)
		local line = string.format(fmt, cur_write.table_adr, ram_write.mod_6_offs, cur_write.write_adr, cur_write.value, value_name)
		table.insert(detail_lines, line)
	end
	local detail = table.concat(detail_lines, "\n")

	write_log.add(summary, detail, important)
end

local function add_corrupted_write(write_adr, write_value)
	-- Get the full corrupted value
	local full_value = ram_map_data.read_value(write_adr)

	-- Replace or add the new value
	if memory_writes.corrupted[write_adr] ~= nil then
		memory_writes.corrupted[write_adr].value = write_value
		memory_writes.corrupted[write_adr].count = memory_writes.corrupted[write_adr].count + 1
		memory_writes.corrupted[write_adr].full_value = full_value
	else
		memory_writes.corrupted[write_adr] = {
			value = write_value,
			count = 1,
			full_value = full_value
		}
	end
end

-- This function gets executed before the OBJ tables are filled
-- we gather some important values for the execution
local function pre_mem_write()
	mem_write_frame = nil

	-- First - check if we are in the right bank first
	local prg_bank = memory.readbyte(val(0x21, 0x23))
	if prg_bank ~= val(0x94, 0x0A) then
		return
	end

	-- We need to update the values since they were already updated since the start of the frame
	obj_val.get()

	-- The post_mem_write function will pick up from here after the memory write is executed
	mem_write_frame = emu.framecount()
end

-- Reads the values from memory after they were written
-- It is very difficult to predict which values the game is gonna write exactly (I tried), but the 
-- location where the writes happened is always static. the only thing to note is that if the first byte
-- of the OBJ struct is 0, no further bytes are written
local function get_write_values(mod_6_offs)
	local write_values = {}
	table.insert(write_values, { table_adr = 0x7C2, value = memory.readbyte(0x7C2 + mod_6_offs) })
	if write_values[1].value == 0 then
		return write_values
	end
	table.insert(write_values, { table_adr = 0x7DA, value = memory.readbyte(0x7DA + mod_6_offs) })
	table.insert(write_values, { table_adr = 0x7E0, value = memory.readbyte(0x7E0 + mod_6_offs) })
	table.insert(write_values, { table_adr = 0x7D4, value = memory.readbyte(0x7D4 + mod_6_offs) })
	table.insert(write_values, { table_adr = 0x7E6, value = memory.readbyte(0x7E6 + mod_6_offs) })
	table.insert(write_values, { table_adr = 0x7CE, value = memory.readbyte(0x7CE + mod_6_offs) })
	table.insert(write_values, { table_adr = 0x7C8, value = memory.readbyte(0x7C8 + mod_6_offs) })
	return write_values
end

local function post_mem_write()
	-- Basic safety check to ensure the pre and post functions actually correspond to the same function call
	if mem_write_frame == nil or mem_write_frame ~= emu.framecount() then
		mem_write_frame = nil
		return
	end
	mem_write_frame = nil

	local ram_write = {
		-- This RAM write should come from OBJ #obj_idx...
		obj_idx_ptr = obj_val.obj_idx_pointer,
		obj_idx = obj_val.obj_idx,
		-- which corresponds to this pointer, which is copied to $00, $01 before reading
		-- note that it could be overwritten midway through, leading the OBJ to be written from wherever
		obj_ptr = obj_val.obj_pointer,

		read_64 = obj_val.room_read_64,
		mod_6_offs = MOD_6_TABLE_DATA[obj_val.room_read_64 + 1],
		writes = {},
		ttl = memory_writes.write_ttl
	}
	local has_corrupted_write = ram_write.mod_6_offs >= 6
	for _, write_value in pairs(get_write_values(ram_write.mod_6_offs)) do
		local write_adr = (write_value.table_adr + ram_write.mod_6_offs) & 0x7FF
		local cur_write = {
			table_adr = write_value.table_adr,
			write_adr = write_adr,
			value = write_value.value
		}
		table.insert(ram_write.writes, cur_write)
		if has_corrupted_write then
			add_corrupted_write(write_adr, write_value.value)
		end
	end

	if has_corrupted_write then
		local userdata_str = corrupted_writes_to_string(memory_writes.corrupted)
		userdata.set(corrupted_writes_userdata_name, userdata_str)
	end
	add_write_message(ram_write)

	memory_writes.recent[ram_write.mod_6_offs] = ram_write
end

-- Register events

local pre_mem_write_pre_event_name = "cv3_corruption_visualizer_ram_map_pre_write"
event_unregister(pre_mem_write_pre_event_name)
event.on_bus_exec(pre_mem_write, val(0x8132, 0x813C), pre_mem_write_pre_event_name)

local post_mem_write_post_event_name = "cv3_corruption_visualizer_ram_map_post_write"
event_unregister(post_mem_write_post_event_name)
event.on_bus_exec(post_mem_write, val(0x8178, 0x8182), post_mem_write_post_event_name)


local on_loadstate_event_name = "cv3_corruption_visualizer_ram_map_on_loadstate"
event_unregister(on_loadstate_event_name)
event.onloadstate(set_corrupted_writes, on_loadstate_event_name)

-- Functions

function memory_writes.clear_corrupted_writes() 
	memory_writes.corrupted = {}
	userdata.set(corrupted_writes_userdata_name, nil)
end

function memory_writes.decrement_write_ttl()
	if client.ispaused() then
		return
	end
	local i, ram_write = next(memory_writes.recent, nil)
	while i do
		ram_write.ttl = ram_write.ttl - 1
		if ram_write.ttl == 0 then
			memory_writes.recent[ram_write.mod_6_offs] = nil
		end
		i, ram_write = next(memory_writes.recent, i)     
	end
end

return memory_writes