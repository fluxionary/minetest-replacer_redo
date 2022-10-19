local pos_to_string = minetest.pos_to_string

local S = replacer.S

local get_safe_short_description = futil.get_safe_short_description

local api = replacer.api

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
    return not api.is_blacklisted(node.name)
end

function api.can_place(player, pos, node)
    local player_name = player:get_player_name()

    if minetest.is_protected(pos, player_name) then
        minetest.record_protection_violation(pos, player_name)
        return false, S("@1 is protected", pos_to_string(pos))
    end

    if api.is_blacklisted(node.name) then
        return false, S("@1 is blacklisted", node.name)
    end

    local current_node = minetest.get_node(pos)
    local current_def = minetest.registered_nodes[current_node.name]

    if not (current_def and current_def.buildable_to) then
        return false, S("@1 is occupied", pos_to_string(pos))
    end

    return true
end

function api.can_replace(player, pos, current_node, replace_node)
    local player_name = player:get_player_name()
    local current_stack = ItemStack(current_node.name)
    local current_desc = get_safe_short_description(current_stack)

    if minetest.is_protected(pos, player_name) then
        minetest.record_protection_violation(pos, player_name)
        return false, S("@1 is protected", pos_to_string(pos))
    end

    if api.is_replacement_blacklisted(current_node.name) then
        return false, S("replacing @1 is blacklisted", current_desc)
    end

    return true
end
