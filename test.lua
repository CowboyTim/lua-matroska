
require("pack")
require("bpack")

local timethese = require("benchmark")

local bunpack   = string.unpack
local cbunpack  = string.unpack
local lbunpack  = string.mybunpack_in_lua


local function dump(...)
    for i,v in ipairs(arg) do
        print(i..':', v)
    end
end

print("SHORT")
dump(bunpack('\005', 'b'))
print("LONG")
dump(bunpack('\000\000\000\000', '>L'))
print("LONG")
dump(bunpack('\000\000\000\005', '>L'))
print("LONG")
dump(bunpack('\255\255\255\255', '>L'))
print("LONG")
dump(bunpack('\001\000\000\000\002\000\000\001\001\010\020', 'b>L>Lbb'))
print("LONG")
dump(bunpack('\001\255\255\255\255\000\000\001\001\010\020', 'b>L>Lbb'))
print("LONG")
dump(bunpack('\001\000\000\010\255\255\255\255\255\010\020', 'b>Qbb'))

print("SHORT")
print(lbunpack('\005', 'b'))
print("LONG")
print(lbunpack('\000\000\000\000', 'L'))
print("LONG")
print(lbunpack('\000\000\000\005', 'L'))
print("LONG")
print(lbunpack('\255\255\255\255', 'L'))
print("LONG")
dump(lbunpack('\001\000\000\000\002\000\000\001\001\010\020', 'bLLbb'))
print("LONG")
dump(lbunpack('\001\255\255\255\255\000\000\001\001\010\020', 'bLLbb'))
print("LONG")
dump(lbunpack('\001\000\000\010\255\255\255\255\255\010\020', 'bQbb'))

timethese(10000000, {
    ["lbunpack"] = function ()
        local a = lbunpack('\255\255\255\255', 'L')
    end,
    ["cbunpack"] = function () 
        local a = cbunpack('\255\255\255\255', 'L')
    end,
})
