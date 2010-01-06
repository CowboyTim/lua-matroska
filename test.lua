
require("lpack")

local bunpack = string.unpack

local function dump(t)
    for i,v in ipairs(t) do
        print(i..':'..v)
    end
end

print("SHORT")
dump(bunpack('S', '\001'))
print("LONG")
dump(bunpack('L', '\000\000\000\000'))
print("LONG")
dump(bunpack('SLLSS', '\001\000\000\000\002\000\000\001\001\010\020'))
print("LONG")
dump(bunpack('SLLSS', '\001\255\255\255\255\000\000\001\001\010\020'))
print("LONG")
dump(bunpack('SJSS', '\001\000\000\010\255\255\255\255\255\010\020'))
