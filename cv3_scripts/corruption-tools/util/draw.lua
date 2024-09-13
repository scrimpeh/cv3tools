-- Drawing utilities

function draw_tick(draw_x, draw_y, length)
	gui.drawLine(draw_x, draw_y, draw_x, draw_y + length, 0xFFFFFFFF)
end

function draw_circle(draw_x, draw_y, d, color)
	-- Draws a simple circle to use when visualizing that a pointer is outside the range of a pointer table
	gui.drawEllipse(draw_x, draw_y, d, d, color, color)
end

function draw_trim_string(str, max_length)
	if string.len(str <= max_length) then
		return str
	end
	return string.sub(str, 1, max_length - 3) .. "..."
end

-- Gets the x, y position to draw on the screen
-- Negative values indicate from the right / bottom edge
function draw_get_pos(x, y, w, h)
	if x < 0 then
		x = client.screenwidth() + x - (w or 0)
	end
	if y < 0 then
		y = client.screenheight() + y - (h or 0)
	end
	return x, y
end

-- Font size parameters for gui.text(...)
DRAW_FONTSIZE_TEXT = {
	w = 10,
	h = 16
}

-- Font size parameters for gui.drawString(...)
DRAW_FONTSIZE_DRAWSTRING = {
	w = 7,
	h = 13
}

-- Font size parameters for gui.pixelText(..., "fceux")
DRAW_FONTSIZE_FCEUX = {
	w = 6,
	h = 9
}

-- Fontsize has the following format
-- w:       width of the font glyph in pixels
-- h:       height of the font glyph in pixels
function draw_estimate_text_size(text, fontsize)
	local lines = 0
	local longest_line = 0
	for line in text:gmatch("[^\r\n]+") do
		lines = lines + 1
		longest_line = math.max(longest_line, #line)
	end
	if fontsize == nil then
		return { 
			w = longest_line, 
			h = lines 
		}
	end
	return {
		w = longest_line * fontsize.w,
		h = lines * fontsize.h
	}
end

-- Formats a table as hex bytes
function draw_format_hex(bytes)
	local formatted = {}
	for k, v in pairs(bytes) do
		formatted[k] = string.format("%02X", v)
	end
	return formatted
end