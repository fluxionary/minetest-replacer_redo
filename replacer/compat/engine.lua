local api = replacer.api

api.blacklist_item("")
api.blacklist_item("air")
api.blacklist_item("ignore")

api.blacklist_predicate(function(itemstring, def)
	return (def.groups.unbreakable or 0) > 0
end)
