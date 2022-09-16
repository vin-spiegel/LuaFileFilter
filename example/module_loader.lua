---@module module_loader 모듈 로더
local modules = {
    case1 = require ("lib/test_module1"),
    case2 = require ("lib/test_module2"),
    case3 = require ("lib/test_module3"),
    case4 = require ("lib/test_module4")
}

-- logger
for _, module in pairs(modules) do
    if module ~= nil then
        print("success".. case1 .. "is loaded")
    end
end

return modules