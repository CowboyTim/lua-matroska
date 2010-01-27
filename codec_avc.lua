local C = {}

require("pack")
local bunpack  = string.unpack

local substr   = string.sub
local ord      = string.byte
local stringx  = string.rep
local subst    = string.gsub
local sprintf  = string.format

local bunpack = function(str, format)
    local i = 4
    local f = substr(format, 2, 2)
    if f == "Q" or f == "q" then
        i = 8
    end
    local s, v = bunpack(stringx("\000", i-#(str))..str, format)
    return tonumber(v)
end

local function hex(s)
    return subst(s,"(.)",function (x) return sprintf("%02X",ord(x)) end)
end

local function write_nal(fh, data, where, size_size)
    io.stderr:write(hex(data),"\n")
    local start     = where + size_size
    local size_end  = bunpack(substr(data,where,start-1),">L")
    io.stderr:write("write_nal, start:\t",start, "\tend:",size_end,"\tsize_size:",size_size,"\n")
    if size_end > 0 then
        size_end = start + size_end - 1
        io.stderr:write("write_in_nal\n")
        fh:write('\000\000\000\001')
        fh:write(substr(data,start,size_end))
        return size_end + 2
    else
        return start + size_end + 1
    end
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

function C:close()
    return self.fh:close()
end

function C:write(data)
    local pos = 1
    while #data > pos do
        pos = write_nal(self.fh, data, pos, self.nal_size_size)
    end
end

function C:new(fh, data)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    local nal_size_size = 1 
    local buf = ord(substr(data, 5,5))
    if testbit_1(nal_size_size) then
        nal_size_size = nal_size_size + 2
    end
    if testbit_0(nal_size_size) then
        nal_size_size = nal_size_size + 1
    end
    io.stderr:write("data\t",#data,"\tnal_size_size:\t",nal_size_size, "\n")

    o.fh = fh
    o.nal_size_size = nal_size_size

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
        numpps = write_nal(fh,data,numpps,2)
    end
    numpps = ord(substr(data,numpps,numpps))
    if numpps == nil then
        return o
    end
    for i=1,numpps do
        write_nal(fh,data,6,2)
    end

    return o
end

return C 
