
local ord    = string.byte
local round  = math.modf

local function get_golomb(data, i, bit_start)
    local nrbits, rb_v, rb_c = nil, 0, 0
    while 1 do
        local v = ord(data, i, i)
        for b,h in ipairs({127, 63, 31, 15, 7, 3, 1, 0}) do
            b = b - 1
            --[[
            print("before i:"..i..",v:"..v..",b:"..b..",h:"..h..
                  ",bit_start:"..bit_start..",nrbits:"..(nrbits or "<nil>"))
            --]]
            if bit_start > b then
                if v > h then
                    v = round(v / h)
                end
            else
                if v > h then
                    if nrbits == nil then
                        nrbits = b - bit_start
                    else
                        rb_c = rb_c + 1
                        if rb_c ~= 1 then
                            rb_v = rb_v + (2^(rb_c-2)) - 1
                        end
                    end
                end
            end
            --[[
            print("after i:"..i..",v:"..v..",b:"..b..",h:"..h..
                  ",rb_v:"..(rb_v or "<nil>")..
                  ",bit_start:"..bit_start..",nrbits:"..(nrbits or "<nil>"))
            --]]
            if nrbits ~= nil and rb_c == nrbits then
                return i, b + 1, 2^nrbits - 1 + rb_v
            end
        end
        i = i + 1
        bit_start = 0
    end
end

return get_golomb
