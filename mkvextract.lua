#!/usr/bin/lua

require("matroska")

local m = matroska:open(arg[2])

local match = string.find
local subst = string.gsub

if arg[1] == "tracks" then
    local raw    = {}
    local tracks = {}
    for a=3,#arg do
        local tn, fn = string.match(arg[a],"(.*):(.*)")
        if tn and fn then
            tn = tonumber(tn)
            io.stderr:write(tn, "\t", fn, "\n")
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
            if     raw[t] == "fullraw" then
                -- --fullraw option in mkvextract
                if track.CodecPrivate ~= nil then
                    tracks[t]:write(track.CodecPrivate)
                end
            elseif raw[t] == nil then
                -- no --raw/--fullraw option in mkvextract
                local codec = "codec_"..subst(track.CodecID,"[^%w]+", "_")
                codec = require(codec)
                tracks[t] = codec:new(tracks[t], track.CodecPrivate)
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
        for k,l,t,timecode,pos,size in m:grep("^Segment/Cluster/BlockGroup") do
            if tracks[t] ~= nil and (
                match(k, "/Block$") or match(k, "/SimpleBlock$") 
            ) then
                io.stderr:write(
                    k                  ,"\t",
                    t        or "<nil>","\t",
                    timecode or "<nil>","\t",
                    pos      or "<nil>","\t",
                    size     or "<nil>","\n")
                tracks[t]:write(m:read(pos, size))
            end
        end
    end
end

m:close()
