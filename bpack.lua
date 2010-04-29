
require("pack")

local substr   = string.sub
local ord      = string.byte
local push     = table.insert
local sprintf  = string.format
local stringx  = string.rep

local function _decode(v, str, i)
    if     v == 'b' then
        v = ord(str, i, i)
        i = i+1
    elseif v == 'L' then
        v = {ord(str, i, i+3)}
        v = 256 * ( 256 * ( 256 * v[1] + v[2] ) + v[3]) + v[4]
        i = i+4
    elseif v == 'Q' then
        v = {ord(str, i, i+7)}
        v = 256 * ( 
            256 * ( 
            256 * (
            256 * ( 
            256 * ( 
            256 * ( 
            256 * v[1] + v[2] ) + v[3]) + v[4] ) + v[5] ) + v[6]) + v[7]) + v[8]
        i = i+8
    end
    return v, i
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

