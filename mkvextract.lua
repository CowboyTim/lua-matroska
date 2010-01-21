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

    local fh = io.open('/var/tmp/aa','w')
    m:reset()
    for k,l,t,timecode,pos,size in m:iterator() do
        if k == 'Block' and t == tracknr then
            print(k,t,timecode,pos,size)
            local data = m:read(pos, size)
            fh:write(data)
        end
    end
    fh:close()
end

m:close()
