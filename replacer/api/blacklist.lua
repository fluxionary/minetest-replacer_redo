local api = replacer.api

api.item_blacklist = {}
api.predicate_blacklist = {}
api.replace_item_blacklist = {}
api.replace_predicate_blacklist = {}

function api.blacklist_item(itemstring)
	api.item_blacklist[itemstring] = true
end

function api.blacklist_predicate(pred)
	table.insert(api.predicate_blacklist, pred)
end

function api.is_blacklisted(itemstring)
	if api.item_blacklist[itemstring] then
		return true
	end

	local def = minetest.registered_nodes[itemstring]

	if not def then
		return true
	end

	for _, pred in ipairs(api.predicate_blacklist) do
		if pred(itemstring, def) then
			return true
		end
	end

	return false
end

function api.blacklist_item_replacement(itemstring)
	api.replace_item_blacklist[itemstring] = true
end

function api.blacklist_predicate_replacement(pred)
	table.insert(api.replace_predicate_blacklist, pred)
end

-- place allowed, replace not allowed
function api.is_replacement_blacklisted(itemstring)
	if api.item_replace_blacklist[itemstring] then
		return true
	end

	local def = minetest.registered_nodes[itemstring]

	if not def then
		return true
	end

	for _, pred in ipairs(api.replace_predicate_blacklist) do
		if pred(itemstring, def) then
			return true
		end
	end

	return api.is_blacklisted(itemstring)
end
