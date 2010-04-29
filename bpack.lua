
require("pack")

local substr   = string.sub
local ord      = string.byte
local push     = table.insert
local stringx  = string.rep

local function _decode(v, str, i)
    if     v == 'L' then
        local v1 = ord(str, i)
        i = i + 1
        v1 = 256 * v1 + ord(str, i)
        i = i + 1
        v1 = 256 * v1 + ord(str, i)
        i = i + 1
        return 256 * v1 + ord(str, i), i + 1
    elseif v == 'b' then
        return ord(str, i, i), i+1
    elseif v == 'Q' then
        v = {ord(str, i, i+7)}
        v = 256 * ( 
            256 * ( 
            256 * (
            256 * ( 
            256 * ( 
            256 * ( 
            256 * v[1] + v[2] ) + v[3]) + v[4] ) + v[5] ) + v[6]) + v[7]) + v[8]
        return v, i + 8
    end
end

string.mybunpack_in_lua = function(str, format)

    if #(format) == 1 then
        local v, _ = _decode(format, str, 1) 
        return v
    end

    local i = 1
    local v
    local t = {}
    for k=1,#(format) do
        v, i = _decode(substr(format,k,k), str, i)
        push(t,v)
    end

    return unpack(t)
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

