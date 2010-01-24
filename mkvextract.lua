#!/usr/bin/lua

local matroska = require("matroska")

local m = matroska:open(arg[2])

if arg[1] == "tracks" then
    local raw    = {}
    local tracks = {}
    for a=3,#arg do
        local tn, fn = string.match(arg[a],"(.*):(.*)")
        if tn and fn then
            tn = tonumber(tn)
            print(tn, fn)
            tracks[tn] = fn
            if     arg[a-1] == "--raw" then
                raw[tn] = "raw"
            elseif arg[a-1] == "--fullraw" then
                raw[tn] = "fullraw"
            end
        end
    end
    for t,track in pairs(m:tracks()) do
        t = track.TrackNumber
        if tracks[t] ~= nil then
            tracks[t] = assert(io.open(tracks[t],"w"))
            if     #track.CodecPrivate and raw[t] == "fullraw" then
                -- --fullraw option in mkvextract
                tracks[t]:write(track.CodecPrivate)
            elseif #track.CodecPrivate and raw[t] == nil then
                -- no --raw/--fullraw option in mkvextract
                -- TODO
                tracks[t]:write(track.CodecPrivate)
            else
                -- --raw option: nothing extra
            end
            for k,v in pairs(track) do
                io.stderr:write(k,":\t",v,"\n")
            end
        end
    end

    if #tracks then
        io.stderr:write("dumping tracks\n")
        m:reset()
        for k,l,t,timecode,pos,size in m:iterator() do
            io.stderr:write(k,"\t",t or "<nil>","\t",timecode or "<nil>","\t",pos or "<nil>","\t",size or "<nil>","\n")
            if k == "Block" and tracks[t] ~= nil then
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
