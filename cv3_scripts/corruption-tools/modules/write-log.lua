-- This module is responsible for logging writes to the OBJ tables in RAM - or OOB writes 
-- that corrupt something else

local osd = require("util/osd")
local mouse = require("util/mouse")

local write_log = {}

-- Configuration

local message_ttl = 160
local cur_message_ttl = message_ttl

local max_messages = 12

local x_offs = 280
local w = 248
local y = 328
local h = 244

local message_w = 252
local message_gap = 8

-- Initialization

local messages = {}

-- Internal functions

local function clear_log()
	messages = {}
end

-- Register events
local loadstate_event_name = "cv3_corruption_visualizer_write_log"
event_unregister(loadstate_event_name)
event.onloadstate(clear_log, loadstate_event_name)

-- Functions

function write_log.add(summary, detail, important)
	local message = {
		summary = summary,
		detail = detail,
		important = important,
		ttl = cur_message_ttl
	}
	-- If multiple messages get added in the same frame, make them disappear slightly staggered
	-- from each other
	cur_message_ttl = cur_message_ttl + 2
	table.insert(messages, 1, message)
	if #messages > max_messages then
		table.remove(messages)
	end
end

function write_log.show()
	local origin_x = 256
	local origin_y = 40
	local client_origin = client.transformPoint(origin_x, origin_y)

	local draw_x = client_origin.x - message_gap - message_w
	local draw_y = client_origin.y + message_gap

	local to_remove = {}

	for i, message in ipairs(messages) do
		local message_h = draw_estimate_text_size(message.summary, DRAW_FONTSIZE_DRAWSTRING).h + 10

		-- Wrap over to the next row if necessary. Note that we do this with an offset
		-- in case the view interferes with the extended object information
		local max_h = client.screenheight()
		if show_extended_info_checkbox.value then
			max_h = max_h - 150
		end
		if draw_y + message_h > max_h then
			draw_x = draw_x - message_w - message_gap
			draw_y = client_origin.y + message_gap
		end

		local bg = 0xC0000000
		if message.important then
			bg = 0xC0600000
		end
		if mouse.is_hovered_values(draw_x, draw_y, message_w, message_h) then
			osd.highlight_coords(draw_x, draw_y, message_w, message_h, message.detail)
			bg = bg | 0x333333
		end

		gui.drawRectangle(draw_x, draw_y, message_w, message_h, 0, bg)
		gui.drawString(draw_x + 3, draw_y + 4, message.summary)

		-- The script still updates while we're paused, so only decrement the ttl if the emu is running
		-- This technically means the TTL will not tick down during frame advance, but that is acceptable
		if not client.ispaused() then
			message.ttl = message.ttl - 1
		end
		if message.ttl <= 0 then
			table.insert(to_remove, i)
		end
		draw_y = draw_y + message_h + message_gap
	end

	for _, message in pairs(to_remove) do
		table.remove(messages, i)
	end

	-- Reset message TTL for this frame
	-- Do it gradually, so that later messages cannot overtake earlier ones
	cur_message_ttl = cur_message_ttl + 1
	if cur_message_ttl > message_ttl then
		cur_message_ttl = cur_message_ttl - 1
	end
end

return write_log