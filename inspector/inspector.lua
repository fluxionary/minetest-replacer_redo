local f = string.format

local S = inspector.S

local get_safe_short_description = futil.get_safe_short_description

function inspector.get_luaentity_description(ent)
	if not ent.name then
		return "<unknown?>"
	elseif ent.name == "__builtin:item" then
		return f(
			"__builtin:item [%s] dropped %.1fs ago by %s",
			ent.itemstring or "??",
			ent.age or -math.huge,
			ent.dropped_by or "???"
		)
	elseif ent.owner then
		if ent.protected or ent.dreamcatcher or ent.locked then
			return f("%s owned by %s (protected)", ent.name, ent.owner)
		else
			return f("%s owned by %s", ent.name, ent.owner)
		end
	else
		return ent.name
	end
end

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
			inspector.chat_send_player(player, "nothing")
		elseif pointed_thing.type == "node" then
			local under_pos = pointed_thing.under
			local under_node = minetest.get_node(under_pos)
			local under_name = under_node.name
			local under_def = minetest.registered_nodes[under_name]

			local desc, light_level
			if under_def then
				desc = get_safe_short_description(under_node.name)
				if under_def.paramtype == "light" then
					light_level = minetest.get_node_light(under_pos, minetest.get_timeofday())
				else
					light_level = minetest.get_node_light(pointed_thing.above, minetest.get_timeofday())
				end
			else
				desc = f("%s (%s)", under_name, get_safe_short_description(under_name))
				light_level = minetest.get_node_light(pointed_thing.above, minetest.get_timeofday())
			end

			inspector.chat_send_player(
				player,
				"node @@@1: @2 param1=@3 param2=@4 light=@5",
				minetest.pos_to_string(under_pos),
				desc,
				under_node.param1,
				under_node.param2,
				light_level
			)
		elseif pointed_thing.type == "object" then
			local obj = pointed_thing.ref

			if minetest.is_player(obj) then
				inspector.chat_send_player(player, "player: @1", obj:get_player_name())
			else
				local lua_entity = obj:get_luaentity()
				if lua_entity then
					inspector.chat_send_player(player, "luaentity: @1", inspector.get_luaentity_description(lua_entity))
				else
					inspector.chat_send_player(
						player,
						"impossible. an object which is neither a player nor a lua entity?"
					)
				end
			end
		end
	end,
})

minetest.register_alias("replacer:inspector", "inspector:inspector")
