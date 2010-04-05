
local B = {}

if _REQUIREDNAME == nil then
    _REQUIREDNAME = "bit"
end
_G[_REQUIREDNAME] = B


local ord    = string.byte
local round  = math.modf
local ceil   = math.ceil

local function get_golomb(data, i, bit_start)
    local nrbits, rb_v, rb_c, nr = nil, 0, 0, 0
    while 1 do
        local v = ord(data, i, i)
        for b=7-bit_start,0,-1 do
            ----[[
            print(
                "before i:"..i..",v:"..v..",b:"..b..
                ",bit_start:"..bit_start..",nrbits:"..(nrbits or "<nil>")
            )
            ----]]
            if nrbits ~= nil then
                rb_c = rb_c + 1
            end
            if v%(2^(b+1)) >= 2^b then
                print("b:"..b.." set")
                if nrbits == nil then
                    nrbits = nr
                else
                    print("b:"..b..",rb_v:"..rb_v..",rb_c:"..rb_c)
                    rb_v = rb_v + (2^(nrbits - rb_c))
                    print("b:"..b..",rb_v:"..rb_v..",rb_c:"..rb_c)
                end
            else
                nr = nr + 1
            end
            ----[[
            print(
                "after i:"..i..",v:"..v..",b:"..b..
                ",rb_v:"..(rb_v or "<nil>")..
                ",rb_c:"..(rb_c or "<nil>")..
                ",bit_start:"..bit_start..",nrbits:"..(nrbits or "<nil>")
            )
            ----]]
            if nrbits ~= nil and rb_c == nrbits then
                b = b + 1
                rb_v = 2^nrbits - 1 + rb_v
                print("golomb:i:",i,",b:",b,",v:",rb_v)
                return i, 7-b, rb_v
            end
        end
        i = i + 1
        bit_start = 0
    end
end

B.get_bit = function (data, i, bit, nrbits)
    if bit == 7 then
        i = i + 1
    end
    local byte = ord(data, i, i)
    return i, bit == 7 and 0 or bit + 1, ((byte%(2^bit) >= 2^(bit-1)) and 1) or 0
end


B.read_bits = function (byte, from, to)
    local s = 0
    for i=from,to do
        local b = 2^i
        --s = ((byte%(b*2) >= b) and s + b) or s
        if byte%(b*2) >= b then
            s = s + b
        end
    end
    s, _ = round(s/(2^from))
    return s
end

B.get_golomb    = get_golomb
B.get_ue_golomb = get_golomb
B.get_se_golomb = function(data, i, b)
    local i, b, v = get_golomb(data, i, b)
    return i, b, -1^(v+1)* ceil(v/2)
end

return B
