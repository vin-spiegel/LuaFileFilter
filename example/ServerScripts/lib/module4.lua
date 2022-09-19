---@module module4 Case4
require("lib/depth1/module5")
local t = function(...)
    print(...)
end
print("lib/module4 loaded")
return t