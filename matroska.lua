
local M = {}

-- add to GLOBAL, else the require of matroska_parser_def.lua won't work
if _REQUIREDNAME == nil then
    _REQUIREDNAME = "matroska"
end
_G[_REQUIREDNAME] = M

require("pack")

local time     = os.time
local bunpack  = string.unpack
local sprintf  = string.format
local subst    = string.gsub
local ord      = string.byte
local char     = string.char
local strftime = os.date
local substr   = string.sub
local stringx  = string.rep
local push     = table.insert
local pop      = table.remove
local join     = table.concat
local match    = string.match

-- common stuff
local start = time({year = 2001, month = 1, day = 1})

-- logging methods
local debugging = 1

local debug = function () end
if debugging ~= nil then
    io.stderr:setvbuf("line")
    local oldprint = print
    function print(...)
        local va = {}
        for _,v in ipairs(arg) do
            push(va, "\t")
            push(va, tostring(v)) 
        end
        push(va, "\n")
        return io.stderr:write(time(), unpack(va))
    end
    debug = print
end

local function hex(s)
    return subst(s,"(.)",function (x) return sprintf("%02X",ord(x)) end)
end

local bunpack = function(str, format)
    local i = 4
    local f = substr(format, 2, 2)
    if f == "Q" or f == "q" then
        i = 8
    end
    local s, v = bunpack(stringx("\000", i-#(str))..str, format)
    return tonumber(v)
end

local function ebml_parse_vint(fh, id)
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
    local vint
    if nrbytes ~= 0 then
        debug("reading from:",fh,",nrbytes:",nrbytes)
        vint = char(size)..fh:read(nrbytes)
    else
        vint = char(size)
    end
    return bunpack(vint, ">Q")
end

local function bit(p)
    return 2 ^ (p - 1) -- 1-based indexing end 
end
local function testflag(b, flag)
    return b % (2*flag) >= flag
end

local function testbit_3(s)
    return s % 8 >= 4
end

local function testbit_2(s)
    return s % 4 >= 2
end

--[[
    
    different type element parser functions

--]]


function M:ebml_parse_string(fh, size)
    return fh:read(size)
end

function M:ebml_parse_binary(fh, size)
    --[[

    According the specs:
        * Bit 0 is the most significant bit.
        *
            Header:
            0x00+	must	Track Number (Track Entry). It is coded in EBML
                            like form (1 octet if the value is < 0x80, 2 if
                             < 0x4000, etc) (most significant bits set to 
                            increase the range).  0x01+	must	Timecode 
                            (relative to Cluster timecode, signed int16) 

            0x01+	must	Timecode (relative to Cluster timecode, signed 
                            int16)

            0x03+	-       0-3   - Reserved, set to 0
                            4     - Invisible, the codec should decode this
                                    frame but not display it
                            5-6   m Lacing:
                                        - 00: no lacing
                                        - 01: Xiph lacing
                                        - 11: EBML lacing
                                        - 10: fixed-size lacing
                            7     - not used
                            5     - Reserverd, set to 0
                            4-0   - Priority
            If Lacing:
            0x00    must    Nr of frames in lace-1

        TODO: only no lacing and fixed size lacing are implemented now

    --]]
    local start_f  = fh:seek()
    debug("reading binary from",start_f)
    
    -- tracknr/timecode/flags
    local tracknr  = ebml_parse_vint(fh, nil)
    local timecode = bunpack(fh:read(2), ">q")
    local flags    = ord(fh:read(1))

    -- what lacing?
    local lacing   = 0 
    local nrlaces  = 0 
    if testbit_3(flags) then
        lacing = 2
    end
    if testbit_2(flags) then
        lacing = lacing + 1
    end
    if     lacing == 0 then
        -- no lacing: nothing, perhaps nrlaces =1?
    elseif lacing == 1 then
        -- Xiph lacing: TODO
    elseif lacing == 2 then
        -- fixed-sized lacing
        nrlaces = ord(fh:read(1))
    elseif lacing == 3 then
        -- EBML lacing
        nrlaces = ord(fh:read(1))
        --for i=1,nrlaces do
            --ebml_parse_vint(fh, nil)
        --end
    end
    debug("size"    , size,
          "tracknr" , tracknr,
          "timecode", timecode,
          "flags"   , flags,
          "lacing"  , lacing,
          "nrlaces" , nrlaces)
    local cur = fh:seek()
    fh:seek("set", start_f + size)
    return tracknr, timecode, cur, (size - (cur - start_f))
end

function M:ebml_parse_date(fh, size)
    local f = bunpack(string.sub(fh:read(size),1,4), ">l")

    --[[
    FIXME: not possible within LUA I think. This is a 64-bit signed integer:
           nanoseconds since 2001-01-01T00:00:00,000000000 
           so, I use only the most 4 significant bytes, hence, I don't
           divide by 1000000000, but I also multiplicate with 4**32.
    --]]

    return strftime("!%c", start + f*4.294967296)
end

function M:ebml_parse_sub_elements(fh, size)
    return nil
end

function M:ebml_parse_float(fh, size)
    return bunpack(fh:read(size), ">f")
end

function M:ebml_parse_u_integer(fh, size)
    return bunpack(fh:read(size), ">Q")
end

function M:ebml_parse_s_integer(fh, size)
    return bunpack(fh:read(size), ">q")
end

M.ebml_parse_utf_8            = M.ebml_parse_string
M.ebml_parse_u_integer_1_bit_ = M.ebml_parse_u_integer
M.ebml_parse_binary_see_      = M.ebml_parse_binary

function M:ebml_parse_SeekID(fh, size)
    return M.leafs[sprintf("%X",ebml_parse_vint(fh, 1))][2]
end

--[[

    parser definition: ID to function mapping

--]]

-- add the other parser defs: after all the parser defs defined above always!
M.leafs = require "matroska_parser_def"

-- SeekID is special, override it.
M.leafs["53AB"][1] = M.ebml_parse_SeekID

--[[

    parser API

--]]

function M:iterator()
    return self.iterate, self
end

function M:info()
    self:reset()
    return self:iterator()
end

function M:iterate()
    local fh = self.fh
    while fh:seek() < self.f_end  do
        local id   = ebml_parse_vint(fh, 1)
        local size = ebml_parse_vint(fh)
        id = sprintf("%X",id)
        local process_element = M.leafs[id]
        debug("id:",id,",size:",size)
        local a,b,c,d = process_element[1](self, fh, size)
        debug("id:",id,",size:",size,",offset:",fh:seek()," --> ",a,b,c,d)
        return process_element[2], process_element[3], a,b,c,d
    end
    return nil
end

local element_array = { TrackEntry = 0, Seek = 0 }

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
    local header    = {}
    local stack     = {}
    local lastlevel = 0
    for w, l, r in mkv:iterator() do
        if l < lastlevel then
            for i=l+1,lastlevel do
                pop(stack)
            end
        end
        if r == nil then
            if element_array[w] ~= nil then
                element_array[w] = element_array[w] + 1
                w = w.."/"..element_array[w]
            end
            push(stack, w)
        else
            header[join(stack, "/").."/"..w] = r
        end
        lastlevel = l
        if w == "Cluster" then
            break
        end
    end

    mkv.header = header
    return mkv
end

function M:grepinfo(what)
    return function (h, k)
        local v, m
        while 1 do
            k,v = next(h, k)
            if k == nil then
                return nil
            end
            if what ~= nil then
                m = {match(k, what)}
                if #m > 0 then
                    return k,v,unpack(m)
                end
            else
                return k,v
            end
        end
    end, self.header
end

function M:multi(what)
    local multi = {}
    for _,v,m,k in self:grepinfo(what.."/(%d)/(.*)") do
        if multi[m] == nil then
            multi[m] = {}
        end
        multi[m][k] = v
    end
    return multi
end

function M:tracks(what)
    return self:multi("Segment/Tracks/TrackEntry")
end

function M:close()
    return self.fh:close()
end

function M:reset()
    return self.fh:seek("set")
end

function M:read(pos, size)
    self.fh:seek("set", pos)
    return self.fh:read(size)
end

return M
