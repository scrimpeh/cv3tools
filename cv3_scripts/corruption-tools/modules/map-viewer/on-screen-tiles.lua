# Shows tiles and staircases on screen

local coords = require("util/map-viewer/coords")
local tile_buffer = require("modules/map-viewer/tile-buffer")
local stair_data = require("modules/map-viewer/stairs")
local tile_val = require("modules/map-viewer/tile-values")

local on_screen_tiles = {}

local function draw_tile_screen(tile_type, sx, sy)
	if tile_type == 0 then
		return
	end
	local color = "white"
	if tile_type == 7 then
		color = "red"
	end

	gui.drawRectangle(sx, sy, 16, 16, color, nil, "emucore")
end

local function draw_tile(tile_type, tx, ty)
	if tile_type == 0 then
		return
	end
	local wx, wy = tile_buffer_xy_to_world(tx, ty)
	local sx, sy = world_xy_to_screen(wx, wy)
	return draw_tile_screen(tile_type, sx, sy)
end

function on_screen_tiles.show()
	if tile_val.horizontal then
		for wsx = 0, 256, 32 do
			for wsy = 32, 224, 16 do
				local offs = tile_buffer.get_byte_offs_h(wsx, wsy)
				local tile = memory.readbyte(tile_val.tile_buffer.start_adr + offs)
				local tile_l = tile >> 4
				local tile_r = tile & 0x0F

				local sx = wsx - (tile_val.camera & 0x1F)
				local sy = wsy - 8

				draw_tile_screen(tile_l, sx, sy)
				draw_tile_screen(tile_r, sx + 16, sy)
			end
		end
	else
		-- In vertical rooms, just draw the contents of the tile buffer directly
		-- There might also be weirdness there out of bounds, but I'm not deciphering that
		-- assembly code
		tile_buffer.show_all(draw_tile)
	end
end

local function get_world_tile(staircase, wx, wy)
	local tx, ty = world_xy_to_tile_buffer_xy(wx, wy + tile_val.stair_v_offs)
	if tx == nil or ty == nil then
		return nil
	end
	return tile_buffer.get_tile(tx, ty)
end

local function draw_staircase(staircase)
	local stair_overload = #tile_val.stair_data > 32
	local props = STAIR_PROPERTIES[staircase.flags]
	local x = staircase.x + props.x_offs
	local y = staircase.y + props.y_offs

	local start_x, start_y = world_xy_to_screen(x, y)
	if stair_overload then
		start_y = start_y + 8
	end
	if start_y > 32 then
		gui.drawPolygon(props.marker, start_x, start_y - 9, "lime", 0xC000FF00, "emucore")
	end

	-- Trace staircase until it hits an obstacle
	-- Unless there's way more stairs in the room than there should be
	-- In that case, peace out, and just draw the entraces
	if stair_overload then
		return
	end
	while true do
		if tile_val.horizontal and (y < 0 or y >= 240) then
			break
		elseif tile_val.vertical and (x < 0 or x >= 256) then
			break
		end

		local step_x, step_y = world_xy_to_screen(x, y)
		if step_y > 32 then
			gui.drawRectangle(step_x, step_y, 8, 8, "lime", 0x4040FF40, "emucore")
			gui.drawRectangle(step_x + props.dx * 8, step_y + props.dy * 8, 8, 8, "lime", 0x4040FF40, "emucore")
		end
		x = x + props.dx * 16
		y = y + props.dy * 16

		-- check if the tile terminates
		local y_check_offs = 0
		if staircase.up then
			y_check_offs = 8
		end
		local t_a = get_world_tile(staircase, x, y + y_check_offs)
		local t_b = get_world_tile(staircase, x - props.dx * 16, y + y_check_offs)
		if (t_a == nil or t_a ~= 0) or (t_b == nil or t_b ~= 0) then
			break
		end
	end
end

function on_screen_tiles.show_stairs()
	if not show_stair_data then
		return
	end

	for _, staircase in pairs(tile_val.stair_data) do
		draw_staircase(staircase)
	end

	-- Draw Stair Info
	local stair_draw_x = 2
	local stair_draw_y = 36
	local draw_pos = client.transformPoint(stair_draw_x, stair_draw_y)
	local open_bus_message = ""
	local stair_count = #tile_val.stair_data .. " staircases"
	if tile_val.stair_ptr > 0x2000 and tile_val.stair_ptr < 0x8000 then
		stair_count = "? staircases (Open bus)"
	end

	local message = string.format("Stair PTR: $%04X, %s", tile_val.stair_ptr, stair_count)
	gui.text(draw_pos.x, draw_pos.y, message)
end

return on_screen_tiles