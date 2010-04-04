local PlayC = {}

local ord    = string.byte
local substr = string.sub
local round  = math.modf
local ceil   = math.ceil
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

local function get_se_golomb(data, i, b)
    io.stderr:write("get_se_golomb:i:"..i..",b:"..b.."\n")
    local i, b, v = get_golomb(data, i, b)
    return i, b, -1^(v+1)* ceil(v/2)
end

local function get_bit(data, i, bit)
    if bit == 7 then
        i = i + 1
    end
    local byte = ord(data, i, i)
    return i, bit == 7 and 0 or bit + 1, ((byte%(2^bit) >= 2^(bit-1)) and 1) or 0
end

local function scaling_list(data, i, b, size)
    io.stderr:write("scalinglist, i:"..i)
    local lastscale, nextscale, sl = 8, 8, {}
    local deltascale, defaultscalematrixflag
    for j=1, size do
        if nextscale then
            i, b, deltascale = get_se_golomb(data, i, b)
            nextscale = (lastscale + deltascale + 256) % 256
            defaultscalematrixflag = j == 1 and nextscale == 0
        end
        lastscale = nextscale or lastscale and nextscale
        sl[j] = lastscale
    end
    return i, b, sl, defaultscalematrixflag
end

local function vui_parameters(data, size)
    -- FIXME
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
    i, b, sps.id = get_ue_golomb(nal_unit, i+4, 0)

    io.stderr:write("SPS:\t",dump_table(sps),"\n")

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
            for j=1, (sps.chroma_format_idc == 3 and 12 or 8) do
                i, b, sps.seq_scaling_list_present_flag[j] = get_bit(nal_unit, i, b)
                if sps.seq_scaling_list_present_flag[j] then
                    sps.scalinglist = {}
                    sps.defscaling  = {}
                    if j < 7 then   -- LUA array 1, see for j=1
                        i, b, sps.scalinglist[j],   sps.defscaling[j]
                            = scaling_list(nal_unit, i, b, 16)
                    else
                        i, b, sps.scalinglist[j-7], sps.defscaling[j-7] 
                            = scaling_list(nal_unit, i, b, 64)
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
        i, b, sps.delta_pic_always_zero_flag     = get_bit(nal_unit, i, b)
        i, b, sps.offset_for_non_ref_pic         = get_se_golomb(nal_unit, i, b)
        i, b, sps.offset_for_top_to_bottom_field = get_se_golomb(nal_unit, i, b)
        i, b, sps.num_ref_frames_in_pic_order_cnt_cycle
                                                 = get_ue_golomb(nal_unit, i, b)
        sps.offset_for_ref_frame = {}
        for i=1,sps.num_ref_frames_in_pic_order_cnt_cycle do
            sps.offset_for_ref_frame[i] = get_se_golomb(nal_unit, i, b)
        end
    end

    i, b, sps.max_num_ref_frames                   = get_ue_golomb(nal_unit, i, b)
    i, b, sps.gaps_in_frame_num_value_allowed_flag = get_bit(nal_unit, i, b)
    i, b, sps.pic_width_in_mbs_minus1              = get_ue_golomb(nal_unit, i, b)
    i, b, sps.pic_height_in_map_units_minus1       = get_ue_golomb(nal_unit, i, b)
    i, b, sps.frame_mbs_only_flag                  = get_bit(nal_unit, i, b)
    if not sps.frame_mbs_only_flag then
        i, b, sps.mb_adaptive_frame_field_flag     = get_bit(nal_unit, i, b)
    end
    i, b, sps.direct_8x8_interference_flag         = get_bit(nal_unit, i, b)
    i, b, sps.frame_cropping_flag                  = get_bit(nal_unit, i, b)
    if sps.frame_cropping_flag then
        i, b, sps.frame_crop_left_offset           = get_ue_golomb(nal_unit, i, b)
        i, b, sps.frame_crop_right_offset          = get_ue_golomb(nal_unit, i, b)
        i, b, sps.frame_crop_top_offset            = get_ue_golomb(nal_unit, i, b)
        i, b, sps.frame_crop_bottom_offset         = get_ue_golomb(nal_unit, i, b)
    end
    i, b, sps.vui_parameters_present_flag          = get_bit(nal_unit, i, b)
    if sps.vui_parameters_present_flag then
        i, b, sps.vui_parameters = vui_parameters(nal_unit, i, b)
    end

    io.stderr:write("SPS:\t",dump_table(sps),"\n")

    -- FIXME: implement further
    
    return i, sps
end

function PlayC:write(_, nal_unit)
    io.stderr:write("NAL data length:"..#(nal_unit).."\n")
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
