local api = replacer.api

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
