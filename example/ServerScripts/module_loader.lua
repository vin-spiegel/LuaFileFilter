---@module module_loader 모듈 로더
local modules = {
    case1=require "lib/module1",
    case2 = require 'lib/module2',
    case3 = require ('lib/module3'),
    case4 = require ("lib/module4"),
}

-- logger
return modules