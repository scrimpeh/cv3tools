-- Lua Table Util

function table_key_set(arg)
	local result = {}
	for _, v in pairs(arg) do
		result[v] = true
	end
	return result
end