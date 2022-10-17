local api = replacer.api

replacer.blacklist = api.item_blacklist -- backwards compatibility

api.blacklist_item("")
api.blacklist_item("air")
api.blacklist_item("ignore")

api.blacklist_groups({unbreakable = 1})
