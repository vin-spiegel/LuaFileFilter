---@module module1 Case1
local t = {}
t.logger = function(...)
    print(...)
end
print("test module1 loaded")
return t