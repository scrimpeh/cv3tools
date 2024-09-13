-- Handles everything related to the tile buffer at 0x6E0 and shows it on the screen
-- at the side
--
-- Tile format:
--
-- Tiles start at 0x6E0 - 0x76F in RAM. A tile occupies 4 bits, with 2 tiles sharing a byte.
-- The tile types are as follows:
-- 
-- 0 - air                         8 - solid (?)
-- 1 - mud                         9 - solid
-- 2 - current right              10 - solid
-- 3 - current left               11 - solid
-- 4 - crumble (no falling block) 12 - crumble 0
-- 5 - spikes                     13 - crumble 1
-- 6 - solid                      14 - crumble 2
-- 7 - spikes                     15 - crumble 3
-- 
-- The upper nibble is the left tile, the lower nibble the right

require("util/draw")

local coords = require("util/map-viewer/coords")
local stair_data = require("modules/map-viewer/stairs")
local tile_val = require("modules/map-viewer/tile-values")

-- Definitions

local tile_buffer = {}

local new_tiles = {}
local new_tiles_max_ttl = 4

local draw_x = 0
local draw_y = 0

-- Scans the current offset on the screen for tile collision, simulating the game's assembly code
-- We cannot rely on the tile buffer when the camera is out of bounds due to the LUT accesses
-- seen below
--
-- I am once again indebted to vinheim...
-- https://github.com/vinheim3/castlevania3-disasm/blob/main/code/bank1f.s#L2710
function tile_buffer.get_byte_offs_h(sx, sy)
	if sy < 0x20 or sy >= 0xE0 then
		return 0
	end
	local ty = (sy - 0x20) // 16
	local wx = tile_val.camera + sx
	-- The game wants to determine the row in the meta tile buffer, and does so by
	-- by dividing the current screen position by 32 and ORing it with a times-8 table for room
	-- If the camera is out of bounds, this can return garbage
	local mtx = (wx & 0xFF) // 32
	local room_mtx = mtx | memory.readbyte(val(0xFD61, 0xFD62) + (wx >> 8))
	-- now the game finds the actual row in the meta tile buffer
	-- mod 12 to stay in bounds of the tile buffer...
	-- and times 12 to get the actual row offset. the game uses a lookup table for this again...
	-- this shouldn't go out of bounds though
	local mtx_buf = room_mtx % 12
	local mt_buf_offs_row = memory.readbyte(val(0xFD4C, 0xFD4D) + mtx_buf)
	-- finally, we can return the actual offs
	return mt_buf_offs_row + ty
end

function tile_buffer.get_tile(tx, ty)
	local t_offs = tile_buffer_xy_to_offs(tx, ty)
	local tiles = tile_val.tile_buffer.tiles[tile_val.tile_buffer.start_adr + t_offs]
	if tx % 2 == 0 then
		return tiles >> 4
	else
		return tiles & 0xF
	end
end

function tile_buffer.show_all(draw_fun)
	-- Sample tile grid at regular intertile_val.
	for t = tile_val.tile_buffer.start_adr, tile_val.tile_buffer.end_adr do
		local tile = tile_val.tile_buffer.tiles[t]

		local tile_l = tile >> 4
		local tile_r = tile & 0x0F

		local tx, ty = tile_buffer_offs_to_xy(t - tile_val.tile_buffer.start_adr)

		draw_fun(tile_l, tx, ty)
		draw_fun(tile_r, tx + 1, ty)
	end
end

local function draw_tile(tile_type, x, y, fg, bg)
	local x_pos = draw_x + tile_w * x
	local y_pos = draw_y + tile_h * y
	if tile_type ~= 0 then
		gui.drawRectangle(x_pos, y_pos, tile_w, tile_h, fg, bg)
	end
end

function tile_buffer.show()
	-- Set drawing coordinates
	local w = tile_w * tile_val.tile_buffer.w
	local h = tile_h * tile_val.tile_buffer.h
	draw_x, draw_y = draw_get_pos(tile_origin_x, tile_origin_y, w, h) 

	gui.drawRectangle(draw_x, draw_y, w, h, 0xFF666666)

	-- Highlight area covered by the camera
	local x_end = draw_x + w
	local y_end = draw_y + h
	if tile_val.vertical then
		local cam_start = (tile_val.camera % (tile_val.tile_buffer.h * 16)) / 16
		local cam_end = (cam_start + 12) % tile_val.tile_buffer.h
		if cam_start < cam_end then
			gui.drawBox(draw_x, draw_y + cam_start * tile_h, x_end, draw_y + cam_end * tile_h, 0xFF666666, 0x4000CCCC)
		else
			gui.drawBox(draw_x, draw_y + cam_start * tile_h, x_end, y_end, 0xFF666666, 0x4000CCCC)
			gui.drawBox(draw_x, draw_y, x_end, draw_y + cam_end * tile_h, 0xFF666666,  0x4000CCCC)
		end
	else
		local cam_start = (tile_val.camera % (tile_val.tile_buffer.w * 16)) / 16
		local cam_end = (cam_start + 16) % tile_val.tile_buffer.w
		if cam_start < cam_end then
			gui.drawBox(draw_x + cam_start * tile_w, draw_y, draw_x + cam_end * tile_w, y_end, 0xFF666666, 0x4000CCCC)
		else
			gui.drawBox(draw_x + cam_start * tile_w, draw_y, x_end, y_end, 0xFF666666, 0x4000CCCC)
			gui.drawBox(draw_x, draw_y, draw_x + cam_end * tile_w, y_end, 0xFF666666,  0x4000CCCC)
		end
	end

	-- Draw stair entrances
	if show_stair_data then
		for _, staircase in pairs(tile_val.stair_data) do
			local x = staircase.x + STAIR_PROPERTIES[staircase.flags].x_offs
			local y = staircase.y + STAIR_PROPERTIES[staircase.flags].y_offs
			local tx, ty = world_xy_to_tile_buffer_xy(x, y + tile_val.stair_v_offs)
			if tx ~= nil and ty ~= nil then
				if staircase.down or tile_val.vertical then
					ty = (ty - 1) % tile_val.tile_buffer.h
				end
				gui.drawRectangle(draw_x + tx * tile_w, draw_y + ty * tile_h, tile_w, tile_h, 0xFFFF0000, 0)
			end
		end
	end

	-- Draw tiles
	local function draw_fun(tile_type, x, y)
		draw_tile(tile_type, x, y, 0xFFCCCCCC)
	end
	tile_buffer.show_all(draw_fun)
end

function tile_buffer.get_replaced()
	local write_offset = memory.readbyte(0x10)
	local x, y = tile_buffer_offs_to_xy(write_offset)
	local tiles = {
		offset = write_offset,
		x = x,
		y = y,
		ttl = new_tiles_max_ttl
	}
	new_tiles[write_offset] = tiles
end

function tile_buffer.show_new_tiles()
	-- Display the new tiles we collected in the callback
	local i, tiles = next(new_tiles, nil)
	while i do
		local alpha = math.floor((tiles.ttl / new_tiles_max_ttl) * 0x80)
		local color = forms.createcolor(0xFF, 0x80, 0x80, alpha)
		draw_tile(1, tiles.x, tiles.y, 0, color)
		draw_tile(1, tiles.x + 1, tiles.y, 0, color)

		if client.ispaused() then
			tiles.ttl = tiles.ttl - 0.05
		else
			tiles.ttl = tiles.ttl - 1
		end

		if tiles.ttl < 0 then
			new_tiles[tiles.offset] = nil
		end
		i, tiles = next(new_tiles, i)     
	end
end

return tile_buffer

