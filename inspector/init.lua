local f = string.format

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local S = minetest.get_translator(modname)

assert(
	type(futil.version) == "number" and futil.version >= os.time({year = 2022, month = 10, day = 24}),
	"please update futil"
)

inspector = {
	author = "flux",
	license = "AGPL_v3",
	version = os.time({year = 2022, month = 10, day = 17}),
	fork = "flux",

	modname = modname,
	modpath = modpath,
	S = S,

	has = {
		default = minetest.get_modpath("default"),
	},

	log = function(level, messagefmt, ...)
		return minetest.log(level, f("[%s] %s", modname, f(messagefmt, ...)))
	end,

	tell = function(player, message, ...)
		if type(player) ~= "string" then
			player = player:get_player_name()
		end

		message = message:format(...)
		minetest.chat_send_player(player, ("[%s] %s"):format(modname, message))
	end,

	dofile = function(...)
		return dofile(table.concat({modpath, ...}, DIR_DELIM) .. ".lua")
	end,
}

inspector.dofile("materials")
inspector.dofile("inspector")
inspector.dofile("craft")
