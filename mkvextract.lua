#!/usr/bin/lua

local matroska = require("matroska")

local m = matroska:open(arg[#arg])

if arg[1] == 'tracks' then
    local tracknr = tonumber(arg[2])
    local t
    for i,track in pairs(m:tracks()) do
        if track.TrackNumber == tracknr then
            t = track
            break
        end
    end
    for k,v in pairs(t or {}) do
        print(k,v)
    end
end

m:close()
