futil.check_version({ year = 2024, month = 2, day = 20 }, "dedupe")

replacer = fmod.create()

replacer.dofile("api", "init")
replacer.dofile("materials")
replacer.dofile("replacer")
replacer.dofile("creaplacer")
replacer.dofile("craft")
replacer.dofile("compat", "init")
