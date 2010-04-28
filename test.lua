
require("pack")
require("bpack")

local bunpack = string.unpack

local function dump(...)
    for i,v in ipairs(arg) do
        print(i..':'..v)
    end
end

print("SHORT")
dump(bunpack('\005', 'b'))
print("LONG")
dump(bunpack('\000\000\000\000', 'L'))
print("LONG")
dump(bunpack('\000\000\000\005', 'L'))
print("LONG")
dump(bunpack('\255\255\255\255', 'L'))
print("LONG")
dump(bunpack('\001\000\000\000\002\000\000\001\001\010\020', 'bLLbb'))
print("LONG")
dump(bunpack('\001\255\255\255\255\000\000\001\001\010\020', 'bLLbb'))
print("LONG")
dump(bunpack('\001\000\000\010\255\255\255\255\255\010\020', 'bQbb'))

local timethese = require("benchmark")

local cbunpack = string.unpack
local lbunpack = string.mybunpack_in_lua

timethese(5000000, {
    ["lbunpack"] = function ()
        local a = lbunpack('\255\255\255\255', 'L')
    end,
    ["cbunpack"] = function () 
        local a = cbunpack('\255\255\255\255', 'L')
    end,
})
