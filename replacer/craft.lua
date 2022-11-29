local chest = replacer.materials.chest
local steel = replacer.materials.steel
local gold = replacer.materials.gold
local crystal = replacer.materials.crystal

if chest and steel and gold and crystal then
	minetest.register_craft({
		output = "replacer:replacer",
		type = "shaped",
		recipe = {
			{ chest, "", gold },
			{ "", crystal, "" },
			{ steel, "", chest },
		},
	})
end
