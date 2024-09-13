-- Basic OSD widgets

local mouse = require("util/mouse")

local osd = {}

local components = {}
local cur_tooltip = nil

-- Params is a table that contains the following keys:
-- x, y, w, h
-- on_click is executed any time a button changes
function osd.button(params, on_click)
	local button_params = {
		class = "Button",
		on_click = on_click
	}
	for k, v in pairs(params) do
		button_params[k] = v
	end
	table.insert(components, button_params)
end

-- checkbox_params: x, y, w, h, label
-- on_click takes a callback with the current value of the checkbox as param
function osd.checkbox(params, on_click)
	local checkbox_params = {
		class = "Checkbox",
		on_click = on_click
	}
	for k, v in pairs(params) do
		checkbox_params[k] = v
	end
	table.insert(components, checkbox_params)
	return checkbox_params
end

-- Highlights an area in the client area and displays a tooltip
function osd.highlight_coords(x, y, w, h, tooltip)
	local bounds = {
		x = x,
		y = y,
		w = w,
		h = h
	}
	osd.highlight(bounds, tooltip)
end

function osd.highlight(bounds, tooltip)
	cur_tooltip = {
		bounds = bounds,
		tooltip = tooltip
	}
end

local function update_button(button) 
	local fg = 0xFF555555
	local bg = 0xFF008080
	if mouse.is_hovered(button) then
		fg = 0xFFFFFFFF
		bg = 0xFFC00000
		if mouse.left then
			bg = 0xFF200000
		end
		if mouse.left_click then
			button.on_click()
		end
	end
	gui.drawRectangle(button.x, button.y, button.w, button.h, fg, bg)
	local text_size = draw_estimate_text_size(button.label, DRAW_FONTSIZE_TEXT)
	gui.text(
		button.x + button.w / 2 - text_size.w / 2 + 2,
		button.y + button.h / 2 - text_size.h / 2 + 9,
		button.label
	)
end

local function update_checkbox(checkbox) 
	local fg = 0xFF555555
	if mouse.is_hovered(checkbox) then
		fg = 0xFFFFFFFF
	end
	local bg = 0x40008080
	if checkbox.value then
		bg = 0xFF008080
	end
	gui.drawRectangle(checkbox.x, checkbox.y, checkbox.w, checkbox.h, fg, bg)
	local label_size = draw_estimate_text_size(checkbox.label, DRAW_FONTSIZE_TEXT)
	local label_x = checkbox.x + checkbox.w + 16
	if label_x + label_size.w >= client.screenwidth() then
		label_x = checkbox.x - 16 - label_size.w
	end
	local label_y = checkbox.y + checkbox.h / 2 - label_size.h / 2 + 8
	gui.text(label_x, label_y, checkbox.label)
	if mouse.is_hovered(checkbox) and mouse.left_click then
		checkbox.value = not checkbox.value
		if checkbox.on_click then
			checkbox.on_click(checkbox.value)
		end
	end
end

local function show_tooltip()
	if cur_tooltip == nil then
		return
	end

	local bounds = cur_tooltip.bounds
	local tooltip = cur_tooltip.tooltip
	local tooltip_size = draw_estimate_text_size(tooltip, DRAW_FONTSIZE_TEXT)
	tooltip_size.w = tooltip_size.w + 8
	tooltip_size.h = tooltip_size.h + 4

	local origin_x = bounds.x + bounds.w + 4
	if origin_x + tooltip_size.w > client.screenwidth() then
		origin_x = bounds.x - 4 - tooltip_size.w
	end
	local origin_y = bounds.y + bounds.h + 4
	if origin_y + tooltip_size.h > client.screenheight() then
		origin_y = bounds.y - 4 - tooltip_size.h
	end

	gui.drawRectangle(origin_x, origin_y, tooltip_size.w, tooltip_size.h, 0xFFFF0000, 0xD0600000)
	gui.text(origin_x + 4, origin_y + 10, tooltip)
	cur_tooltip = nil
end

function osd.update()
	-- Draw all components
	for _, component in pairs(components) do
		if component.class == "Button" then
			update_button(component)
		elseif component.class == "Checkbox" then
			update_checkbox(component)
		end
	end

	show_tooltip()
end

return osd