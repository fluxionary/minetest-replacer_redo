local f = string.format

local S = inspector.S

local get_safe_short_description = futil.get_safe_short_description

minetest.register_tool("inspector:inspector", {
	description = S("Inspector"),
	short_description = S("Inspector"),
	inventory_image = "inspector_inspector.png",
	liquids_pointable = true,

	on_use = function(_, player, pointed_thing)
		-- left click
		if not minetest.is_player(player) then
			return
		end

		if pointed_thing.type == "nothing" then
			inspector.chat_send_player(player, S("nothing"))
		elseif pointed_thing.type == "node" then
			local pos = pointed_thing.under
			local node = minetest.get_node(pos)
			local stack = ItemStack(node)
			local desc
			if stack:is_known() then
				desc = get_safe_short_description(node.name)
			else
				desc = f("%s (%s)", get_safe_short_description(node.name), node.name)
			end

			inspector.chat_send_player(
				player,
				S("node @@@1: @2 param1=@3 param2=@4", minetest.pos_to_string(pos), desc, node.param1, node.param2)
			)
		elseif pointed_thing.type == "object" then
			local obj = pointed_thing.ref

			if minetest.is_player(obj) then
				inspector.chat_send_player(player, S("player: @1", obj:get_player_name()))
			else
				local lua_entity = obj:get_luaentity()
				if lua_entity then
					inspector.chat_send_player(player, S("luaentity: @1", lua_entity.name or "unknown???"))
				else
					inspector.chat_send_player(
						player,
						S("impossible. an object which is neither a player nor a lua entity?")
					)
				end
			end
		end
	end,
})

minetest.register_alias("replacer:inspector", "inspector:inspector")
