local stick = inspector.materials.stick
local torch = inspector.materials.torch

if stick and torch then
	minetest.register_craft({
		output = "replacer:inspector",
		type = "shaped",
		recipe = {
			{ torch },
			{ stick },
		},
	})
end
