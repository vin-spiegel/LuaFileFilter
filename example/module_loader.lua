---@module module_loader 모듈 로더
local modules = {
    case1=require "lib/module1",
    case2 = require 'lib/module2',
    case3 = require ('lib/module3'),
    case4 = require ("lib/module4"),
    case5 = require"lib/module5",
    case6 = require'lib/module6',
    case7 = require'lib/module6',
    case8 = require'lib/module6',
    case9 = require'lib/module6',
    case10 = require'lib/function1',
}

-- logger
return modules