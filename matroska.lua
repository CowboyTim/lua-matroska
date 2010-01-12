
local M = {}

-- add to GLOBAL
if _REQUIREDNAME == nil then
    matroska = M
else
    _G[_REQUIREDNAME] = M
end

require("pack")

local time     = os.time
local bunpack  = string.unpack
local sprintf  = string.format
local subst    = string.gsub
local ord      = string.byte
local char     = string.char
local strftime = os.date

-- common stuff
local start = time({year = 2001, month = 1, day = 1})

-- logging methods
local debugging = nil

local debug = function () end
if debugging ~= nil then
    local oldprint = print
    function print(...)
        return oldprint(time(), unpack(arg))
    end
    debug = print
end

local function hex(s)
    return subst(s,"(.)",function (x) return sprintf("%02X",ord(x)) end)
end

function M:ebml_parse_vint(fh, id)
    debug("reading from:",fh)
    local size = fh:read(1)
    debug(hex(size))
    local nrbytes
    size = ord(size)
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
    local s, vint
    if nrbytes ~= 0 then
        debug("reading from:",fh,',nrbytes:',nrbytes)
        vint = char(size)..fh:read(nrbytes)
    else
        vint = char(size)
    end
    for i=0,(7-#(vint)) do
        vint = '\000'..vint
    end
    s, vint  = bunpack(vint, '>Q')
    return vint
end

function M:ebml_parse_string(fh, size)
    return fh:read(size)
end

function M:ebml_parse_binary(fh, size)
    fh:seek("cur", size)
    return size
end

function M:ebml_parse_date(fh, size)
    local s, f = 1, fh:read(size)
    for i=0,(7-#(f)) do
        f = '\000'..f
    end
    debug('date:'..hex(f))
    s, f = bunpack(string.sub(f,1,4), '>l')

    -- FIXME: not possible within LUA I think. This is a 64-bit signed integer:
    --        nanoseconds since 2001-01-01T00:00:00,000000000 
    --        so, I use only the most 4 significant bytes, hence, I don't
    --        divide by 1000000000, but I also multiplicate with 4**32.

    return strftime("!%c", start + f*4.294967296)
end

local function ebml_parse_quad(fh, size, what)
    local s, f = 1, fh:read(size)
    for i=0,(3-#(f)) do
        f = '\000'..f
    end
    s, f = bunpack(f, what)
    return f
end

function M:ebml_parse_sub_elements(fh, size)
    return '<node>'
end

function M:ebml_parse_float (fh, size)
    return ebml_parse_quad(fh, size, '>f')
end

function M:ebml_parse_u_integer (fh, size)
    return ebml_parse_quad(fh, size, '>L')
end

function M:ebml_parse_s_integer (fh, size)
    return ebml_parse_quad(fh, size, '>l')
end

M.ebml_parse_utf_8            = M.ebml_parse_string
M.ebml_parse_u_integer_1_bit_ = M.ebml_parse_u_integer
M.ebml_parse_binary_see_      = M.ebml_parse_binary

-- add the other parser defs: after all the parser defs defined above always!
local leafs = require 'matroska_parser_def'

function M:iterator()
    return self.iterate, self
end

function M:info()
    self.fh:seek("set")
    return self:iterator()
end

function M:iterate()
    local fh = self.fh
    while fh:seek() < self.f_end  do
        local id   = M:ebml_parse_vint(fh, 1)
        local size = M:ebml_parse_vint(fh)
        id = sprintf('%X',id)
        local process_element = leafs[id]
        debug('id:',id,',size:',size)
        local a = process_element[1](self, fh, size)
        debug('id:',id,',size:',size,',offset:',fh:seek(),' --> ',a)
        return process_element[2], a
    end
    return nil
end

-- define the open: uses leafs as a closure
function M:open(file)
    local mkv = {}
    setmetatable(mkv, self)
    self.__index = self
    debug("opening file: ", file)
    local fh = assert(io.open(file, "r"))
    local f_end = fh:seek("end")
    mkv.f_end = f_end
    mkv.fh    = fh
    debug("f_end:", f_end)
    fh:seek("set")
    for w, r in mkv:iterator(mkv) do
        mkv[w] = r
        if w == 'Cluster' then
            break
        end
    end
    return mkv
end

function M:close()
    return self.fh:close()
end

return matroska
