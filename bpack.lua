
require("pack")

local substr   = string.sub
local ord      = string.byte
local push     = table.insert
local sprintf  = string.format
local stringx  = string.rep

local function dump(t)
    for i,v in ipairs(t) do
        print(i..':'..v)
    end
end


local function mybunpack_in_lua(format, str)

    local i = 1
    local v
    local t = {}
    for k=1,#(format) do
        v = substr(format,k,k)
        if     v == 'b' then
            v = ord(str, i, i)
            i = i+1
        elseif v == 'L' then
            v = {ord(str, i, i+3)}
            v = 256 * ( 256 * ( 256 * v[1] + v[2] ) + v[2]) + v[4]
            i = i+4
            
        elseif v == 'Q' then
            v = {ord(str, i, i+7)}
            v = 256 * ( 
                256 * ( 
                256 * (
                256 * ( 
                256 * ( 
                256 * ( 
                256 * v[1] + v[2] ) + v[2]) + v[4] ) + v[5] ) + v[6]) + v[7]) + v[8]
            i = i+8
        end
        push(t,v)
    end

    return t
end

local bunpack = string.unpack
local bunpack = function(str, format)
    local i = 4
    local f = substr(format, 2, 2)
    if f == "Q" or f == "q" then
        i = 8
    end
    local s, v = bunpack(stringx("\000", i-#(str))..str, format)
    return tonumber(v)
end

return bunpack

