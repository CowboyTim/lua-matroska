
local M = {}

require("pack")

local bpack   = string.pack
local bunpack = string.unpack
local sprintf = string.format

local function hex(s)
    return string.gsub(s,"(.)",function (x) return sprintf("%02X",string.byte(x)) end)
end

function M:ebml_parse_vint(fh, id)
    --print("reading from:"..fh:seek())
    local byte = fh:read(1)
    --print(hex(byte))
    local s, size, nrbytes, vint
    s, size = bunpack(byte, '>b')
    if     size > 127 then
        if not id then
            size = size - 128
        end
        nrbytes = 0
    elseif size > 63 then
        if not id then
            size = size - 64
        end
        nrbytes = 1
    elseif size > 31 then
        if not id then
            size = size - 32
        end
        nrbytes = 2
    elseif size > 15 then
        if not id then
            size = size - 16
        end
        nrbytes = 3
    elseif size > 7  then
        if not id then
            size = size - 8
        end
        nrbytes = 4
    elseif size > 3  then
        if not id then
            size = size - 4
        end
        nrbytes = 5
    elseif size > 1  then
        if not id then
            size = size - 2
        end
        nrbytes = 6
    elseif size > 0  then
        if not id then
            size = size - 1
        end
        nrbytes = 7
    else 
        nrbytes = 8
    end
    if nrbytes ~= 0 then
        --print("reading from:"..fh:seek()..',nrbytes:'..nrbytes)
        s, vint  = bunpack(fh:read(nrbytes), 'A'..nrbytes)
        vint = bpack('b', size)..vint
    else
        vint = bpack('b', size)
    end
    for i=0,(7-#(vint)) do
        vint = '\000'..vint
    end
    s, vint  = bunpack(vint, '>J')
    return vint
end

local master = {
    ["18538067"] = 1,
    ["285"]      = 1,
    ["1549A966"] = 1,
    ["114D9B74"] = 1,
    ["1F43B675"] = 1,
    ["1654AE6B"] = 1,
    ["1C53BB6B"] = 1,
    ["1941A469"] = 1,
    ["1043A770"] = 1,
    ["1254C367"] = 1,
    ["4DBB"]     = 1,
    ["AE"]       = 1,
    ["E0"]       = 1,
    ["E1"]       = 1,
    ["6D80"]     = 1,
    ["6240"]     = 1,
    ["A0"]       = 1,
    ["BB"]       = 1,
    ["B7"]       = 1,
    ["45B9"]     = 1,
    ["B6"]       = 1,
    ["8F"]       = 1,
    ["80"]       = 1,
    ["61A7"]     = 1,
    ["7373"]     = 1,
    ["63C0"]     = 1,
    ["67C8"]     = 1,
}

function M:open(file)
    print("opening file: "..file)
    -- read until 0x1A, that can be ignored, strip 0x1A too
    local fh = assert(io.open(file, "r"))
    local f_end = fh:seek("end")
    print("f_end:"..f_end)
    fh:seek("set")
    while fh:seek() < f_end  do
        local id   = M:ebml_parse_vint(fh, 1)
        local size = M:ebml_parse_vint(fh)
        id = sprintf('%X',id)
        print('id:'..id)
        print('size:'..size)
        if not master[id] then
            --print('seek to:'..fh:seek()+size)
            fh:seek("cur",size)
        end
    end
    fh:close()
    local mkv = {}
    setmetatable(mkv, self)
    self.__index = self
    return mkv
end


if _REQUIREDNAME == nil then
    matroska = M
else
    _G[_REQUIREDNAME] = M
end


return matroska
