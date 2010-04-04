#!/usr/bin/lua

require("matroska")

local m = matroska:open(arg[1])

local match = string.find
local subst = string.gsub

local tracks = {}
for t,track in pairs(m:tracks()) do
    for k,v in pairs(track) do
        io.stderr:write(k,":\t",v,"\n")
    end
    t = track.TrackNumber
    local c_name = subst(track.CodecID,"[^%w]+", "_")
    local codec  = require("codec_"..c_name)
    local player
    local status, err = pcall(function() player = require("play_"..c_name) end)
    if status then
        player = player:new()
    else
        io.stderr:write("Error loading play_"..c_name..":"..err.."\n")
        player = assert(io.open("/dev/null", "a"))
    end 
    tracks[t] = codec:new(player, track.CodecPrivate)
end

if #tracks then
    io.stderr:write("playing tracks\n")
    m:reset()
    for k,l,t,timecode,pos,size in m:grep("^Segment/Cluster") do
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

m:close()
