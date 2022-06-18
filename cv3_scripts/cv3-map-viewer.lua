-- CV3 Map Viewer, For BizHawk --

-- Todos:
-- - Correlate camera information with meta tile buffer, show screen
-- - Show stairs 
-- - Show sprites
-- - permanently show where the game wants to put metatiles next

-- Configuration --

display_tiles = true
show_replaced_tiles = true

tile_w = 12
tile_h = 12
tile_origin_x = 1384
tile_origin_y = 192

-------------------

--[[ 
	Tiles start at 0x6E0 - 0x76F in RAM. A tile occupies 4 bits, with 2 tiles sharing a byte.
	The tile types are as follows:
	
	0 - air                         8 - solid (?)
	1 - mud                         9 - solid
	2 - current right              10 - solid
	3 - current left               11 - solid
	4 - crumble (no falling block) 12 - crumble 0
	5 - spikes                     13 - crumble 1
	6 - solid                      14 - crumble 2
	7 - spikes                     15 - crumble 3
	
	The upper nibble is the left tile, the lower nibble the right
--]]

game_type = nil
replaced_tiles_cb_registered = false
vertical = false
new_tiles = {}
new_tiles_max_ttl = 4

function getGameType()
	local board = gameinfo.getboardtype()
	if board == "ExROM" then
		game_type = "us"
	elseif board == "VRC6" then
		game_type = "jp"
	else
		error("Cannot determine game type" .. board)
	end
	print("Game type is " .. game_type .. ".")
end

function drawTile(tile_type, x, y, color, backColor)
	local x_pos = tile_origin_x + tile_w * x
	local y_pos = tile_origin_y + tile_h * y
	
	if tile_type ~= 0 then
		gui.drawRectangle(x_pos, y_pos, tile_w, tile_h, color, backColor)
	end
end

function getVal(us, jp)
	if game_type == "jp" then
		return jp
	else
		return us
	end
end

function getRow(offs, vertical_mode) 
	if vertical_mode then
		return math.floor(offs / 8)
	else
		return math.mod(offs, 12)
	end
end

function getColumn(offs, vertical_mode) 
	if vertical_mode then
		return math.mod(offs, 8)
	else
		return math.floor(offs / 12)
	end
end

function isVerticalMode() 
	-- Figure out the scrolling mode by 0xFC, which contains the vertical scroll offset for the status bar
	-- In horizontal rooms, it is 0, in vertical rooms it is 4
	-- This is not very pretty, but until I can figure out something better, this will do the trick
	return memory.readbyte(0xFC) == 4
end

function displayTiles()
	-- Test if we're ingame
	local gamestate = memory.readbyte(0x18)
	if gamestate ~= 4 then
		-- Clear the map then
		gui.drawRectangle(tile_origin_x, tile_origin_y, tile_w * 24, tile_h * 16, 0, 0xFF000000)
		return
	end

	local tiles_start = 0x6E0
	local metatile_buffer_width
	local metatile_buffer_height
	local tiles_end
	if vertical then
		metatile_buffer_width = 16
		metatile_buffer_height = 16
		tiles_end = 0x760 - 1
	else
		metatile_buffer_width = 24
		metatile_buffer_height = 12
		tiles_end = 0x770 - 1
	end
	
	-- Draw box around tiles
	gui.drawRectangle(tile_origin_x, tile_origin_y, tile_w * metatile_buffer_width, tile_h * metatile_buffer_height, 0xFF666666, 0xFF000000)
	
	for t = tiles_start, tiles_end do
		local tile = memory.readbyte(t)
		
		local tile_l = bit.rshift(tile, 4)
		local tile_r = bit.band(tile, 0x0F)
		
		local column = getColumn(t - 0x6E0, vertical)
		local row = getRow(t - 0x6E0, vertical)
		
		drawTile(tile_l, column * 2, row, 0xFFCCCCCC)
		drawTile(tile_r, column * 2 + 1, row, 0xFFCCCCCC)
	end
end

function getReplacedTiles()
	local writeOffset = memory.readbyte(0x10)
	local tiles = {
		offset = writeOffset,
		column = getColumn(writeOffset, vertical),
		row = getRow(writeOffset, vertical),
		ttl = new_tiles_max_ttl
	}
	new_tiles[writeOffset] = tiles
end


function showReplacedTiles()
	if not show_replaced_tiles then
		return
	end
	-- Display the new tiles we collected in the callback
	local i, tiles = next(new_tiles, nil)
	while i do
		local alpha = math.floor((tiles.ttl / new_tiles_max_ttl) * 0x80)
		local color = forms.createcolor(0xFF, 0x80, 0x80, alpha)
		drawTile(1, tiles.column * 2, tiles.row, 0, color)
		drawTile(1, tiles.column * 2 + 1, tiles.row, 0, color)	
		tiles.ttl = tiles.ttl - 1
		if tiles.ttl == 0 then
			new_tiles[tiles.offset] = nil
		end
		i, tiles = next(new_tiles, i)     
	end
end


-- Start Execution --

console.clear()
gui.clearGraphics()

print("Starting CV3 Map viewer...")

getGameType()
gui.use_surface("client")


-- Main script loop, execute every frame --
while true do
	vertical = isVerticalMode()
	
	if display_tiles then
		displayTiles()
	end
	
	-- Todo - using a callback for is way too slow - i need to somehow detect this happening in RAM
	if show_replaced_tiles then
		if not replaced_tiles_cb_registered then
			event.onmemoryexecute(getReplacedTiles, getVal(0xD29E, 0xD273), "cv3_map_viewer_showReplacedTiles")
			replaced_tiles_cb_registered = true
		end
		showReplacedTiles()
	else
		event.unregisterbyname("cv3_map_viewer_showReplacedTiles")
		replaced_tiles_cb_registered = false
	end
	
	emu.frameadvance()
end