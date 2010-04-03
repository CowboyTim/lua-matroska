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

local function nal_type(nal_abbr)
    return read_bits(nal_abbr, 5, 6), read_bits(nal_abbr, 0, 4)
end

function PlayC:write(_, nal_unit)
    --io.stderr:write(nal_unit)
    local i = 1

    -- determine main nal_unit_type
    local nal_ref_idc, nal_unit_type = nal_type(ord(substr(nal_unit, i, i)))
    i = i + 1

    if nal_unit_type == 14 or nal_unit_type == 20 then
        -- FIXME: parse svc_extensio and mvc_extension
        io.stderr:write("SVC/MVC not yet supported")

        -- both are 3 bytes wide though, we skip.
        i = i + 3
    end

    -- start decoding the rbsp data itself
    local profile_idc = ord(substr(nal_unit, i, i))
    i = i + 1
    local constaint_f = ord(substr(nal_unit, i, i))
    i = i + 1
    local level_idc   = ord(substr(nal_unit, i, i))

    io.stderr:write(
        "nal_ref_idc:\t",     nal_ref_idc   or "<nil>",
        "\tnal_unit_type:\t", nal_unit_type or "<nil>",
        "\tprofile_idc:\t",   profile_idc   or "<nil>",
        "\tconstaint_f:\t",   constaint_f   or "<nil>",
        "\tlevel_idc:\t",     level_idc     or "<nil>", "\n"
    )

end

function PlayC:new(data)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

return PlayC 
