---@module 테스트 모듈
local t = {}

t.a = "This is Module:lib1.lua"

t.logger = function(...)  
    print(...)
end

print("module lib1 loaded")
return t