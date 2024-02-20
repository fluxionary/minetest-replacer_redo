futil.check_version({ year = 2024, month = 2, day = 20 }, "dedupe")

inspector = fmod.create()

inspector.dofile("materials")
inspector.dofile("inspector")
inspector.dofile("debugger")
inspector.dofile("craft")
