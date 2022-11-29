futil.check_version({ year = 2022, month = 10, day = 24 })

replacer = fmod.create()

replacer.dofile("api", "init")
replacer.dofile("materials")
replacer.dofile("replacer")
replacer.dofile("creaplacer")
replacer.dofile("craft")
replacer.dofile("compat", "init")
