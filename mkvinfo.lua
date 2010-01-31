#!/usr/bin/lua

require("matroska")
require("stringextra")

local verbose = nil
if arg[1] == '-v' then
    verbose = 1
    arg[1] = arg[2]
end
local m = matroska:open(arg[1])
for k,l,v in m:info() do
    if k == 'SegmentUID' or k == 'CodecPrivate' then
        v = string.hex(v)
    end
    print(k,v)
    if not verbose and k == 'Cluster' then
        break
    end
end
m:close()
