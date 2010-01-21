#!/usr/bin/lua

local matroska = require("matroska")

local verbose = nil
if arg[1] == '-v' then
    verbose = 1
    arg[1] = arg[2]
end
local m = matroska:open(arg[1])
for k,l,v in m:info() do
    print(k,v)
    if not verbose and k == 'Cluster' then
        break
    end
end
m:close()
