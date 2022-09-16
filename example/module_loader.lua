---@module module_loader 모듈 로더
local modules = {
    case1=require "lib/test_module1",
    case2 = require 'lib/test_module2',
    case3 = require ('lib/test_module3'),
    case4 = require ("lib/test_module4"),
    case5 = require"lib/test_module5",
    case6 = require'lib/test_module6',
    case7 = require'lib/test_module6',
    case8 = require'lib/test_module6',
    case9 = require'lib/test_module6',
}

-- logger
return modules