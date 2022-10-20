local f = string.format

local pos_to_string = minetest.pos_to_string

local S = replacer.S

local deserialize_node_meta = futil.deserialize_node_meta
local get_safe_short_description = futil.get_safe_short_description
local serialize_node_meta = futil.serialize_node_meta

local api = replacer.api

function api.creative_copy(toolstack, player, pointed_thing)
	if pointed_thing.type ~= "node" then
		return
	end

	local pos = pointed_thing.under
	local node = minetest.get_node(pos)
	local nodestack = ItemStack(node.name)
	local desc = get_safe_short_description(nodestack)

	if not api.can_copy(player, pos, node) then
		replacer.tell(player, S("you cannot copy @1", desc))
		return
	end

	local serialized_meta = serialize_node_meta(pos)

	local tool_meta = toolstack:get_meta()
	tool_meta:set_string("itemstring", node.name)
	tool_meta:set_int("param2", node.param2)
	tool_meta:set_string("node_meta", serialized_meta)

	tool_meta:set_string(
		"description",
		table.concat({
			S("creaplacer"),
			desc,
			node.name,
			f("param2=%i", node.param2),
			f("meta=%s", serialized_meta)
		}, "\n")
	)

	return toolstack
end

function api.creative_place(toolstack, player, pointed_thing)
	if pointed_thing.type ~= "node" then
		return
	end

	local tool_meta = toolstack:get_meta()
	local to_place_name = tool_meta:get_string("itemstring")
	local to_place_param2 = tool_meta:get_int("param2")
	local to_place_stack = ItemStack(to_place_name)
	local to_place_def = minetest.registered_nodes[to_place_name]
	local to_place_desc = get_safe_short_description(to_place_stack)

	local player_name = player:get_player_name()

	local pos = pointed_thing.above
	local new_node = {name = to_place_name, param2 = to_place_param2}

	if not api.check_tool(toolstack) then
		replacer.tell(player, S("placement failed: replacer not configured. use sneak+right-click to copy a node."))
		return
	end

	if not api.can_place(player, pos, new_node) then
		replacer.tell(player, S("placement failed: you cannot place @1 there.", to_place_desc))
		return
	end

	local placed_pos

	if to_place_def.on_place then
		to_place_def.on_place(to_place_stack, player, pointed_thing)
		placed_pos = pos

	else
		placed_pos = select(2, minetest.item_place_node(to_place_stack, player, pointed_thing))
	end

	if placed_pos then
		-- placement succeeded
		local placed_node = minetest.get_node(placed_pos)

		if placed_node.param2 ~= to_place_param2 then
			-- fix param2 if necessary
			placed_node.param2 = to_place_param2
			minetest.swap_node(placed_pos, placed_node)
		end

		deserialize_node_meta(tool_meta:get_string("node_meta"), placed_pos)

		replacer.log("action", "%s creative-placed %s @ %s", player_name, to_place_name, pos_to_string(placed_pos))

	else
		replacer.log("action", "%s failed to creative-place %s @ %s", player_name, to_place_name, pos_to_string(pos))
	end
end

local stuck_node_by_player_name = {}

function api.creative_replace(toolstack, player, pointed_thing)
	if pointed_thing.type ~= "node" then
		return
	end

	local tool_meta = toolstack:get_meta()
	local to_place_name = tool_meta:get_string("itemstring")
	local to_place_param2 = tool_meta:get_int("param2")
	local to_place_stack = ItemStack(to_place_name)
	local to_place_def = minetest.registered_nodes[to_place_name]
	local to_place_desc = get_safe_short_description(to_place_stack)

	local player_name = player:get_player_name()
	local player_inv = player:get_inventory()

	local pos = pointed_thing.under
	local spos = pos_to_string(pos)

	local current_node = minetest.get_node(pos)

	local new_node = {name = to_place_name, param1 = 0, param2 = to_place_param2}

	if not api.check_tool(toolstack) then
		replacer.tell(player, S("Replacement failed: replacer not configured. Use sneak+right-click to copy a node."))
		return
	end

	local can_replace, reason = api.can_replace(player, pos, current_node, new_node)
	if not can_replace then
		replacer.tell(player, S("replacement failed: @1.", reason))
		return
	end

	if current_node.name == to_place_name then
		if current_node.param2 ~= to_place_param2 then
			-- just tweak param2
			minetest.swap_node(pos, {name = to_place_name, param2 = to_place_param2})
			deserialize_node_meta(tool_meta:get_string("node_meta"), pos)

			replacer.log("action", "%s set param2=%s of %s @ %s",
				player_name, to_place_param2, to_place_name, pos_to_string(pos))
		end
		-- nothing to do
		return
	end

	local old_node_meta = minetest.get_meta(pos):to_table()
	local old_player_inventory = player_inv:get_list("main")

	local was_dug = minetest.node_dig(pos, current_node, player)
	player_inv:set_list("main", old_player_inventory)

	if not was_dug then
		local stuck_node = stuck_node_by_player_name[player_name]
		if stuck_node and stuck_node == spos then
			stuck_node_by_player_name[player_name] = nil
			minetest.remove_node(pos)
			if minetest.get_node(pos).name ~= "air" then
				replacer.tell(player, S("replacement failed: removal failed for unknown reason."))
				return
			end

		else
			replacer.tell(player, S("replacement failed: try again to force replacement (dangerous!)."))
			stuck_node_by_player_name[player_name] = spos
			return
		end
	end

	stuck_node_by_player_name[player_name] = nil

	-- luacheck: ignore leftover
	local placed_pos
	local to_place_pointed_thing = {type = "node", above = pos, under = pos}

	if to_place_def.on_place then
		to_place_def.on_place(to_place_stack, player, to_place_pointed_thing)
		placed_pos = pos

	else
		placed_pos = select(2, minetest.item_place_node(to_place_stack, player, to_place_pointed_thing))
	end

	if placed_pos then
		-- placement succeeded
		local placed_node = minetest.get_node(placed_pos)

		if placed_node.param2 ~= to_place_param2 then
			-- fix param2 if necessary
			placed_node.param2 = to_place_param2
			minetest.swap_node(placed_pos, placed_node)
		end

		deserialize_node_meta(tool_meta:get_string("node_meta"), pos)

		replacer.log("action", "%s (creative) replaced %s:%s with %s:%s @ %s",
			player_name, current_node.name, current_node.param2, to_place_name, to_place_param2,
			pos_to_string(placed_pos))

	else
		-- failed to place, undo the break
		minetest.set_node(pos, current_node)
		minetest.get_meta(pos):from_table(old_node_meta)
		replacer.tell(player, S("replacement failed: @1 for unknown reasons", to_place_desc))
	end
end
