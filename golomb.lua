
local ord    = string.byte
local round  = math.modf

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

return get_golomb
