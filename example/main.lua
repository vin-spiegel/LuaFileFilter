-- main.lua
local myModule = require("module_loader")

print("logging main....")

myModule.case1.logger("Hello, World")
myModule.case5("Call module function")
