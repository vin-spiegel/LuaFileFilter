---@module module2 Case2

local a = function()  
    print("this is module2")
end
return {
    logger = function(...)
        print(...)
    end,
    a
}