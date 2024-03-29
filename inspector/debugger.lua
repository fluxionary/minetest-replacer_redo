local f = string.format

local S = inspector.S

local dedupe_by_player = futil.dedupe_by_player
local get_safe_short_description = futil.get_safe_short_description

minetest.register_tool("inspector:debugger", {
	description = S("Inspector"),
	short_description = S("Inspector"),
	inventory_image = "inspector_inspector.png^[multiply:red",
	liquids_pointable = true,
	groups = { not_in_creative_inventory = 1 },

	on_use = function(_, player, pointed_thing)
		-- left click
		if not futil.is_player(player) then
			return
		end

		if pointed_thing.type == "nothing" then
			dedupe_by_player(inspector.chat_send_player, player, "nothing")
		elseif pointed_thing.type == "node" then
			local under_pos = pointed_thing.under
			local under_node = minetest.get_node(under_pos)
			local under_name = under_node.name
			local under_def = minetest.registered_nodes[under_name]

			local desc, light_level
			if under_def then
				desc = f("%s (%s)", under_name, get_safe_short_description(under_name))
				if under_def.paramtype == "light" then
					light_level = minetest.get_node_light(under_pos, minetest.get_timeofday())
				else
					light_level = minetest.get_node_light(pointed_thing.above, minetest.get_timeofday())
				end
			else
				desc = f("%s (%s)", under_name, get_safe_short_description(under_name))
				light_level = minetest.get_node_light(pointed_thing.above, minetest.get_timeofday())
			end
			local meta = minetest.get_meta(under_pos)

			dedupe_by_player(
				inspector.chat_send_player,
				player,
				"node @@@1: @2 param1=@3 param2=@4 light=@5 meta=@6",
				minetest.pos_to_string(under_pos),
				desc,
				under_node.param1,
				under_node.param2,
				light_level,
				futil.dump(meta:to_table())
			)
		elseif pointed_thing.type == "object" then
			local obj = pointed_thing.ref

			if futil.is_player(obj) then
				local meta = obj:get_meta()
				dedupe_by_player(
					inspector.chat_send_player,
					player,
					"player=@1 meta=@2",
					obj:get_player_name(),
					futil.dump(meta:to_table())
				)
			else
				local lua_entity = obj:get_luaentity()
				if lua_entity then
					dedupe_by_player(
						inspector.chat_send_player,
						player,
						"luaentity=@1 properties=@2",
						futil.dump(lua_entity),
						futil.dump(obj:get_properties())
					)
				else
					dedupe_by_player(
						inspector.chat_send_player,
						player,
						"impossible. an object which is neither a player nor a lua entity?"
					)
				end
			end
		end
	end,
})
