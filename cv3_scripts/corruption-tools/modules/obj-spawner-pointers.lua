-- To find the current index into the object spawner table, the game finds a matching pointer for the current room.
-- This uses three levels of indirection, from block, to sublevel, to room, resulting in three pointer tables in the ROM
-- The tables for the sublevel and room data are split into two separate pieces in the ROM, and going significantly OOB
-- can result in us reading the tables out of bounds. This is relevant for the current wrong warp.
-- We show these tables here.

local block_info = require("static/block-info")
local obj_spawner_data = require("static/obj-spawner-data")
local obj_val = require("modules/object-data-values")

local obj_spawner_pointers = {}

-- Configurations

local row_0_y_offs = 138
local row_1_y_offs = 98
local row_h = 10
local oob_dot_offs_l = 16 + row_h
local bar_label_offs = 5
local oob_dot_offs_r = 16

local block_w = 10
local sublevel_w = 15
local room_w = 10

local sublevel_gap = 64
local room_gap = 128

local tick_label_offs = 20

-- Each drawing function assumes as origin the top left corner of the bar

-- Draw Block to Sublevel
local function show_blocks(draw_x, draw_y)
	gui.text(draw_x - 136, draw_y + bar_label_offs, "Block Data")
	gui.drawString(draw_x, draw_y - tick_label_offs, string.format("$%04X", BLK_OBJ_SPAWNERS_ADR))

	-- Draw box for all blocks
	local w = block_w * block_info.count
	gui.drawRectangle(draw_x, draw_y, w, row_h, 0xFFFFFFFF ,0)

	-- Draw vertical ticks for each block
	for i = 0, block_info.count - 1, 1 do
		local x = draw_x + i * block_w
		gui.drawLine(x, draw_y, x, draw_y + row_h, 0xC0FFFFFF)
	end

	-- Highlight current block
	if obj_val.block < block_info.count then
		local x = draw_x + obj_val.block * block_w
		gui.drawRectangle(x, draw_y, room_w, row_h, 0xFFFF00FF, 0xFFFF0000)
	else
		draw_circle(draw_x + w + oob_dot_offs_r, draw_y, row_h, 0xFFFF0000)
	end
end

-- Draw sublevel to room pointers
local function show_sublevels(draw_x, draw_y)
	gui.text(draw_x - 178, draw_y + bar_label_offs, "Sublevel Data")

	-- If the current sublevel object pointer somehow points to before the start of the table, draw a circle
	if obj_val.sublevel_idx_adr < obj_spawner_data.get_sublevel(block_info.first_room()).adr then
		draw_circle(draw_x - oob_dot_offs_l, draw_y, row_h, 0xFFFF0000)
	end

	-- Draw sublevels range by range
	for i, range in ipairs(obj_spawner_data.sublevel_ranges) do
		local w = range.count * sublevel_w
		gui.drawRectangle(draw_x, draw_y, w, row_h, 0xFFFFFFFF, 0)

		-- Draw a connecting bar to the next range
		-- We do this early so an "address overshoot" dot can still be drawn over it
		if i < #obj_spawner_data.sublevel_ranges then
			gui.drawRectangle(draw_x + w + 1, draw_y, sublevel_gap - 1, row_h, 0xFF666666, 0xFF222222)
		end

		-- Iterate through the range to draw boxes and the current block index
		local i_room = range.i_room_start
		for j = 0, range.count - 1, 1 do
			local x = draw_x + j * sublevel_w
			gui.drawLine(x, draw_y, x, draw_y + row_h, 0xC0FFFFFF)

			-- If we are at the start of a block, draw a tick and mark the current address
			if i_room.sublevel == 0 then
				local block_adr = obj_spawner_data.get_block(i_room).adr
				gui.drawString(x, draw_y - tick_label_offs, string.format("$%04X", block_adr))
				draw_tick(x, draw_y + row_h, 6)
			end

			-- Highlight current block
			if i_room.block == obj_val.block then
				gui.drawRectangle(x, draw_y, sublevel_w, row_h, 0xFFFF00FF, 0xFF800080)
			end

			i_room = block_info.next_sublevel(i_room)
		end

		-- Check the current sublevel index pointer is located in this range. Highlight one box,
		-- or draw a dot after the current range
		if range.start_adr <= obj_val.sublevel_idx_adr then
			if obj_val.sublevel_idx_adr < range.end_adr + 2 then
				local offs = (obj_val.sublevel_idx_adr - range.start_adr) / 2
				local x = draw_x + offs * sublevel_w
				gui.drawRectangle(x, draw_y, sublevel_w, row_h, 0xFFFF00FF, 0xFFFF0000)
			else
				local next_range = obj_spawner_data.sublevel_ranges[i + 1]
				if next_range == nil or obj_val.sublevel_idx_adr < next_range.start_adr then
					draw_circle(draw_x + w + oob_dot_offs_r, draw_y, row_h, 0xFFFF0000)
				end
			end
		end

		-- Draw an extra tick at the end of the range
		draw_tick(draw_x + w, draw_y + row_h, 6)

		draw_x = draw_x + w + sublevel_gap
	end
end

-- Draw room pointers to camera pointers
local function show_rooms(draw_x, draw_y)
	gui.text(draw_x - 140, draw_y + bar_label_offs, "Room Data")

	-- If the current room object pointer somehow points to before the start of the table, draw a circle
	if obj_val.room_idx_adr < obj_spawner_data.get_room(block_info.first_room()).adr then
		draw_circle(draw_x - oob_dot_offs_l, draw_y, row_h, 0xFFFF0000)
	end

	-- Draw room range by range
	for i, range in ipairs(obj_spawner_data.room_ranges) do
		local w = range.count * room_w
		gui.drawRectangle(draw_x, draw_y, w, row_h, 0xFFFFFFFF, 0)

		-- Draw a connecting bar to the next range
		-- We do this early so an "address overshoot" dot can still be drawn over it
		if i < #obj_spawner_data.room_ranges then
			gui.drawRectangle(draw_x + w + 1, draw_y, room_gap - 1, row_h, 0xFF666666, 0xFF222222)
		end

		-- Iterate through the range to draw boxes and the current block index
		local i_room = range.i_room_start
		for j = 0, range.count - 1, 1 do
			local x = draw_x + j * room_w
			gui.drawLine(x, draw_y, x, draw_y + row_h, 0xC0FFFFFF)

			-- If we are at the start of a block, draw a tick and mark the current address
			if i_room.room == 0 then
				if i_room.sublevel == 0 then
					local block_adr = obj_spawner_data.get_block(i_room).adr
					gui.drawString(x, draw_y - tick_label_offs, string.format("$%04X", block_adr))
					draw_tick(x, draw_y - 4, row_h + 12)
				else
					draw_tick(x, draw_y + row_h, 6)
				end
			end

			-- Highlight current block
			if i_room.block == obj_val.block then
				local fg = 0xFFFF00FF
				local bg = 0xFF800080
				-- And highlight the sublevel. Technically, we should try to find the range that is actually occupied by 
				-- the sublevel, however, this is too much effort, when so far, I've never actually seen the sublevel
				-- index get corrupted
				if i_room.sublevel == obj_val.sublevel then
					fg = 0xFFFF6060
					bg = 0xFFB080B0
				end
				gui.drawRectangle(x, draw_y, room_w, row_h, fg, bg)
			end

			i_room = block_info.next_room(i_room)
		end

		-- Check the current room index pointer is located in this range. Highlight one box,
		-- or draw a dot after the current range
		if range.start_adr <= obj_val.room_idx_adr then
			if obj_val.room_idx_adr < range.end_adr + 2 then
				local offs = (obj_val.room_idx_adr - range.start_adr) / 2
				local x = draw_x + offs * room_w
				gui.drawRectangle(x, draw_y, room_w, row_h, 0xFFFF00FF, 0xFFFF0000)
			else
				local next_range = obj_spawner_data.sublevel_ranges[i + 1]
				if next_range == nil or obj_val.room_idx_adr < next_range.start_adr then
					draw_circle(draw_x + w + oob_dot_offs_r, draw_y, row_h, 0xFFFF0000)
				end
			end
		end

		-- Draw an extra tick at the end of the range
		draw_tick(draw_x + w, draw_y + row_h, 6)

		draw_x = draw_x + w + room_gap
	end
end

function obj_spawner_pointers.show()
	-- First, get actual draw width for rooms
	local w = 0
	for i, range in ipairs(obj_spawner_data.room_ranges) do
		if i ~= 0 then
			w = w + room_gap
		end
		w = w + range.count * room_w
	end

	local draw_x_origin = client.screenwidth() / 2 - w / 2
	local draw_y_origin = client.screenheight() - row_0_y_offs

	-- Draw a translucent background in client space, since it's faster
	gui.drawRectangle(0, 187, 256, 224, 0xE0000000, 0xE0000000, "emucore")

	show_blocks(draw_x_origin, client.screenheight() - row_0_y_offs)
	show_sublevels(draw_x_origin + 384, client.screenheight() - row_0_y_offs)
	show_rooms(draw_x_origin, client.screenheight() - row_1_y_offs)
end

return obj_spawner_pointers
