-- Handles transforming between the different coordinate systems in the game
--
-- - World Coordinates (wx, wy)
--    - Pixel offset from the start of the room in the X and Y direction
--
--      Note: In vertical rooms, the tile_val.camera spans 240 pixels and skips pixels 
--      240 - 256 when scrolling. This needs to be taken into account when 
--      transforming coordinates.
-- - Screen coordinates (sx, sy)
-- - Tile Buffer Coordinates (tx, ty)
--    - The x and y position in the tile buffer starting at $6E0
--    - For horizontal rooms, the tile buffer is 24 * 12 tiles large, for vertical
--      rooms, 16 * 15 tiles. If the room is larger than the tile buffer,
--      the tile buffer only occupies a small slice of the room at a time
-- - Tile buffer offset
--    - The byte offset from the start of $6E0. Each byte covers two horizontally
--      adjacent tiles. In horizontal rooms, the buffer is accessed in vertical lines
--      going down, in vertical rooms in horizontal rows going right.

local tile_val = require("modules/map-viewer/tile-values")

local function y_cam_to_pixel(cam)
	return ((cam >> 8) * 240) + (cam & 0xFF)
end

function tile_buffer_xy_to_offs(tx, ty)
	if tile_val.vertical then
		return ty * 8 + (tx // 2)
	else
		return (tx // 2) * 12 + ty
	end
end

function tile_buffer_offs_to_xy(offs)
	if tile_val.vertical then
		return (offs % 8) * 2, offs // 8
	else
		return (offs // 12) * 2, offs % 12
	end
end

function tile_buffer_xy_to_world(tx, ty)
	if tile_val.vertical then
		local ty_cam = (tile_val.camera // 16) % 15
		local dty = ty - ty_cam
		if ty_cam > ty then
			dty = (15 - ty_cam) + ty
		end
		return tx * 16, (tile_val.camera & 0xFFF0) + dty * 16 + 42
	else
		local tx_cam = (tile_val.camera // 16) % 24
		local dtx = tx - tx_cam
		if tx_cam > tx then
			dtx = (24 - tx_cam) + tx
		end
		return (tile_val.camera & 0xFFF0) + dtx * 16, ty * 16 + 24
	end
end

function world_xy_to_tile_buffer_xy(wx, wy)
	if tile_val.vertical then
		if wy < tile_val.camera or wy >= tile_val.camera + 192 then
			return nil
		end
		return (wx // 16), (wy // 16) % 15
	else
		if wy < 24 or wy >= 216 then
			return nil
		end
		if wx < tile_val.camera or wx >= tile_val.camera + 256 then
			return nil
		end
		return (wx // 16) % 24, (wy - 24) // 16
	end
end

function world_xy_to_screen(wx, wy)
	if tile_val.vertical then
		return wx, wy - y_cam_to_pixel(tile_val.camera)
	else
		return wx - tile_val.camera, wy
	end
end