-- CV3 Map Viewer, For BizHawk --

-- Configuration --

display_tiles = true

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

function drawTile(tile_type, x, y)
	local x_pos = tile_origin_x + tile_w * x
	local y_pos = tile_origin_y + tile_h * y
	
	if tile_type ~= 0 then
		gui.drawRectangle(x_pos, y_pos, tile_w, tile_h, 0xCCCCCCCC)
	end
end

function getVal(us, jp)
	if game_type == "jp" then
		return jp
	else
		return us
	end
end

function displayTiles()
	-- Test if we're ingame
	local gamestate = memory.readbyte(getVal(0x18, 0x18))
	if gamestate ~= 4 then
		gui.clearGraphics()
		return
	end
	
	local vertical = false	-- todo, figure out how to discern room modes
	
	local tiles_start = 0x6E0
	local tiles_end = 0x770 - 1
	
	local row = 0			-- rows, going down
	local column = 0 		-- columns, going side way
	
	-- Draw box around tiles
	gui.drawRectangle(tile_origin_x, tile_origin_y, tile_w * 24, tile_h * 12, 0x66666666)
	
	for t = tiles_start, tiles_end do
		local tile = memory.readbyte(t)
		
		local tile_l = bit.rshift(tile, 4)
		local tile_r = bit.band(tile, 0x0F)
		
		drawTile(tile_l, column * 2, row)
		drawTile(tile_r, column * 2 + 1, row)
		
		if vertical then
			column = column + 1
			if column == 8 then
				column = 0
				row = row + 1
			end
		else	
			row = row + 1
			if row == 12 then
				row = 0
				column = column + 1
			end
		end
	end
end

-- Start Execution --

console.clear()
print("Starting CV3 Map viewer...")

getGameType()

-- We're drawing in client space
gui.use_surface("client")

while true do
	if display_tiles then
		displayTiles()
	end
	emu.frameadvance()
end