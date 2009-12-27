
local M = {}

require("pack")

local bpack   = string.pack
local bunpack = string.unpack
local sprintf = string.format

local function hex(s)
    return string.gsub(s,"(.)",function (x) return sprintf("%02X",string.byte(x)) end)
end

function M:ebml_parse_leaf(fh, size)
    --print('seek to:'..fh:seek()+size)
    return fh:read(size)
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

local function ebml_parse_string(fh, size)
    return fh:read(size)
end

local function ebml_void(fh, size)
    return fh:seek("cur", size)
end

local function ebml_parse_uint(fh, size)
    local s, uint = 1, fh:read(size)
    for i=0,(3-#(uint)) do
        uint = '\000'..uint
    end
    s, uint = bunpack(uint, '>L')
    return uint
end

local function ebml_parse_float(fh, size)
    local s, f = 1, fh:read(size)
    for i=0,(3-#(f)) do
        f = '\000'..f
    end
    s, f = bunpack(f, '>f')
    return f
end


local leafs = {
    ["EC"]     = ebml_void,
    ["4286"]   = ebml_parse_uint,
    ["42F7"]   = ebml_parse_uint,
    ["42F2"]   = ebml_parse_uint,
    ["42F3"]   = ebml_parse_uint,
    ["4282"]   = ebml_parse_string,
    ["4287"]   = ebml_parse_uint,
    ["4285"]   = ebml_parse_uint,
    ["73A4"]   = ebml_parse_string,
    ["7384"]   = ebml_parse_string,
    ["3CB923"] = ebml_parse_string,
    ["3C83AB"] = ebml_parse_string,
    ["3EB923"] = ebml_parse_string,
    ["3E83BB"] = ebml_parse_string,
    ["2AD7B1"] = ebml_parse_uint,
    ["4489"]   = ebml_parse_float,
    ["7BA9"]   = ebml_parse_string,
    ["4D80"]   = ebml_parse_string,
    ["5741"]   = ebml_parse_string,
    ["4461"]   = ebml_parse_uint,
    ["53AB"]   = ebml_parse_uint,
    ["53AC"]   = ebml_parse_uint,
    ["D7"]     = ebml_parse_uint,
    ["73C5"]   = ebml_parse_uint,
    ["83"]     = ebml_parse_uint,
    ["B9"]     = ebml_parse_uint,
    ["88"]     = ebml_parse_uint,
    ["55AA"]   = ebml_parse_uint,
    ["9C"]     = ebml_parse_uint,
    ["6DE7"]   = ebml_parse_uint,
    ["6DF8"]   = ebml_parse_uint,
    ["23E383"] = ebml_parse_uint,
    ["23314F"] = ebml_parse_float,
    ["536E"]   = ebml_parse_string,
    ["22B59C"] = ebml_parse_string,
    ["86"]     = ebml_parse_string,
    ["63A2"]   = ebml_parse_string,
    ["258688"] = ebml_parse_string,
    ["7446"]   = ebml_parse_uint,
    ["B0"]     = ebml_parse_uint,
    ["BA"]     = ebml_parse_uint,
    ["54AA"]   = ebml_parse_uint,
    ["54BB"]   = ebml_parse_uint,
    ["54CC"]   = ebml_parse_uint,
    ["54DD"]   = ebml_parse_uint,
    ["54B0"]   = ebml_parse_uint,
    ["54BA"]   = ebml_parse_uint,
    ["54B2"]   = ebml_parse_uint,
    ["B5"]     = ebml_parse_uint,
    ["78B5"]   = ebml_parse_uint,
    ["9F"]     = ebml_parse_uint,
    ["6264"]   = ebml_parse_uint,
    ["5031"]   = ebml_parse_uint,
    ["5032"]   = ebml_parse_uint,
    ["5033"]   = ebml_parse_uint,
    ["4254"]   = ebml_parse_uint,
    ["4255"]   = ebml_parse_string,
    ["E7"]     = ebml_parse_uint,
    ["A7"]     = ebml_parse_uint,
    ["AB"]     = ebml_parse_uint,
    ["A3"]     = ebml_parse_string,
    ["A1"]     = ebml_parse_string,
    ["FB"]     = ebml_parse_uint,
    ["9B"]     = ebml_parse_uint,
    ["B3"]     = ebml_parse_uint,
    ["F7"]     = ebml_parse_uint,
    ["F1"]     = ebml_parse_uint,
    ["5378"]   = ebml_parse_uint,
    ["45BC"]   = ebml_parse_uint,
    ["45BD"]   = ebml_parse_uint,
    ["45DB"]   = ebml_parse_uint,
    ["45DD"]   = ebml_parse_uint,
    ["73C4"]   = ebml_parse_uint,
    ["91"]     = ebml_parse_uint,
    ["92"]     = ebml_parse_uint,
    ["98"]     = ebml_parse_uint,
    ["4598"]   = ebml_parse_uint,
    ["6E67"]   = ebml_parse_string,
    ["6EBC"]   = ebml_parse_uint,
    ["8F"]     = ebml_parse_uint,
    ["89"]     = ebml_parse_uint,
    ["85"]     = ebml_parse_string,
    ["437C"]   = ebml_parse_string,
    ["437E"]   = ebml_parse_string,
    ["467E"]   = ebml_parse_string,
    ["466E"]   = ebml_parse_string,
    ["4660"]   = ebml_parse_string,
    ["465C"]   = ebml_parse_string,
    ["46AE"]   = ebml_parse_uint,
    ["68CA"]   = ebml_parse_uint,
    ["63CA"]   = ebml_parse_string,
    ["63C5"]   = ebml_parse_uint,
    ["63C9"]   = ebml_parse_uint,
    ["63C4"]   = ebml_parse_uint,
    ["63C6"]   = ebml_parse_uint,
    ["45A3"]   = ebml_parse_string,
    ["447A"]   = ebml_parse_string,
    ["4484"]   = ebml_parse_uint,
    ["4487"]   = ebml_parse_string,
    ["4485"]   = ebml_parse_string,
    ["55EE"]   = ebml_parse_uint,
    ["AA"]     = ebml_parse_uint,
}

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
    local id   = M:ebml_parse_vint(fh, 1)
    local size = M:ebml_parse_vint(fh)
    id = sprintf('%X',id)
    print('id:'..id..',size:'..size)
    while fh:seek() < f_end  do
        local id   = M:ebml_parse_vint(fh, 1)
        local size = M:ebml_parse_vint(fh)
        id = sprintf('%X',id)
        print('id:'..id..',size:'..size)
        if not master[id] then
            print('id:'..id..',size:'..size..',offset:'..fh:seek()..' --> '..(leafs[id](fh, size) or ''))
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
