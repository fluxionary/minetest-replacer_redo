local f = string.format

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local S = minetest.get_translator(modname)

replacer = {
    version = os.time({ year = 2022, month = 10, day = 17 }),
    fork = "fluxionary",

    modname = modname,
    modpath = modpath,

    S = S,

    has = {
        default = minetest.get_modpath("default"),
    },

    log = function(level, message, ...)
        message = f(message, ...)
        minetest.log(level, f("[%s] %s", modname, message))
    end,

    tell = function(player, message, ...)
        if type(player) ~= "string" then
            player = player:get_player_name()
        end

        message = f(message, ...)
	    minetest.chat_send_player(player, f("[%s] %s", modname, message))
    end,

    dofile = function(...)
        dofile(table.concat({ modpath, ... }, DIR_DELIM) .. ".lua")
    end,
}

replacer.dofile("api", "init")
replacer.dofile("materials")
replacer.dofile("replacer")
replacer.dofile("creaplacer")
replacer.dofile("craft")
replacer.dofile("compat", "init")
