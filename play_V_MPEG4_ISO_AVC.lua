

local PlayC = {}

local bit = require("bit")

local ord    = string.byte
local substr = string.sub
local round  = math.modf
local join   = table.concat
local push   = table.insert

local get_golomb    = bit.get_golomb
local get_ue_golomb = bit.get_ue_golomb
local get_se_golomb = bit.get_se_golomb
local get_bit       = bit.get_bit
local read_bits     = bit.read_bits

local function scaling_list(s, size)
    local lastscale, nextscale, sl, defaultscalematrixflag = 8, 8, {}, 0
    local deltascale
    for j=1, size do
        if nextscale then
            deltascale = get_se_golomb(s)
            nextscale = (lastscale + deltascale + 256) % 256
            defaultscalematrixflag = (j == 1 and nextscale == 0) or 0
        end
        lastscale = nextscale or lastscale and nextscale
        sl[j] = lastscale
    end
    return sl, defaultscalematrixflag
end

local function hrd_parameters(s)
    local hrd = {}

    hrd.cpb_cnt_minus1 = get_ue_golomb(s)
    hrd.bit_rate_scale = read_bits(s,4)
    hrd.cpb_size_scale = read_bits(s,4)
    hrd.bit_rate_value_minus1 = {}
    hrd.cpb_size_value_minus1 = {}
    hrd.cpb_flag              = {}
    for j=1,hrd.cpb_cnt_minus1+1 do
        hrd.bit_rate_value_minus1[j] = get_ue_golomb(s)
        hrd.cpb_size_value_minus1[j] = get_ue_golomb(s)
        hrd.cpb_flag[j]              = get_bit(s)
    end
    hrd.initial_cpb_removal_delay_length = read_bit(s,5)
    hrd.cpb_removal_delay_length_minus1  = read_bit(s,5)
    hrd.dpb_output_delay_length_minus1   = read_bit(s,5)
    hrd.time_offset_length               = read_bit(s,5)

    return hrd
end

local function vui_parameters(s)
    local vui = {}

    vui.aspect_ratio_info_present_flag = get_bit(s)
    if vui.aspect_ratio_info_present_flag then
        vui.aspect_ratio_idc = read_bits(s,8)
        if vui.aspect_ratio_idc then
            vui.sar_width  = read_bits(s,16)
            vui.sar_height = read_bits(s,16)
        end
    end

    vui.overscan_info_present_flag = get_bit(s)
    if vui.overscan_info_present_flag then
        vui.overscan_appropriate_flag = get_bit(s)
    end

    vui.video_signal_type_present_flag = get_bit(s)
    if vui.video_signal_type_present_flag then
        vui.video_format                    = read_bits(3)
        vui.video_full_range_flag           = get_bit(s)
        vui.colour_description_present_flag = get_bit(s)
        if vui.colour_description_present_flag then
            vui.colour_primaries         = read_bits(s,8)
            vui.transfer_characteristics = read_bits(s,8)
            vui.matrix_coefficients      = read_bits(s,8)
        end
    end

    vui.chroma_location_info_present_flag = get_bit(s)
    if vui.chroma_location_info_present_flag then
        vui.chroma_sample_loc_type_top_field    = get_ue_golomb(s)
        vui.chroma_sample_loc_type_bottom_field = get_ue_golomb(s)
    end

    vui.timing_info_present_flag = get_bit(s)
    if vui.timing_info_present_flag then
        vui.num_units_in_tick     = read_bits(s,32)
        vui.time_scale            = read_bits(s,32)
        vui.fixed_frame_rate_flag = get_bit(s)
    end

    vui.nal_hrd_parameters_present_flag = get_bit(s)
    if vui.nal_hrd_parameters_present_flag then
        vui.nal_hrd_parameters = hrd_parameters(s)
    end
    vui.vcl_hrd_parameters_present_flag = get_bit(s)
    if vui.vcl_hrd_parameters_present_flag then
        vui.vcl_hrd_parameters = hrd_parameters(s)
    end
    if     vui.vcl_hrd_parameters_present_flag
        or vui.nal_hrd_parameters_present_flag then
        vui.low_delay_hrd_flag = get_bit(s)
    end

    vui.pic_struct_present_flag    = get_bit(s)
    vui.bitstream_restriction_flag = get_bit(s)
    if vui.bitstream_restriction_flag then
        vui.motion_vectors_over_pic_boundaries_flag = get_bit(s)
        vui.max_bytes_per_pic_denom                 = get_bit(s)
        vui.max_bits_per_mb_denom                   = get_bit(s)
        vui.log2_max_mv_length_horizontal           = get_bit(s)
        vui.log2_max_mv_length_vertical             = get_bit(s)
        vui.num_reorder_frames                      = get_bit(s)
        vui.max_dec_frame_buffering                 = get_bit(s)
    end

    return vui
end

local function dump_table(t)
    local p = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then
            v = '{'..dump_table(v)..'}'
        elseif type(v) == 'boolean' then
            v = v and 'true' or 'false'
        end
        push(p, k..":"..(v or "<nil>"))
    end
    return join(p, " ,")
end

local function decode_seq_parameter_set(s)
    local sps = {}
    sps.profile_idc = read_bits(s,8)
    sps.constaint_f = read_bits(s,8) 
    sps.level_idc   = read_bits(s,8) 
    sps.sps_id      = get_ue_golomb(s)

    if sps.profile_idc == 100 or
       sps.profile_idc == 110 or
       sps.profile_idc == 122 or
       sps.profile_idc == 244 or
       sps.profile_idc == 118 or
       sps.profile_idc ==  44 or
       sps.profile_idc ==  83 or
       sps.profile_idc ==  86 
    then
        sps.chroma_format_idc = get_ue_golomb(s)
        if sps.chroma_format_idc == 3 then
            sps.seperate_colour_plane_flag = get_bit(s)
        end
        sps.bit_depth_luma_minus8   = get_ue_golomb(s)
        sps.bit_depth_chroma_minus8 = get_ue_golomb(s)

        sps.qpprime_y_zero_transform_bypass_flag = get_bit(s)
        sps.seq_scaling_matrix_present_flag      = get_bit(s)
        if sps.seq_scaling_matrix_present_flag then
            sps.seq_scaling_list_present_flag = {}
            for j=1, (sps.chroma_format_idc == 3 and 12 or 8) do
                sps.seq_scaling_list_present_flag[j] = get_bit(s)
                if sps.seq_scaling_list_present_flag[j] then
                    if j < 7 then   -- LUA array 1, see for j=1
                        sps.scalinglist4x4 = sps.scalinglist4x4 or {}
                        sps.defscaling4x4  = sps.defscaling4x4  or {}
                        sps.scalinglist4x4[j],   sps.defscaling4x4[j]
                            = scaling_list(s, 16)
                    else
                        sps.scalinglist8x8 = sps.scalinglist8x8 or {}
                        sps.defscaling8x8  = sps.defscaling8x8  or {}
                        sps.scalinglist8x8[j-7], sps.defscaling8x8[j-7] 
                            = scaling_list(s, 64)
                    end
                end
            end
        else
            sps.chroma_format_idc       = 1
            sps.bit_depth_luma_minus8   = 0
            sps.bit_depth_chroma_minus8 = 0
        end
    end
        
    sps.log2_max_frame_num_minus4 = get_ue_golomb(s)
    sps.pic_order_cnt_type        = get_ue_golomb(s)
    if      sps.pic_order_cnt_type == 0 then
        sps.log2_max_pic_order_cnt_lsb_minus4 = get_ue_golomb(s)
    elseif sps.pic_order_cnt_type == 1 then
        sps.delta_pic_always_zero_flag     = get_bit(s)
        sps.offset_for_non_ref_pic         = get_se_golomb(s)
        sps.offset_for_top_to_bottom_field = get_se_golomb(s)
        sps.num_ref_frames_in_pic_order_cnt_cycle
                                                 = get_ue_golomb(s)
        sps.offset_for_ref_frame = {}
        for j=1,sps.num_ref_frames_in_pic_order_cnt_cycle do
            sps.offset_for_ref_frame[j] = get_se_golomb(s)
        end
    end

    sps.max_num_ref_frames                   = get_ue_golomb(s)
    sps.gaps_in_frame_num_value_allowed_flag = get_bit(s)
    sps.pic_width_in_mbs_minus1              = get_ue_golomb(s)
    sps.pic_height_in_map_units_minus1       = get_ue_golomb(s)
    sps.frame_mbs_only_flag                  = get_bit(s)
    if not sps.frame_mbs_only_flag then
        sps.mb_adaptive_frame_field_flag     = get_bit(s)
    end
    sps.direct_8x8_interference_flag         = get_bit(s)
    sps.frame_cropping_flag                  = get_bit(s)
    if sps.frame_cropping_flag then
        sps.frame_crop_left_offset           = get_ue_golomb(s)
        sps.frame_crop_right_offset          = get_ue_golomb(s)
        sps.frame_crop_top_offset            = get_ue_golomb(s)
        sps.frame_crop_bottom_offset         = get_ue_golomb(s)
    end
    sps.vui_parameters_present_flag          = get_bit(s)
    if sps.vui_parameters_present_flag then
        sps.vui_parameters = vui_parameters(s)
    end

    io.stderr:write("SPS:\t",dump_table(sps),"\n")
    
    return sps
end

local function nal_unit_header_svc_extension(s)
    local svc = {}
    svc.idr_flag                 = get_bit(s)
    svc.priority_id              = read_bits(s,6)
    svc.no_inter_layer_pred_flag = get_bit(s)
    svc.dependency_id            = read_bits(s,3)
    svc.quality_id               = read_bits(s,4)
    svc.temporal_id              = read_bits(s,3)
    svc.use_ref_base_pic_flag    = get_bit(s)
    svc.discarable_flag          = get_bit(s)
    svc.output_flag              = get_bit(s)
    local reserved_three_2bits   = read_bits(s,3)
    return svc
end

local function nal_unit_header_mvc_extension(s)
    local mvc = {}
    mvc.non_idr_flag        = get_bit(s)
    mvc.priority_id         = read_bits(s,6)
    mvc.view_id             = read_bits(s,10)
    mvc.temporal_id         = read_bits(s,3)
    mvc.anchor_pic_flag     = get_bit(s)
    mvc.inter_view_flag     = get_bit(s)
    local reserverd_one_bit = get_bit(s)
    return mvc
end

function PlayC:write(_, nal_unit)
    io.stderr:write("NAL data length:"..#(nal_unit).."\n")
    local get_bit, s = bit.iterator(nal_unit)

    local header = {}

    -- determine main nal_unit_type
    local forbidden_zero_bit = get_bit(s)
    header.nal_ref_idc       = read_bits(s, 2)
    header.nal_unit_type     = read_bits(s, 5)
    io.stderr:write(
        "nal_ref_idc:\t",     header.nal_ref_idc   or "<nil>",
        "\tnal_unit_type:\t", header.nal_unit_type or "<nil>", "\n"
    )

    if header.nal_unit_type == 14 or header.nal_unit_type == 20 then
        header.svc_extension_flag = get_bit(s) 
        if header.svc_extension_flag then
            header.svc_extension = nal_unit_header_svc_extension(s)
        else
            header.mvc_extension = nal_unit_header_mvc_extension(s)
        end
    end

    -- start decoding the rbsp data itself
    if header.nal_unit_type == 7 then
        self.sps = decode_seq_parameter_set(s)
    end

end

function PlayC:new(data)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

return PlayC 
