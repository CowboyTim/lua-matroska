local PlayC = {}

local ord    = string.byte
local substr = string.sub
local round  = math.modf
local join   = table.concat
local push   = table.insert

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

local function get_bit(data, i, bit)
    if bit == 7 then
        i = i + 1
    end
    local byte = ord(data, i, i)
    return i, bit == 7 and 0 or bit + 1, ((byte%(2^bit) >= 2^(bit-1)) and 1) or 0
end

local function scaling_list(data, size)
end

local function nal_type(nal_abbr)
    return read_bits(nal_abbr, 5, 6), read_bits(nal_abbr, 0, 4)
end

local function dump_table(t)
    local p = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then
            v = '{'..dump_table(v)..'}'
        end
        push(p, k..":"..(v or nil))
    end
    return join(p, " ,")
end

local function decode_seq_parameter_set(nal_unit, i)

    local sps = {}
    sps.profile_idc, sps.constaint_f, sps.level_idc = ord(nal_unit, i, i+3)
    i, b, sps.id = get_ue_golomb(nal_unit, i+3, 0)


    if sps.profile_idc == 100 or
       sps.profile_idc == 110 or
       sps.profile_idc == 122 or
       sps.profile_idc == 244 or
       sps.profile_idc == 118 or
       sps.profile_idc ==  44 or
       sps.profile_idc ==  83 or
       sps.profile_idc ==  86 
    then
        i, b, sps.chroma_format_idc = get_ue_golomb(nal_unit, i, b)
        if sps.chroma_format_idc == 3 then
            i, b, sps.seperate_colour_plane_flag = get_bit(nal_unit, i, b)
        end
        i, b, sps.bit_depth_luma_minus8   = get_ue_golomb(nal_unit, i, b)
        i, b, sps.bit_depth_chroma_minus8 = get_ue_golomb(nal_unit, i, b)

        i, b, sps.qpprime_y_zero_transform_bypass_flag = get_bit(nal_unit, i, b)
        i, b, sps.seq_scaling_matrix_present_flag      = get_bit(nal_unit, i, b)
        if sps.seq_scaling_matrix_present_flag then
            sps.seq_scaling_list_present_flag = {}
            for i=0, sps.chroma_format_idc == 3 and 12 or 8 do
                i, b, sps.seq_scaling_list_present_flag[i] = get_bit(nal_unit, i, b)
                if sps.seq_scaling_list_present_flag[i] then
                    if i < 6 then
                        scaling_list(nal_unit, 16)
                    else
                        scaling_list(nal_unit, 64)
                    end
                end
            end
        end
    end
        
    i, b, sps.log2_max_frame_num_minus4 = get_ue_golomb(nal_unit, i, b)
    i, b, sps.pic_order_cnt_type        = get_ue_golomb(nal_unit, i, b)
    if      sps.pic_order_cnt_type == 0 then
        i, b, sps.log2_max_pic_order_cnt_lsb_minus4 = get_ue_golomb(nal_unit, i, b)
    elseif sps.pic_order_cnt_type == 1 then
        i, b, sps.log2_max_pic_order_cnt_lsb_minus4 = get_ue_golomb(nal_unit, i, b)
    end

    io.stderr:write("SPS:\t",dump_table(sps),"\n")


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
