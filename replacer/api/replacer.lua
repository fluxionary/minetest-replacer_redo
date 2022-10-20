local f = string.format

local pos_to_string = minetest.pos_to_string

local S = replacer.S

local get_safe_short_description = futil.get_safe_short_description

local api = replacer.api

function api.copy(toolstack, player, pointed_thing)
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

	local meta = toolstack:get_meta()
	meta:set_string("itemstring", node.name)
	meta:set_int("param2", node.param2)

	meta:set_string(
		"description",
		table.concat({S("replacer"), desc, node.name, f("param2=%i", node.param2)}, "\n")
	)

	return toolstack
end

function api.place(toolstack, player, pointed_thing)
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
	local is_creative = minetest.is_creative_enabled(player_name)

	local pos = pointed_thing.above
	local new_node = {name = to_place_name, param2 = to_place_param2}

	if not api.check_tool(toolstack) then
		replacer.tell(player, S("placement failed: replacer not configured. use sneak+right-click to copy a node."))
		return
	end

	local can_place, reason = api.can_place(player, pos, new_node)
	if not can_place then
		replacer.tell(player, S("placement failed: @1.", reason))
		return
	end

	if not (is_creative or player_inv:contains_item("main", to_place_stack)) then
		--local drops = futil.get_primary_drop(to_place_stack)

		replacer.tell(player, S("placement failed: you have no @1 in your inventory.", to_place_desc))
		return
	end

	local leftover, placed_pos

	if to_place_def.on_place then
		leftover = to_place_def.on_place(to_place_stack, player, pointed_thing)
		placed_pos = pos

	else
		leftover, placed_pos = minetest.item_place_node(to_place_stack, player, pointed_thing)
	end

	if placed_pos and ((leftover and leftover:is_empty()) or is_creative) then
		-- placement succeeded
		local placed_node = minetest.get_node(placed_pos)

		if placed_node.param2 ~= to_place_param2 then
			-- fix param2 if necessary
			placed_node.param2 = to_place_param2
			minetest.swap_node(placed_pos, placed_node)
		end

		if not is_creative then
			-- remove item from inventory
			local removed = player_inv:remove_item("main", ItemStack(to_place_name))

			if removed:is_empty() then
				replacer.log("error", "failed to remove %s from %s's inventory", to_place_name, player_name)

			else
				replacer.log("action", "removed %s from %s's inventory", to_place_name, player_name)
			end
		end

		replacer.log("action", "%s placed %s @ %s", player_name, to_place_name, pos_to_string(placed_pos))

	else
		replacer.log("action", "%s failed to place %s @ %s", player_name, to_place_name, pos_to_string(pos))
	end
end

function api.replace(toolstack, player, pointed_thing)
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
	local is_creative = minetest.is_creative_enabled(player_name)

	local pos = pointed_thing.under
	local current_node = minetest.get_node(pos)

	local new_node = {name = to_place_name, param1 = 0, param2 = to_place_param2}

	if not api.check_tool(toolstack) then
		replacer.tell(player, S("replacement failed: replacer not configured. use sneak+right-click to copy a node."))
		return
	end

	local can_replace, reason = api.can_replace(player, pos, current_node, new_node)
	if not can_replace then
		replacer.tell(player, S("replacement failed: @1.", reason))
		return
	end

	if not (is_creative or player_inv:contains_item("main", to_place_stack)) then
		replacer.tell(player, S("replacement failed: you have no @1 in your inventory.", to_place_desc))
		return
	end

	if current_node.name == to_place_name then
		if current_node.param2 ~= to_place_param2 then
			-- just tweak param2
			minetest.swap_node(pos, {name = to_place_name, param2 = to_place_param2})
			replacer.log("action", "%s set param2=%s of %s @ %s",
				player_name, to_place_param2, to_place_name, pos_to_string(pos))
		end
		-- nothing to do
		return
	end

	local old_meta = minetest.get_meta(pos):to_table()
	local old_player_inventory = player_inv:get_list("main")

	local was_dug = minetest.node_dig(pos, current_node, player)
	if not was_dug then
		player_inv:set_list("main", old_player_inventory)
		replacer.tell(player, S("replacement failed: digging failed for unknown reason."))
		return
	end

	local leftover, placed_pos
	local to_place_pointed_thing = {type = "node", above = pos, under = pos}

	if to_place_def.on_place then
		leftover = to_place_def.on_place(to_place_stack, player, to_place_pointed_thing)
		placed_pos = pos

	else
		leftover, placed_pos = minetest.item_place_node(to_place_stack, player, to_place_pointed_thing)
	end

	if placed_pos and ((leftover and leftover:is_empty()) or is_creative) then
		-- placement succeeded
		local placed_node = minetest.get_node(placed_pos)

		if placed_node.param2 ~= to_place_param2 then
			-- fix param2 if necessary
			placed_node.param2 = to_place_param2
			minetest.swap_node(placed_pos, placed_node)
		end

		-- to_place_stack gets munged by item_place_node, for no good reason
		if not is_creative then
			to_place_stack = ItemStack(to_place_name)
			local removed = player_inv:remove_item("main", to_place_stack)
			if removed:is_empty() then
				replacer.log("error", "failed to remove %s from %s's inventory", to_place_name, player_name)

			else
				replacer.log("action", "removed %s from %s's inventory", to_place_name, player_name)
			end

			replacer.log("action", "%s replaced %s:%s with %s:%s @ %s",
				player_name, current_node.name, current_node.param2, to_place_name, to_place_param2,
				pos_to_string(placed_pos))

		else
			replacer.log("action", "%s (creative) replaced %s:%s with %s:%s @ %s",
				player_name, current_node.name, current_node.param2, to_place_name, to_place_param2,
				pos_to_string(placed_pos))
		end

	else
		-- failed to place, undo the break
		minetest.swap_node(pos, current_node)
		minetest.get_meta(pos):from_table(old_meta)
		player_inv:set_list("main", old_player_inventory)
		replacer.tell(player, S("replacement failed: could not place @1 for unknown reason", to_place_desc))
	end
end
