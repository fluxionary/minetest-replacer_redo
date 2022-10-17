local f = string.format

local S = replacer.S

local get_safe_short_description = futil.get_safe_short_description

local api = {}

api.item_blacklist = {}
api.groups_blacklist = {}
api.item_replace_blacklist = {}
api.groups_replace_blacklist = {}

function api.blacklist_item(itemstring)
    api.item_blacklist[itemstring] = true
end

function api.blacklist_groups(groups)
    table.insert(api.groups_blacklist, groups)
end

function api.is_blacklisted(itemstring)
    if api.item_blacklist[itemstring] then
        return true
    end

    local def = minetest.registered_nodes[itemstring]

    if not def then
        return true
    end

    local node_groups = def.groups

    for _, groups in ipairs(api.groups_blacklist) do
        local all = true

        for group, value in pairs(groups) do
            local node_value = node_groups[group]
            if (not node_value) or node_value >= value then
                all = false
                break
            end
        end

        if all then
            return true
        end
    end

    return false
end

function api.blacklist_item_replacement(itemstring)
    api.item_replace_blacklist[itemstring] = true
end

function api.blacklist_groups_replacement(groups)
    table.insert(api.groups_replace_blacklist, groups)
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

    local node_groups = def.groups

    for _, groups in ipairs(api.groups_replace_blacklist) do
        local all = true

        for group, value in pairs(groups) do
            local node_value = node_groups[group]
            if (not node_value) or node_value >= value then
                all = false
                break
            end
        end

        if all then
            return true
        end
    end

    return api.is_blacklisted(itemstring)
end

function api.check_tool(toolstack)
    local tool_meta = toolstack:get_meta()
    local itemstring = tool_meta:get_string("itemstring")

    if api.is_blacklisted(itemstring) then
        tool_meta:set_string("itemstring", "")
        tool_meta:set_string("description", "")
        return false
    end

    return true
end

function api.can_copy(player, pos, node)
    local player_name = player:get_player_name()

    if minetest.is_creative_enabled(player_name) then
        return true
    end

    return not api.is_blacklisted(node.name)
end

function api.can_place(player, pos, node)
    local player_name = player:get_player_name()

    if minetest.is_protected(pos, player_name) then
        minetest.record_protection_violation(pos, player_name)
        return false
    end

    if api.is_blacklisted(node.name) then
        return false
    end

    local current_node = minetest.get_node(pos)
    local current_def = minetest.registered_nodes[current_node]

    if not (current_def and current_def.buildable_to) then
        return false
    end

    return true
end

function api.can_replace(player, pos, current_node, replace_node)
    local player_name = player:get_player_name()

    if minetest.is_protected(pos, player_name) then
        minetest.record_protection_violation(pos, player_name)
        return false
    end

    if api.is_replacement_blacklisted(current_node.name) then
        return false
    end

    if minetest.is_creative_enabled(player_name) then
        return true
    end

    local current_def = minetest.registered_nodes[current_node.name]
    if not (current_def and current_def.diggable) then
        return false
    end

    return true
end

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

    local node_meta = minetest.get_meta(pos)
    local serialized_meta = minetest.serialize(node_meta:to_table())

    local tool_meta = toolstack:get_meta()
    tool_meta:set_string("itemstring", node.name)
    tool_meta:set_int("param2", node.param2)
    tool_meta:set_string("node_meta", serialized_meta)

    tool_meta:set_string(
        "description",
        table.concat({S("creaplacer"), desc, node.name, f("param2=%i", node.param2), f("meta=%s", serialized_meta)}, "\n")
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

    if not api.can_place(player, pos, new_node) then
        replacer.tell(player, S("placement failed: you cannot place @1 there.", to_place_desc))
        return
    end

    if not (is_creative or player_inv:contains_item("main", to_place_stack)) then
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

    if placed_pos and leftover and leftover:is_empty() then
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

        replacer.log("action", "%s placed %s @ %s", player_name, to_place_name, minetest.pos_to_string(placed_pos))

    else
        replacer.log("action", "%s failed to place %s @ %s", player_name, to_place_name, minetest.pos_to_string(pos))
    end
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

    local leftover, placed_pos

    if to_place_def.on_place then
        leftover = to_place_def.on_place(to_place_stack, player, pointed_thing)
        placed_pos = pos

    else
        leftover, placed_pos = minetest.item_place_node(to_place_stack, player, pointed_thing)
    end

    if placed_pos and leftover and leftover:is_empty() then
        -- placement succeeded
        local placed_node = minetest.get_node(placed_pos)

        if placed_node.param2 ~= to_place_param2 then
            -- fix param2 if necessary
            placed_node.param2 = to_place_param2
            minetest.swap_node(placed_pos, placed_node)
        end

        local node_meta = minetest.get_meta(placed_pos)
        node_meta:from_table(minetest.deserialize(tool_meta:get_string("node_meta")))

        replacer.log("action", "%s creative-placed %s @ %s", player_name, to_place_name, minetest.pos_to_string(placed_pos))

    else
        replacer.log("action", "%s failed to creative-place %s @ %s", player_name, to_place_name, minetest.pos_to_string(pos))
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
    local current_stack = ItemStack(current_node.name)
    local current_desc = get_safe_short_description(current_stack)

    local new_node = {name = to_place_name, param1 = 0, param2 = to_place_param2}

    if not api.check_tool(toolstack) then
        replacer.tell(player, S("replacement failed: replacer not configured. use sneak+right-click to copy a node."))
        return
    end

    if not api.can_replace(player, pos, current_node, new_node) then
        replacer.tell(player, S("replacement failed: you cannot replace @1 with @2 there.", current_desc, to_place_desc))
        return
    end

    if not (is_creative or player_inv:contains_item("main", to_place_stack)) then
        replacer.tell(player, S("replacement failed: you have no @1 in your inventory.", to_place_desc))
        return
    end

    if current_node.name == to_place_name then
        if current_node.param2 ~= to_place_param2 then
            -- just tweak param2
            minetest.swap_node(pos, { name = to_place_name, param2 = to_place_param2 })
            replacer.log("action", "%s set param2=%s of %s @ %s",
                player_name, to_place_param2, to_place_name, minetest.pos_to_string(pos))
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

    if leftover and leftover:is_empty() and placed_pos then
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
                minetest.pos_to_string(placed_pos))

        else
            replacer.log("action", "%s (creative) replaced %s:%s with %s:%s @ %s",
                player_name, current_node.name, current_node.param2, to_place_name, to_place_param2,
                minetest.pos_to_string(placed_pos))
        end

    else
        -- failed to place, undo the break
        minetest.swap_node(pos, current_node)
        minetest.get_meta(pos):from_table(old_meta)
        player_inv:set_list("main", old_player_inventory)
        replacer.tell(player, S("replacement failed: could not place @1 for unknown reason", to_place_desc))
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
    local spos = minetest.pos_to_string(pos)

    local current_node = minetest.get_node(pos)
    local current_stack = ItemStack(current_node.name)
    local current_desc = get_safe_short_description(current_stack)

    local new_node = {name = to_place_name, param1 = 0, param2 = to_place_param2}

    if not api.check_tool(toolstack) then
        replacer.tell(player, S("Replacement failed: replacer not configured. Use sneak+right-click to copy a node."))
        return
    end

    if not api.can_replace(player, pos, current_node, new_node) then
        replacer.tell(player, S("replacement failed: you cannot replace @1 with @2 there.", current_desc, to_place_desc))
        return
    end

    if current_node.name == to_place_name then
        if current_node.param2 ~= to_place_param2 then
            -- just tweak param2
            minetest.swap_node(pos, { name = to_place_name, param2 = to_place_param2 })
            replacer.log("action", "%s set param2=%s of %s @ %s",
                player_name, to_place_param2, to_place_name, minetest.pos_to_string(pos))
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
    local leftover, placed_pos
    local to_place_pointed_thing = {type = "node", above = pos, under = pos}

    if to_place_def.on_place then
        leftover = to_place_def.on_place(to_place_stack, player, to_place_pointed_thing)
        placed_pos = pos

    else
        leftover, placed_pos = minetest.item_place_node(to_place_stack, player, to_place_pointed_thing)
    end

    if leftover and leftover:is_empty() and placed_pos then
        -- placement succeeded
        local placed_node = minetest.get_node(placed_pos)

        if placed_node.param2 ~= to_place_param2 then
            -- fix param2 if necessary
            placed_node.param2 = to_place_param2
            minetest.swap_node(placed_pos, placed_node)
        end

        local node_meta = minetest.get_meta(placed_pos)
        node_meta:from_table(minetest.deserialize(tool_meta:get_string("node_meta")))

        replacer.log("action", "%s (creative) replaced %s:%s with %s:%s @ %s",
            player_name, current_node.name, current_node.param2, to_place_name, to_place_param2,
            minetest.pos_to_string(placed_pos))

    else
        -- failed to place, undo the break
        minetest.set_node(pos, current_node)
        minetest.get_meta(pos):from_table(old_node_meta)
        replacer.tell(player, S("replacement failed: @1 for unknown reasons", to_place_desc))
    end
end

replacer.api = api
