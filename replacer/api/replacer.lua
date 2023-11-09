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
		replacer.chat_send_player(player, "you cannot copy @1", desc)
		return
	end

	local meta = toolstack:get_meta()
	meta:set_string("itemstring", node.name)
	meta:set_int("param2", node.param2)

	local def = nodestack:get_definition()
	local palette_index = minetest.strip_param2_color(node.param2, def.paramtype2)
	if palette_index then
		meta:set_int("palette_index", palette_index)
		meta:set_string(
			"description",
			table.concat({
				S("replacer"),
				desc,
				node.name,
				f("param2=%i", node.param2),
				f("palette_index=%i", palette_index),
			}, "\n")
		)
	else
		meta:set_string("palette_index", "")
		meta:set_string(
			"description",
			table.concat({
				S("replacer"),
				desc,
				node.name,
				f("param2=%i", node.param2),
			}, "\n")
		)
	end

	return toolstack
end

local function drop_filter(item)
	return minetest.registered_nodes[item]
end

function api.place(toolstack, player, pointed_thing)
	if pointed_thing.type ~= "node" then
		return
	end

	if not api.check_tool(toolstack) then
		replacer.chat_send_player(player, "placement failed: replacer not configured. use sneak+place to copy a node.")
		return
	end

	local tool_meta = toolstack:get_meta()
	local to_place_name = tool_meta:get_string("itemstring")
	local to_place_stack = ItemStack(to_place_name)

	if not to_place_stack:is_known() then
		replacer.chat_send_player(player, "placement failed: @1 is not a known node", to_place_name)
	end

	local to_place_param2 = tool_meta:get_int("param2")
	local to_place_palette_index = tonumber(tool_meta:get("palette_index"))

	if to_place_palette_index then
		local to_place_stack_meta = to_place_stack:get_meta()
		to_place_stack_meta:set_int("palette_index", to_place_palette_index)
	end

	local to_place_def = to_place_stack:get_definition()
	local to_place_desc = get_safe_short_description(to_place_stack)

	local player_name = player:get_player_name()
	local player_inv = player:get_inventory()
	local is_creative = minetest.is_creative_enabled(player_name)

	local pos = pointed_thing.above
	local to_place_node = { name = to_place_name, param2 = to_place_param2 }

	if not (is_creative or player_inv:contains_item("main", to_place_stack, true)) then
		-- none of the original item, check for the drop instead
		local drop = futil.get_primary_drop(to_place_stack, drop_filter)
		if drop and not drop:is_empty() and player_inv:contains_item("main", drop, true) then
			to_place_stack = drop
			to_place_name = drop:get_name()
			to_place_def = drop:get_definition()
			to_place_node = { name = to_place_name, param2 = to_place_param2 }
		else
			replacer.chat_send_player(player, "placement failed: you have no @1 in your inventory.", to_place_desc)
			return
		end
	end

	local can_place, reason = api.can_place(player, pos, to_place_node)

	if not can_place then
		replacer.chat_send_player(player, "placement failed: @1.", reason)
		return
	end

	local removed_from_inventory = ItemStack()

	if not is_creative then
		-- remove item from inventory
		removed_from_inventory = futil.remove_item_with_meta(player_inv, "main", to_place_stack)

		if removed_from_inventory:is_empty() then
			replacer.log("error", "failed to remove %s from %s's inventory", to_place_stack:to_string(), player_name)
			return
		else
			replacer.log("action", "removed %s from %s's inventory", to_place_stack:to_string(), player_name)
		end
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

		replacer.log("action", "%s placed %s @ %s", player_name, to_place_name, pos_to_string(placed_pos))
	else
		replacer.log("action", "%s failed to place %s @ %s", player_name, to_place_name, pos_to_string(pos))
		local leftover2 = player_inv:add_item("main", removed_from_inventory)
		if not leftover2:is_empty() then
			if not minetest.add_item(pos, leftover2) then
				replacer.log("action", "lost %s", leftover:to_string())
			end
		end
	end
end

local function allow_tweak_param2(paramtype2)
	return paramtype2 == "wallmounted"
		or paramtype2 == "facedir"
		or paramtype2 == "4dir"
		or paramtype2 == "degrotate"
		or paramtype2 == "meshoptions"
end

function api.replace(toolstack, player, pointed_thing)
	if pointed_thing.type ~= "node" then
		return
	end

	if not api.check_tool(toolstack) then
		replacer.chat_send_player(
			player,
			"replacement failed: replacer not configured. use sneak+place to copy a node."
		)
		return
	end

	local tool_meta = toolstack:get_meta()
	local to_place_name = tool_meta:get_string("itemstring")
	local to_place_stack = ItemStack(to_place_name)

	if not to_place_stack:is_known() then
		replacer.chat_send_player(player, "placement failed: @1 is not a known node", to_place_name)
	end

	local to_place_param2 = tool_meta:get_int("param2")
	local to_place_palette_index = tonumber(tool_meta:get("palette_index"))

	if to_place_palette_index then
		local to_place_stack_meta = to_place_stack:get_meta()
		to_place_stack_meta:set_int("palette_index", to_place_palette_index)
	end

	local to_place_def = to_place_stack:get_definition()
	local to_place_desc = get_safe_short_description(to_place_stack)

	local player_name = player:get_player_name()
	local player_inv = player:get_inventory()
	local is_creative = minetest.is_creative_enabled(player_name)

	local pos = pointed_thing.under
	local current_node = minetest.get_node(pos)
	local to_place_node = { name = to_place_name, param2 = to_place_param2 }

	if not (is_creative or player_inv:contains_item("main", to_place_stack, true)) then
		-- none of the original item, check for the drop instead
		local drop = futil.get_primary_drop(to_place_stack, drop_filter)
		if drop and not drop:is_empty() and player_inv:contains_item("main", drop, true) then
			to_place_stack = drop
			to_place_name = drop:get_name()
			to_place_def = drop:get_definition()
			to_place_node = { name = to_place_name, param2 = to_place_param2 }
		else
			replacer.chat_send_player(player, "placement failed: you have no @1 in your inventory.", to_place_desc)
			return
		end
	end

	local can_replace, reason = api.can_replace(player, pos, current_node, to_place_node)

	if not can_replace then
		replacer.chat_send_player(player, "replacement failed: @1.", reason)
		return
	end

	if current_node.name == to_place_name and allow_tweak_param2(to_place_def.paramtype2) then
		if current_node.param2 ~= to_place_param2 then
			-- just tweak param2
			minetest.swap_node(pos, { name = to_place_name, param2 = to_place_param2 })
			replacer.log(
				"action",
				"%s set param2=%s of %s @ %s",
				player_name,
				to_place_param2,
				to_place_name,
				pos_to_string(pos)
			)
		end
		-- nothing to do
		return
	end

	-- remember these in case we need to undo
	local old_meta = minetest.get_meta(pos):to_table()
	local old_player_inventory = player_inv:get_list("main")

	local current_node_stack = ItemStack(current_node.name)
	local current_node_def = current_node_stack:get_definition()
	local was_dug
	if current_node_def.on_dig then
		-- note that unifieddyes.on_dig is currently bugged
		-- https://github.com/mt-mods/unifieddyes/pull/15
		was_dug = current_node_def.on_dig(pos, current_node, player)
	else
		was_dug = minetest.node_dig(pos, current_node, player)
	end

	if not was_dug then
		minetest.swap_node(pos, current_node)
		minetest.get_meta(pos):from_table(old_meta)
		player_inv:set_list("main", old_player_inventory)
		replacer.chat_send_player(player, "replacement failed: removal failed for unknown reason.")
		return
	end

	if not is_creative then
		-- remove item from inventory
		local removed_from_inventory = futil.remove_item_with_meta(player_inv, "main", to_place_stack)

		if removed_from_inventory:is_empty() then
			minetest.swap_node(pos, current_node)
			minetest.get_meta(pos):from_table(old_meta)
			player_inv:set_list("main", old_player_inventory)

			replacer.log("error", "failed to remove %s from %s's inventory", to_place_stack:to_string(), player_name)
			replacer.chat_send_player(
				player,
				"replacement failed: failed to remove @1 from your inventory",
				to_place_desc
			)
			return
		else
			replacer.log("action", "removed %s from %s's inventory", to_place_stack:to_string(), player_name)
		end
	end

	local leftover, placed_pos
	local to_place_pointed_thing = { type = "node", above = pos, under = pos }

	if to_place_def.on_place then
		leftover = to_place_def.on_place(to_place_stack, player, to_place_pointed_thing)
		placed_pos = pos
	else
		leftover, placed_pos = minetest.item_place_node(to_place_stack, player, to_place_pointed_thing)
		-- NOTE: to_place_stack gets munged by item_place_node
	end

	if placed_pos and ((leftover and leftover:is_empty()) or is_creative) then
		-- placement succeeded
		local placed_node = minetest.get_node(placed_pos)

		if placed_node.param2 ~= to_place_param2 then
			-- fix param2 if necessary
			placed_node.param2 = to_place_param2
			minetest.swap_node(placed_pos, placed_node)
		end

		replacer.log(
			"action",
			"%s replaced %s:%s with %s:%s @ %s",
			player_name,
			current_node.name,
			current_node.param2,
			to_place_name,
			to_place_param2,
			pos_to_string(placed_pos)
		)
	else
		-- failed to place, undo the break
		minetest.swap_node(pos, current_node)
		minetest.get_meta(pos):from_table(old_meta)
		player_inv:set_list("main", old_player_inventory)

		replacer.chat_send_player(player, "replacement failed: could not place @1 for unknown reason", to_place_desc)
	end
end
