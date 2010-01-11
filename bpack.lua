
local L = _G.string

local subst   = string.gsub
local substr  = string.sub
local ord     = string.byte
local push    = table.insert
local sprintf = string.format

local function hex(s)
    return subst(s,"(.)",function (x) return sprintf("%02X",ord(x)) end)
end


L.unpack = function(format, str)

    local i = 1
    local t = {}
    for k=1,#(format) do
        local x = substr(format,k,k)
        print('x:'..x)
        local j
        if     x == 'b' then
            j = i
            print('i:'..i..',j:'..j)
            local s = substr(str,i,j)
            v = ord(s)
        elseif x == 'L' then
            j = i + 3
            print('i:'..i..',j:'..j)
            local s = substr(str,i,j)
            v =   256 * 256 * 256 * ord(substr(s,1,1))
                + 256 * 256 * ord(substr(s,2,2))
                + 256 * ord(substr(s,3,3))
                + ord(substr(s,4,4))
        elseif x == 'J' then
            j = i + 7
            print('i:'..i..',j:'..j)
            local s = substr(str,i,j)
            v =   256 * 256 * 256 * 256 * 256 * 256 * 256 * ord(substr(s,1,1))
                + 256 * 256 * 256 * 256 * 256 * 256 * ord(substr(s,2,2))
                + 256 * 256 * 256 * 256 * 256 * ord(substr(s,3,3))
                + 256 * 256 * 256 * 256 * ord(substr(s,4,4))
                + 256 * 256 * 256 * ord(substr(s,5,5))
                + 256 * 256 * ord(substr(s,6,6))
                + 256 * ord(substr(s,7,7))
                + ord(substr(s,8,8))
        end
        push(t,v)
        i = j+1
    end

    print(newformat)

--    subst(str,newformat,function (...) 
--        for i,x in ipairs(arg) do
--            print('length:'..#(x)..',s:'..hex(x))
--            local v
--            if     #(x) == 1 then
--                v = ord(x)
--            elseif #(x) == 4 then
--                v =   256 * 256 * 256 * ord(substr(x,1,1))
--                    + 256 * 256 * ord(substr(x,2,2))
--                    + 256 * ord(substr(x,3,3))
--                    + ord(substr(x,4,4))
--            end
--            push(t,v)
--        end
--    end)
    return t
end

return L
