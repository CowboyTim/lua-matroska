local PlayC = {}

local ord    = string.byte
local substr = string.sub
local round  = math.modf

local function read_bits(byte, from, to)
    local s = 0
    for i=from,to do
        local b = 2^i
        --s = ((byte%(b*2) >= b) and s + b) or s
        if byte%(b*2) >= b then
            s = s + b
        end
    end
    s, _ = round(s/(2^from))
    return s
end

local function nal_type(nal_unit)
    local nal_abbr = ord(substr(nal_unit, 1, 1))
    return read_bits(nal_abbr, 5, 6), read_bits(nal_abbr, 0, 4)
end

function PlayC:write(_, nal_unit)
    --io.stderr:write(nal_unit)
    local nal_ref_idc, nal_unit_type = nal_type(nal_unit)

    io.stderr:write(
        "nal_ref_idc:\t",     nal_ref_idc   or "<nil>",
        "\tnal_unit_type:\t", nal_unit_type or "<nil>", "\n"
    )
end

function PlayC:new(data)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

return PlayC 
