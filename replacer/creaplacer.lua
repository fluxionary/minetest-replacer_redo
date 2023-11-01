local S = replacer.S
local api = replacer.api

minetest.register_tool("replacer:creaplacer", {
	description = S("creaplacer"),
	short_description = S("creaplacer"),
	inventory_image = "replacer_replacer.png^[multiply:red",
	liquids_pointable = true,
	range = 10,
	groups = { not_in_creative_inventory = 1 },

	on_use = function(toolstack, player, pointed_thing)
		-- left click (punch)
		if not (futil.is_player(player) and minetest.is_creative_enabled(player:get_player_name())) then
			return
		end

		return api.creative_replace(toolstack, player, pointed_thing)
	end,

	on_place = function(toolstack, player, pointed_thing)
		-- rightclick
		if not (futil.is_player(player) and minetest.is_creative_enabled(player:get_player_name())) then
			return
		end

		local keys = player:get_player_control()
		if keys.sneak then
			return api.creative_copy(toolstack, player, pointed_thing)
		else
			return api.creative_place(toolstack, player, pointed_thing)
		end
	end,
})
