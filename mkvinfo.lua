#!/usr/bin/lua

local matroska = require("matroska")

local ord      = string.byte
local sprintf  = string.format
local subst    = string.gsub
local function hex(s)
    return subst(s,"(.)",function (x) return sprintf("%02X",ord(x)) end)
end

local verbose = nil
if arg[1] == '-v' then
    verbose = 1
    arg[1] = arg[2]
end
local m = matroska:open(arg[1])
for k,l,v in m:info() do
    if k == 'SegmentUID' or k == 'CodecPrivate' then
        v = hex(v)
    end
    print(k,v)
    if not verbose and k == 'Cluster' then
        break
    end
end
m:close()
