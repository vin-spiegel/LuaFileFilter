-- main.lua
local t = require("lib/test_module1")
require("lib/test_module2")
require("lib/test_module3")
require("lib/test_module4")

print("logging main....")

t.logger("Hello, World")

