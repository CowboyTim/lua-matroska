

local PlayC = {}

local bit = require("bit")

local ord    = string.byte
local substr = string.sub
local round  = math.modf
local ceil   = math.ceil
local join   = table.concat
local push   = table.insert

local get_golomb = bit.get_golomb
local get_ue_golomb = get_golomb

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

local function get_se_golomb(data, i, b)
    io.stderr:write("get_se_golomb:i:"..i..",b:"..b.."\n")
    local i, b, v = get_golomb(data, i, b)
    return i, b, -1^(v+1)* ceil(v/2)
end

local function get_bit(data, i, bit, nrbits)
    if bit == 7 then
        i = i + 1
    end
    local byte = ord(data, i, i)
    return i, bit == 7 and 0 or bit + 1, ((byte%(2^bit) >= 2^(bit-1)) and 1) or 0
end

local function scaling_list(data, i, b, size)
    local lastscale, nextscale, sl, defaultscalematrixflag = 8, 8, {}, 0
    local deltascale
    for j=1, size do
        if nextscale then
            i, b, deltascale = get_se_golomb(data, i, b)
            nextscale = (lastscale + deltascale + 256) % 256
            defaultscalematrixflag = (j == 1 and nextscale == 0) or 0
        end
        lastscale = nextscale or lastscale and nextscale
        sl[j] = lastscale
    end
    return i, b, sl, defaultscalematrixflag
end

local function hrd_parameters(data, i, b)
    local hrd = {}

    i, b, hrd.cpb_cnt_minus1 = get_ue_golomb(data, i, b)
    i, b, hrd.bit_rate_scale = get_bit(data, i, b, 4)
    i, b, hrd.cpb_size_scale = get_bit(data, i, b, 4)
    hrd,bit_rate_value_minus1 = {}
    hrd,cpb_size_value_minus1 = {}
    hrd,cpb_flag              = {}
    for j=1,hrd.cpb_cnt_minus1+1 do
        i, b, hrd.bit_rate_value_minus1[j] = get_ue_golomb(data, i, b)
        i, b, hrd.cpb_size_value_minus1[j] = get_ue_golomb(data, i, b)
        i, b, hrd.cpb_flag[j]              = get_bit(data, i, b)
    end
    i, b, hrd.initial_cpb_removal_delay_length = get_bit(data, i, b, 5)
    i, b, hrd.cpb_removal_delay_length_minus1  = get_bit(data, i, b, 5)
    i, b, hrd.dpb_output_delay_length_minus1   = get_bit(data, i, b, 5)
    i, b, hrd.time_offset_length               = get_bit(data, i, b, 5)

    return i, b, hrd
end

local function vui_parameters(data, i, b)
    local vui = {}

    i, b, vui.aspect_ratio_info_present_flag = get_bit(data, i, b)
    if vui.aspect_ratio_info_present_flag then
        i, b, vui.aspect_ratio_idc = get_bit(data, i, b, 8)
        if vui.aspect_ratio_idc then
            vui.sar_width  = get_bit(data, i, b, 16)
            vui.sar_height = get_bit(data, i, b, 16)
        end
    end

    i, b, vui.overscan_info_present_flag = get_bit(data, i, b)
    if vui.overscan_info_present_flag then
        i, b, vui.overscan_appropriate_flag = get_bit(data, i, b)
    end

    i, b, vui.video_signal_type_present_flag = get_bit(data, i, b)
    if vui.video_signal_type_present_flag then
        i, b, vui.video_format                    = get_bit(data, i, b, 3)
        i, b, vui.video_full_range_flag           = get_bit(data, i, b)
        i, b, vui.colour_description_present_flag = get_bit(data, i, b)
        if vui.colour_description_present_flag then
            i, b, vui.colour_primaries         = get_bit(data, i, b, 8)
            i, b, vui.transfer_characteristics = get_bit(data, i, b, 8)
            i, b, vui.matrix_coefficients      = get_bit(data, i, b, 8)
        end
    end

    i, b, vui.chroma_location_info_present_flag = get_bit(data, i, b)
    if vui.chroma_location_info_present_flag then
        i, b, vui.chroma_sample_loc_type_top_field    = get_ue_golomb(data, i, b)
        i, b, vui.chroma_sample_loc_type_bottom_field = get_ue_golomb(data, i, b)
    end

    i, b, vui.timing_info_present_flag = get_bit(data, i, b)
    if vui.timing_info_present_flag then
        i, b, vui.num_units_in_tick     = get_bit(data, i, b, 32)
        i, b, vui.time_scale            = get_bit(data, i, b, 32)
        i, b, vui.fixed_frame_rate_flag = get_bit(data, i, b)
    end

    i, b, vui.nal_hrd_parameters_present_flag = get_bit(data, i, b)
    if vui.nal_hrd_parameters_present_flag then
        i, b, vui.nal_hrd_parameters = hrd_parameters(data, i, b)
    end
    i, b, vui.vcl_hrd_parameters_present_flag = get_bit(data, i, b)
    if vui.vcl_hrd_parameters_present_flag then
        i, b, vui.vcl_hrd_parameters = hrd_parameters(data, i, b)
    end
    if     vui.vcl_hrd_parameters_present_flag
        or vui.nal_hrd_parameters_present_flag then
        i, b, vui.low_delay_hrd_flag = get_bit(data, i, b)
    end

    i, b, vui.pic_struct_present_flag    = get_bit(data, i, b)
    i, b, vui.bitstream_restriction_flag = get_bit(data, i, b)
    if vui.bitstream_restriction_flag then
        i, b, vui.motion_vectors_over_pic_boundaries_flag = get_bit(data, i, b)
        i, b, vui.max_bytes_per_pic_denom                 = get_bit(data, i, b)
        i, b, vui.max_bits_per_mb_denom                   = get_bit(data, i, b)
        i, b, vui.log2_max_mv_length_horizontal           = get_bit(data, i, b)
        i, b, vui.log2_max_mv_length_vertical             = get_bit(data, i, b)
        i, b, vui.num_reorder_frames                      = get_bit(data, i, b)
        i, b, vui.max_dec_frame_buffering                 = get_bit(data, i, b)
    end

    return i, b, vui
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
        push(p, k..":"..(v or "<nil>"))
    end
    return join(p, " ,")
end

local function decode_seq_parameter_set(nal_unit, i)

    local sps = {}
    sps.profile_idc, sps.constaint_f, sps.level_idc = ord(nal_unit, i, i+2)
    i, b, sps.sps_id = get_ue_golomb(nal_unit, i+3, 0)

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
                    if j < 7 then   -- LUA array 1, see for j=1
                        sps.scalinglist4x4 = sps.scalinglist4x4 or {}
                        sps.defscaling4x4  = sps.defscaling4x4  or {}
                        i, b, sps.scalinglist4x4[j],   sps.defscaling4x4[j]
                            = scaling_list(nal_unit, i, b, 16)
                    else
                        sps.scalinglist8x8 = sps.scalinglist8x8 or {}
                        sps.defscaling8x8  = sps.defscaling8x8  or {}
                        i, b, sps.scalinglist8x8[j-7], sps.defscaling8x8[j-7] 
                            = scaling_list(nal_unit, i, b, 64)
                    end
                end
            end
        else
            sps.chroma_format_idc       = 1
            sps.bit_depth_luma_minus8   = 0
            sps.bit_depth_chroma_minus8 = 0
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
