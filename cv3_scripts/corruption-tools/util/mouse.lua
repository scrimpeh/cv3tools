-- Mouse handling

local mouse = {}

-- Coords is any object that provides x/y/w/h properties
function mouse.is_hovered(coords)
	return mouse.is_hovered_values(coords.x, coords.y, coords.w, coords.h)
end

function mouse.is_hovered_values(x, y, w, h)
	return mouse.x >= x and mouse.x < x + w and mouse.y >= y and mouse.y < y + h
end

function mouse.update()
	local cur_mouse = input.getmouse()

	-- Transform x/y into client coordinates
	local mouse_xy = client.transformPoint(cur_mouse.X, cur_mouse.Y)
	mouse.x = mouse_xy.x
	mouse.y = mouse_xy.y

	-- Handle button clicks
	mouse.left = cur_mouse.Left
	mouse.left_click = mouse.left and not mouse.prev_left
	mouse.prev_left = mouse.left
end

return mouse