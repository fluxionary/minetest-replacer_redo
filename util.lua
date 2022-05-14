replacer.util = {}

function replacer.util.get_description(item_or_string)
    if type(item_or_string) == "string" then
        item_or_string = ItemStack(item_or_string)
    end
    return item_or_string:get_short_description() or item_or_string:get_description()
end
