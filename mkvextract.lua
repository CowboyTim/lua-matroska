#!/usr/bin/lua

local matroska = require("matroska")

require("pack")
local bunpack  = string.unpack

local m = matroska:open(arg[2])

local substr   = string.sub
local ord      = string.byte
local stringx  = string.rep

local bunpack = function(str, format)
    local i = 4
    local f = substr(format, 2, 2)
    if f == "Q" or f == "q" then
        i = 8
    end
    local s, v = bunpack(stringx("\000", i-#(str))..str, format)
    return tonumber(v)
end

local function write_nal(fh, data, where, size_size)
    fh:write('\000\000\000\001')
    local start     = where + size_size
    local size_end  = bunpack(substr(data,where,start-1),">L")
    size_end        = start + size_end - 1
    io.stderr:write("write_nal\t",start, "\t",size_end,"\t",size_size,"\n")
    fh:write(substr(data,start,size_end))
    return size_end + 1
end

local function testbit_5(s)
    return s % 32 >= 16
end

local function testbit_4(s)
    return s % 16 >= 8
end

local function testbit_3(s)
    return s % 8 >= 4
end

local function testbit_2(s)
    return s % 4 >= 2
end

local function testbit_1(s)
    return s % 2 >= 1
end

local function testbit_0(s)
    return s % 1 >= 0
end


local function write_codec_header(fh, data)
    local nal_size_size = 1 
    local buf = ord(substr(data, 5,5))
    if testbit_1(nal_size_size) then
        nal_size_size = 2
    end
    if testbit_0(nal_size_size) then
        nal_size_size = nal_size_size + 1
    end
    io.stderr:write("data\t",#data,"\tnal_size_size:\t",nal_size_size, "\n")

    local numsps = 0 
    buf = ord(substr(data, 6,6))
    if testbit_5(buf) then
        numsps = numsps + 32
    end
    if testbit_4(buf) then
        numsps = numsps + 16
    end
    if testbit_3(buf) then
        numsps = numsps + 8
    end
    if testbit_2(buf) then
        numsps = numsps + 4
    end
    if testbit_1(buf) then
        numsps = numsps + 2
    end
    if testbit_0(buf) then
        numsps = numsps + 1
    end
    io.stderr:write("numsps:\t",numsps, "\n")

    local numpps = 7
    for i=1,numsps do
        numpps =write_nal(fh,data,numpps,2)
    end
    numpps = ord(substr(data,numpps,numpps))
    if numpps == nil then
        return
    end
    for i=1,numpps do
        write_nal(fh,data,6,2)
    end


end

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
            if track.CodecPrivate ~= nil then
                if     raw[t] == "fullraw" then
                    -- --fullraw option in mkvextract
                    tracks[t]:write(track.CodecPrivate)
                elseif raw[t] == nil then
                    -- no --raw/--fullraw option in mkvextract
                    write_codec_header(tracks[t], track.CodecPrivate)
                else
                    -- --raw option: nothing extra
                end
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
            if k == "Block" and tracks[t] ~= nil then
                io.stderr:write(
                    k                  ,"\t",
                    t        or "<nil>","\t",
                    timecode or "<nil>","\t",
                    pos      or "<nil>","\t",
                    size     or "<nil>","\n")
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
