-- Utilities relating to events

function event_unregister(event_name)
	while event.unregisterbyname(event_name) do
	end
end