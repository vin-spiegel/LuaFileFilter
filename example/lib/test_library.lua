---@module 테스트 모듈
local t = {}

t.logger = function(...)  
    print(...)
end

print("module loaded: [lib/test_library]")
return t