local PlayC = {}

local ord    = string.byte
local substr = string.sub
local round  = math.modf

local get_golomb = require("golomb")

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

local get_ue_golomb = get_golomb

local function nal_type(nal_abbr)
    return read_bits(nal_abbr, 5, 6), read_bits(nal_abbr, 0, 4)
end

local function decode_seq_parameter_set(nal_unit, i)

    local sps = {}
    sps.profile_idc, sps.constaint_f, sps.level_idc = ord(nal_unit, i, i+3)
    i, b, sps.id = get_ue_golomb(nal_unit, i+3, 0)

    io.stderr:write(
        "profile_idc:\t",   sps.profile_idc or "<nil>",
        "\tconstaint_f:\t", sps.constaint_f or "<nil>",
        "\tlevel_idc:\t",   sps.level_idc   or "<nil>",
        "\tsps_id:\t",      sps.id          or "<nil>",
        "\ti:\t",           i, "\n"
    )


    -- FIXME: implement further
    
    return i, sps
end

function PlayC:write(_, nal_unit)
    --io.stderr:write(nal_unit)
    local i = 1

    -- determine main nal_unit_type
    local nal_ref_idc, nal_unit_type = nal_type(ord(substr(nal_unit, i, i)))
    i = i + 1
    io.stderr:write(
        "nal_ref_idc:\t",     nal_ref_idc   or "<nil>",
        "\tnal_unit_type:\t", nal_unit_type or "<nil>", "\n"
    )

    if nal_unit_type == 14 or nal_unit_type == 20 then
        -- FIXME: parse svc_extension and mvc_extension
        io.stderr:write("SVC/MVC not yet supported")

        -- both are 3 bytes wide though, we skip.
        i = i + 3
    end

    -- start decoding the rbsp data itself
    if nal_unit_type == 7 then
        i, self.sps = decode_seq_parameter_set(nal_unit, i)
    end

end

function PlayC:new(data)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

return PlayC 
