-- The RAM Map shows what is actually written into the game's RAM when memory corruption occurs
-- It highlights previously overwritten values
-- The plan is also that it will eventually display "interesting" values

local osd = require("util/osd")
local mouse = require("util/mouse")

local ram_map_data = require("static/ram-map-data")
local memory_writes = require("modules/memory-writes")

local ram_map = {}

-- Configurations

local x_offs = 14
local y_offs = 42
local col_w = 16
local row_h = 12
local cols = 16
local col_separator = cols / 4
local gap_h = 24

-- Definitions

-- Special ranges that should be highlighted in the RAM map
-- The user can potentially add their own later

-- Automatically set the first time while drawing
-- To adjust what gets highlighted, edit ~/static/ram_map_data.lua
local HIGHLIGHT_RANGES = {}

local VIEW_RANGES = {
	{ start_adr = 0x0000, size = 0x0100 }, -- Zero Page
	{ start_adr = 0x07C0, size = 0x0040 }  -- Highest 64 bytes - contain enemy tables
}

-- Internal Functions

local function get_highlight_values(start, size)
	if HIGHLIGHT_RANGES[start] == nil then
		local range = {}
		for _, val in pairs(ram_map_data.values) do
			if range[val.adr] == nil and val.adr >= start and val.adr <= start + size then
				local should_highlight = val.value_type.bg ~= 0 or val.value_type.fg ~= 0
				if should_highlight then
					range[val.adr] = val
				end
			end
		end
		HIGHLIGHT_RANGES[start] = range
	end
	return HIGHLIGHT_RANGES[start]
end

local function get_pos(origin_adr, origin_x, origin_y, adr)
	local offs_adr = adr - origin_adr
	return {
		x = origin_x + (offs_adr % cols) * col_w,
		y = origin_y + (offs_adr // cols) * row_h
	}
end

-- Returns the coordinates of the top left of the next memory cell to draw
local function get_bounds(origin_adr, origin_x, origin_y, adr, size)
	-- First of all, divide the memory range into subranges for each row
	local subranges = {}
	local row_adr = (adr // cols) * cols
	for i = row_adr, adr + size - 1, cols do
		local subrange = {
			start_adr = math.max(adr, i),
			end_adr = math.min(adr + size, i + cols)
		}
		table.insert(subranges, subrange)
	end
	local origin_row_adr = (origin_adr // cols) * cols
	local bounds = {}
	for _, subrange in pairs(subranges) do
		local pos = get_pos(origin_row_adr, origin_x, origin_y, subrange.start_adr)
		local cur_bounds = { 
			x = pos.x,
			y = pos.y,
			w = (subrange.end_adr - subrange.start_adr) * col_w,
			h = row_h 
		}
		table.insert(bounds, cur_bounds)
	end
	return bounds
end

-- This function is responsbile for highlighting RAM writes
-- Recent corruptions are highlighted in red
-- Previously corrupted tiles are highlighted in purple
local function show_writes(draw_x, draw_y, start, size)
	local highlighted_writes = {}
	for _, ram_write in pairs(memory_writes.recent) do
		local alpha = math.floor((ram_write.ttl / memory_writes.write_ttl) * 0x80)
		local color = forms.createcolor(0x00, 0xFF, 0xC0, alpha)
		if ram_write.mod_6_offs >= 6 then
			color = forms.createcolor(0xFF, 0x00, 0x00, alpha * 2 - 1)
		end
		for _, cur_write in pairs(ram_write.writes) do
			if cur_write.write_adr >= start and cur_write.write_adr < start + size then
				highlighted_writes[cur_write.write_adr] = true
				local pos = get_pos(start, draw_x, draw_y, cur_write.write_adr)
				gui.drawRectangle(pos.x, pos.y, col_w, row_h, 0, color)
			end
		end
	end

	-- Show values that have ever been corrupted previously
	for adr, value in pairs(memory_writes.corrupted) do
		if adr >= start and adr < start + size and not highlighted_writes[adr] then
			local pos = get_pos(start, draw_x, draw_y, adr)
			gui.drawRectangle(pos.x, pos.y, col_w, row_h, 0, 0x80FF00FF)
		end
	end
end

local function get_corruption_count(adr)
	local corrupted_write = memory_writes.corrupted[adr]
	if corrupted_write ~= nil then
		return corrupted_write.count
	end
	return 0
end

local function show_mouseover_value(start, size, draw_x, draw_y)
	-- Find the exact RAM address that is highlighted
	local col_x = (mouse.x - draw_x) // col_w
	local col_y = (mouse.y - draw_y) // row_h
	local adr = start + (col_y * cols) + col_x
	local game_value = ram_map_data.get_value(adr)
	local value = ram_map_data.read_value(adr)
	local bounds = get_bounds(start, draw_x, draw_y, game_value.adr, game_value.size)

	local value_str = string.format("%02X", value)
	local corruption_count = get_corruption_count(adr)
	local corruption_str = ""

	-- Two-byte values need special handling, since we group both writes into one
	if game_value.size == 2 then
		value_str = string.format("%04X", value)
		corruption_count = get_corruption_count(game_value.adr) + get_corruption_count(game_value.adr + 1)
	end

	if corruption_count ~= 0 then
		local cur_corruption = nil
		local last_corrupted_str = ""
		if game_value.size == 2 then
			cur_corruption = memory_writes.corrupted[game_value.adr] or memory_writes.corrupted[game_value.adr + 1]
			last_corrupted_str = string.format("%04X", cur_corruption.full_value) 
		else
			cur_corruption = memory_writes.corrupted[adr]
			last_corrupted_str = string.format("%02X", cur_corruption.full_value) 
		end
		corruption_str = string.format(" / last : %s\ncorrupted %d times", last_corrupted_str, corruption_count)
	end

	local message = string.format("$%02X: %s\n%s%s", game_value.adr, game_value.desc, value_str, corruption_str)

	for _, cur_bounds in pairs(bounds) do
		gui.drawRectangle(cur_bounds.x, cur_bounds.y, cur_bounds.w, cur_bounds.h, 0xFFFF0000, 0x30FFFFFF)
	end

	-- In tables, highlight the individual value
	if game_value.size > 2 then
		local value_bounds = get_bounds(start, draw_x, draw_y, adr, 1)[1]
		gui.drawRectangle(value_bounds.x, value_bounds.y, value_bounds.w, value_bounds.h, 0xFFFF00FF, 0x30FFFFFF)
		osd.highlight(value_bounds, message)
	else
		osd.highlight(bounds[1], message)
	end
end

local function show_region(start, size, draw_x, draw_y)
	local rows = math.ceil(size / cols)
	local w = col_w * cols
	local h = row_h * rows
	gui.drawRectangle(draw_x, draw_y, w, h, 0xFFFFFFFF, 0)

	-- Draw vertical bars
	for j = col_separator, cols - 1, col_separator do
		local x = get_pos(start, draw_x, draw_y, start + j).x
		gui.drawLine(x, draw_y + 1, x, draw_y + h - 1, 0xFF666666)
	end

	-- Draw horizontal bars
	for i = 0, rows - 1, 1 do
		local row_adr = start + i * cols
		local y = get_pos(start, draw_x, draw_y, row_adr).y
		gui.drawString(draw_x - 36, y - 1, string.format("$%02X", row_adr))
		if i > 0 then
			gui.drawLine(draw_x, y, draw_x + w, y, 0xFFFFFFFF)
		end
	end

	-- Highlight special memory values
	for _, value in pairs(get_highlight_values(start, size)) do
		local bounds = get_bounds(start, draw_x, draw_y, value.adr, value.size)
		for _, cur_bounds in pairs(bounds) do
			gui.drawRectangle(cur_bounds.x, cur_bounds.y, cur_bounds.w, cur_bounds.h, value.value_type.fg, value.value_type.bg)
		end
	end

	-- Show all RAM writes into this region
	show_writes(draw_x, draw_y, start, size)

	-- Finally, if the mouse is pointing into this region, highlight the current address
	if mouse.is_hovered_values(draw_x, draw_y, w, h) then
		show_mouseover_value(start, size, draw_x, draw_y)
	end

	return draw_y + h
end

-- Register OSD widgets

local clear_button_params = {
	x = client.screenwidth() - 88,
	y = y_offs - 30,
	w = 64,
	h = 22,
	label = "Clear"
}
local clear_button = osd.button(clear_button_params, memory_writes.clear_corrupted_writes)

-- Functions

-- Shows memory in the zero page and everything from 0x7C0 onwards
function ram_map.show()
	local draw_x = client.screenwidth() - (cols * col_w) - x_offs
	local draw_y = y_offs

	gui.drawString(draw_x + 12, 20, "6502 RAM MAP")

	for i, range in ipairs(VIEW_RANGES) do
		draw_y = show_region(range.start_adr, range.size, draw_x, draw_y)
		if i ~= #VIEW_RANGES then
			local x = draw_x + ((col_w * cols) / 2) - 12
			local y = draw_y + gap_h / 2 - 10
			gui.drawString(x, y, "...")
			draw_y = draw_y + gap_h
		end
	end

	memory_writes.decrement_write_ttl()
end

return ram_map