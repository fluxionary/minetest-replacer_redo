local S = replacer.S
local api = replacer.api.replacer

minetest.register_tool("replacer:creative_replacer", {
    description = S("Replacer"),
    short_description = S("Replacer"),
    inventory_image = "replacer_replacer.png^[multiply:red",
    liquids_pointable = true,
    groups = {not_in_creative_inventory = 1},

    on_use = function(toolstack, player, pointed_thing)
        -- left click (punch)
        if not (minetest.is_player(player) and minetest.is_creative_enabled(player:get_player_name())) then
            return
        end

        return api.creative_replace(toolstack, player, pointed_thing)
    end,

    on_place = function(toolstack, player, pointed_thing)
        -- rightclick
        if not (minetest.is_player(player) and minetest.is_creative_enabled(player:get_player_name())) then
            return
        end

        local keys = player:get_player_control()
        if keys.sneak then
            return api.copy(toolstack, player, pointed_thing)
        else
            return api.place(toolstack, player, pointed_thing)
        end
    end,
})
