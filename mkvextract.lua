#!/usr/bin/lua

local matroska = require("matroska")

local m = matroska:open(arg[1])
for i,t in pairs(m:tracks()) do
    print('Track ',i)
    for k,v in pairs(t) do
        print(' ',k,v)
    end
end
m:close()
