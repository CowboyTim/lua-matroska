#!/usr/bin/lua

require("matroska")
require("stringextra")

local match = string.find

local verbose = nil
if arg[1] == "-v" then
    verbose = 1
    arg[1] = arg[2]
end
local m = matroska:open(arg[1])
for k,l,v in m:info() do
    if k == "Segment/Info/SegmentUID" or match(k, "/CodecPrivate$") then
        v = string.hex(v)
    end
    print(k,v)
    if not verbose and k == "Segment/Cluster" then
        break
    end
end
m:close()
