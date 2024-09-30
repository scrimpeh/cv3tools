-- The OBJ Index Range shows where obj_idx_ptr ($98) points to. Ordinarily, the value of the pointer is
-- determined by the current room index, but going to an invalid room or corrupting the value using memory
-- corruption can set the pointer to any value. We therefore show the entire 6502 address range.
-- The range is compressed and specifically highlights the important areas, i.e. the usual PRG ROM space
-- where the pointer is intended to point, and zero page, since that is also very common

local obj_idx_data = require("static/obj-idx-data")
local obj_val = require("modules/object-data-values")

local obj_idx_range = {}

-- Configuration

local y_offs = 60
local h = 10

-- Functions

local function show_region(draw_x, draw_y, w, start_adr, end_adr, fg, bg)
	-- Draw the actual box for the memory
	local size = end_adr - start_adr
	gui.drawRectangle(draw_x, draw_y, w, h, fg, bg)
	gui.drawLine(draw_x, draw_y, draw_x, draw_y + h, 0xFFFFFFFF)
	draw_tick(draw_x, draw_y, -4)
	gui.drawText(draw_x + 2, draw_y - 16, string.format("$%04X", start_adr))

	-- If obj_idx_pointer falls into this range, draw a handle to show it
	if obj_val.obj_idx_pointer >= start_adr and obj_val.obj_idx_pointer < start_adr + size then
		local tick_draw_x = draw_x + (obj_val.obj_idx_pointer - start_adr) * (w / size)
		gui.drawLine(tick_draw_x, draw_y, tick_draw_x, draw_y + h, 0xFFFF0000)
		gui.drawRectangle(tick_draw_x - 4, draw_y + h + 1, 8, 8, 0xFFFF0000, 0xFFFF0000)
	end
	-- Since obj_idx_pointer is also indexed by the camera position, draw a second handle
	local ptr_read_64 = obj_val.obj_idx_pointer + obj_val.room_read_64_offs
	if ptr_read_64 >= start_adr and ptr_read_64 < start_adr + size then
		local tick_draw_x = draw_x + (ptr_read_64 - start_adr) * (w / size)
		gui.drawLine(tick_draw_x, draw_y + 1, tick_draw_x, draw_y + h, 0xFFFF60FF)
		gui.drawRectangle(tick_draw_x - 4, draw_y + h, 8, 8, 0xFFFF60FF, 0xFFFF60FF)
	end
	return draw_x + w
end

function obj_idx_range.show()
	-- Visualize what part of the NES address space obj_val.obj_idx_pointer actually points to
	local draw_y = client.screenheight() - y_offs

	-- Define how much space every region should take on
	local zp_w = 128                -- $0000
	local stack_w = zp_w            -- $0100
	local ram_w = zp_w              -- $0200
	local lower_bus_w = zp_w        -- $0800
	local rom_start_w = zp_w / 2    -- $8000
	local group_scale_factor = 0.15 -- .....
	local group_gap_w = zp_w / 2    -- .....
	local rom_end_w = rom_start_w   -- ..... - $FFFF

	-- Find out how many groups there actually are to calculate the total width
	local total_w = zp_w + stack_w + ram_w + lower_bus_w + rom_start_w + rom_end_w

	local min_group = 0xFFFF
	local max_group = 0x0000

	local group_ws = {}
	for _, group in pairs(obj_idx_data.ranges) do
		min_group = math.min(min_group, group.min_value)
		max_group = math.max(max_group, group.max_value)

		local size = group.max_value - group.min_value
		total_w = total_w + size * group_scale_factor + group_gap_w
		table.insert(group_ws, size * group_scale_factor)
	end
	total_w = total_w - group_gap_w

	local draw_x = client.screenwidth() / 2 - total_w / 2

	local message = string.format("Index for $%04X", OBJ_PTR_TABLE_ADR)
	gui.text(draw_x - 224, draw_y + 6, message)

	-- Now actually draw the bars
	draw_x = show_region(draw_x, draw_y, zp_w,           0x0000,    0x0100, 0xFFFFFFFF, 0x00000000)
	draw_x = show_region(draw_x, draw_y, stack_w,        0x0100,    0x0200, 0xFF666666, 0xFF222222)
	draw_x = show_region(draw_x, draw_y, ram_w,          0x0200,    0x0800, 0xFF666666, 0xFF222222)
	draw_x = show_region(draw_x, draw_y, lower_bus_w,    0x0800,    0x8000, 0xFF666666, 0xFF222222)
	draw_x = show_region(draw_x, draw_y, rom_start_w,    0x8000, min_group, 0xFF666666, 0xFF222222)
	for i = 1, #obj_idx_data.ranges, 1 do
		local group = obj_idx_data.ranges[i]
		if i ~= 1 then
			-- Draw Gap
			local prev_group = obj_idx_data.ranges[i - 1]
			draw_x = show_region(draw_x, draw_y, group_gap_w, prev_group.max_value, group.min_value, 0xFF666666, 0xFF222222)
		end
		draw_x = show_region(draw_x, draw_y, group_ws[i], group.min_value, group.max_value, 0xFFFFFFFF, 0x00000000)
	end
	draw_x = show_region(draw_x, draw_y, rom_start_w, max_group,    0xFFFF, 0xFF666666, 0xFF222222)
end

return obj_idx_range