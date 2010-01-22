#!/usr/bin/lua

local matroska = require("matroska")

local m = matroska:open(arg[2])

if arg[1] == "tracks" then
    local tracks = {}
    for a=3,#arg do
        local tn, fn = string.match(arg[a],"(.*):(.*)")
        if tn and fn then
            print(tn, fn)
            tracks[tonumber(tn)] = fn
        end
    end
    for i,track in pairs(m:tracks()) do
        i = track.TrackNumber
        if tracks[i] ~= nil then
            tracks[i] = assert(io.open(tracks[i],"w"))
            for k,v in pairs(track) do
                io.stderr:write(k,":\t",v,"\n")
            end
        end
    end

    if #tracks then
        io.stderr:write("dumping tracks\n")
        m:reset()
        for k,l,t,timecode,pos,size in m:iterator() do
            if k == "Block" and tracks[t] ~= nil then
                io.stderr:write(k,"\t",t,"\t",timecode,"\t",pos,"\t",size,"\n")
                local data = m:read(pos, size)
                tracks[t]:write(data)
            end
        end
        for _,fh in ipairs(tracks) do
            fh:close()
        end
    end
end

m:close()
