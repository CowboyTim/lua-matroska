

local PlayC = {}

local bit   = require("bit")
local cabac = require("h264_cabac")

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
local get_ae        = cabac.get_ae

local P  = 0
local B  = 1
local I  = 2
local SP = 3
local SI = 4
local SI = 5

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
    return join(p, ", ")
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
            for j=1, (sps.chroma_format_idc ~= 3 and 8 or 12) do
                sps.seq_scaling_list_present_flag[j] = get_bit(s)
                if sps.seq_scaling_list_present_flag[j] then
                    -- copy/paste a bit
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

    if sps.seperate_colour_plane_flag then
        sps.ChromaArrayType = 0
    else
        sps.ChromaArrayType = sps.chroma_format_idc
    end

    sps.PicHeightInMapUnits = sps.pic_height_in_map_units_minus1 + 1
    sps.FrameHeightInMbs    = (2 - (sps.frame_mbs_only_flag and 1 or 0)) * sps.PicHeightInMapUnits
    sps.PicWidthInMbs       = sps.pic_width_in_mbs_minus1 + 1
    sps.PicSizeInMapUnits   = sps.PicWidthInMbs * sps.PicHeightInMapUnits

    print("SPS:\t",dump_table(sps),"\n")
    
    return sps
end

local function min(a,b)
    return a < b and a or b
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

local function pic_parameter_set(s, sps)
    local pic = {}
    pic.pic_parameter_set_id     = get_ue_golomb(s)
    pic.seq_parameter_set_id     = get_ue_golomb(s)
    pic.entropy_coding_mode_flag = get_bit(s)
    pic.bottom_field_pic_order_in_frame_present_flag
                                 = get_bit(s)
    pic.num_slice_groups_minus1  = get_ue_golomb(s)
    if pic.num_slice_groups_minus1 > 0 then
        pic.slice_group_map_type = get_ue_golomb(s)
        if     pic.slice_group_map_type == 0 then
            pic.run_length_minus1 = {}
            for j=1,pic.num_slice_groups_minus1+1 do
                pic.run_length_minus1[j] = get_ue_golomb(s)
            end
        elseif pic.slice_group_map_type == 2 then
            pic.top_left    = {}
            pic.bottom_left = {}
            for j=1,pic.num_slice_groups_minus1 do
                pic.top_left[j]    = get_ue_golomb(s)
                pic.bottom_left[j] = get_ue_golomb(s)
            end
        elseif pic.slice_group_map_type == 3
            or pic.slice_group_map_type == 4
            or pic.slice_group_map_type == 5 then
            pic.slice_group_change_direction_flag = get_bit(s)
            pic.slice_group_change_rate_minus1    = get_ue_golomb(s)
        elseif pic.slice_group_map_type == 6 then
            pic.pic_size_in_map_units_minus1 = get_ue_golomb(s)
            pic.slice_group_id = {}
            for j=1,pic.pic_size_in_map_units_minus1+1 do
                pic.slice_group_id[j] = get_bit(s)
            end
        end
    end

    pic.num_ref_idx_l0_default_active_minus1   = get_ue_golomb(s)
    pic.num_ref_idx_l1_default_active_minus1   = get_ue_golomb(s)
    pic.weighted_pred_flag                     = get_bit(s)
    pic.weighted_bipred_idc                    = read_bits(s,2)
    pic.init_qp_minus26                        = get_se_golomb(s)
    pic.init_qs_minus26                        = get_se_golomb(s)
    pic.chroma_qp_index_offset                 = get_se_golomb(s)
    pic.deblocking_filter_control_present_flag = get_bit(s)
    pic.constrained_intra_pred_flag            = get_bit(s)
    pic.redundant_pic_cnt_present_flag         = get_bit(s)

    pic.transform_8x8_mode_flag = get_bit(s)
    if pic.transform_8x8_mode_flag then
        pic.pic_scaling_matrix_present_flag = get_bit(s)
        if pic.pic_scaling_matrix_present_flag then
            pic.pic_scaling_list_present_flag = {}
            for j=1,6
                    +(pic.transform_8x8_mode_flag and 1 or 0)
                    *(sps.chroma_format_idc ~= 3 and 2 or 6) do
                pic.pic_scaling_list_present_flag[j] = get_bit(s)
                if pic.pic_scaling_list_present_flag[j] then
                    -- copy/paste a bit
                    if j < 7 then   -- LUA array 1, see for j=1
                        pic.scalinglist4x4 = pic.scalinglist4x4 or {}
                        pic.defscaling4x4  = pic.defscaling4x4  or {}
                        pic.scalinglist4x4[j],   pic.defscaling4x4[j]
                            = scaling_list(s, 16)
                    else
                        pic.scalinglist8x8 = pic.scalinglist8x8 or {}
                        pic.defscaling8x8  = pic.defscaling8x8  or {}
                        pic.scalinglist8x8[j-7], pic.defscaling8x8[j-7] 
                            = scaling_list(s, 64)
                    end
                end
            end
        end
        pic.second_chroma_qp_index_offset = get_se_golomb(s)
    end

    print("PIC:\t",dump_table(pic),"\n")
    return pic
end

local handle_sei = {
    ["5"] = function (s, sei)
        
        -- get UUID: 16 bytes
        sei.uuid_iso_iec_11578
            = substr(s.data, s.i, s.i+15)

        -- get the user data: payloadSize - 16 
        sei.user_data_payload_byte
            = substr(s.data, s.i+16, s.i+sei.payloadSize -1)

        -- set the bit iterator ok again
        s.bit = 7
        s.i   = s.i + sei.payloadSize

        print(
            "sei.uuid_iso_iec_11578\t",#(sei.uuid_iso_iec_11578),
            "\tsei.user_data_payload_byte\t",#(sei.user_data_payload_byte),
            "\ti:\t",s.i,"\tb:\t",s.b,"\n"
        )
        return
    end,
}

local function sei_rbsp(s)

    -- NOTE: basically, we start byte_aligned() here
         
    while true do 

        local sei = {}
        sei.payloadType, sei.payloadSize = 0, 0

        -- payloadType
        v = read_bits(s, 8)
        if v == nil then break end
        while true do
            sei.payloadType = sei.payloadType + v
            if v ~= 255 then break end
            v = read_bits(s, 8)
        end
        
        -- payloadSize
        v = read_bits(s, 8)
        if v == nil then break end
        while true do
            sei.payloadSize = sei.payloadSize + v
            if v ~= 255 then break end
            v = read_bits(s, 8)
        end

        -- handle that data according to the SEI payloadType
        local sei_handler = handle_sei[tostring(sei.payloadType)]
        if sei_handler ~= nil then
            sei_handler(s, sei)
        else
            print("SEI Type\t", sei.payloadType, "\t not supported\n")
        end

        -- make byte aligned, NOTE: have extra byte here, wich is 0x80, which
        -- happens to be the 10000000 bit string we 'need' according to the
        -- specs, however, we are allready byte_aligned here, so we don't need
        -- do anything here. What's going on?!
        if s.bit ~= 7 then
            v = get_bit(s)
        end

        print("SEI:\t",dump_table(sei),"\n")
    end
    
    return sei
end

function PlayC:macroblock_layer(s, header)
    -- TODO
end

function PlayC:NextMbAddr(n)
    -- TODO
    local i = n + 1
    while i < self.sps.PicSizeInMbs and MbToSliceGroupMap[i] ~= MbToSliceGroupMap[n] do
        i = i + 1
    end
    return i
end

function PlayC:slice_data(s, header)
    io.stderr:write("slice_data\n")

    -- TODO: implement further

    if self.pic.entropy_coding_mode_flag then
        while s.bit ~= 7 do
            local v = get_bit(s)
        end
    end

    local MbaffFrameFlag = self.sps.mb_adaptive_frame_field_flag and not header.field_pic_flag
    local firstMbAddr    = header.first_mb_in_slice * (1 + (MbaffFrameFlag and 1 or 0))
    local CurrMbAddr     = firstMbAddr
    local moreDataFlag   = true
    local prevMbSkipped  = false
    repeat
        if header.slice_type ~= I and header.slice_type ~= SI then
            if not self.pic.entropy_coding_mode_flag then
                mb_skip_run   = get_ue_golomb(s)
                prevMbSkipped = mb_skip_flag > 0
                for i=0,mb_skip_run do
                    CurrMbAddr = self:NextMbAddr(CurrMbAddr)
                end
                if CurrMbAddr ~= firstMbAddr or mb_skip_run > 0 then
                    moreDataFlag = more_rbsp_data(s) -- TODO
                end
            else
                mb_skip_flag = get_ae(s) -- TODO
                moreDataFlag = not mb_skip_flag
            end
        end
        if moreDataFlag then
            if     (CurrMbAddr % 2 == 0 and MbaffFrameFlag)
                or (CurrMbAddr % 2 == 1 and prevMbSkipped ) then
                mb_field_decoding_flag = get_bit(s) -- TODO
            end
            self:macroblock_layer(s, header)
        end
        if not self.pic.entropy_coding_mode_flag then
            moreDataFlag = more_rbsp_data(s) -- TODO
        else
            if header.slice_type ~= I and header.slice_type ~= SI then
                prevMbSkipped = mb_skip_flag
            end
            if MbaffFrameFlag and CurrMbAddr % 2 == 0 then
                moreDataFlag = 1
            else
                end_of_slice_flag = get_ae(s) -- TODO
                moreDataFlag = not end_of_slice_flag
            end
        end
        CurrMbAddr = self:NextMbAddr(CurrMbAddr)
    until not moreDataFlag
end

function PlayC:slice_layer_without_partitioning_rbsp(s, nal_unit_type, nal_ref_idc, is_idr)
    local header = self:slice_header(s, nal_unit_type, nal_ref_idc, is_idr)
    local data   = self:slice_data(s, header)
    return header, data
end

local function _mod_list(s, r)
    local modification_of_pic_nums_idc
    repeat
        modification_of_pic_nums_idc = get_ue_golomb(s)
        if     modification_of_pic_nums_idc == 0
            or modification_of_pic_nums_idc == 1 then
            r.abs_diff_pic_num_minus1 = get_ue_golomb(s)
        elseif modification_of_pic_nums_idc == 2 then
            r.long_term_pic_num = get_ue_golomb(s) 
        end
    until modification_of_pic_nums_idc ~= 3
end

local function ref_pic_list_modification(s, slice_type)
    local r = {}
    if slice_type % 5 ~= 2 and slice_type % 5 ~= 4 then
        r.ref_pic_list_modification_flag_l0 = get_bit(s)
        if r.ref_pic_list_modification_flag_l0 then
            _mod_list(s, r)
        end
    end

    if slice_type % 5 == 1 then
        r.ref_pic_list_modification_flag_l1 = get_bit(s)
        if r.ref_pic_list_modification_flag_l1 then
            _mod_list(s, r)
        end
    end
    return r
end

local function dec_ref_pic_marking(s, IdrPicFlag)
    local drpm = {}
    if IdrPicFlag then
        drpm.no_output_of_prior_pics_flag = get_bit(s)
        drpm.long_term_reference_flag     = get_bit(s)
    else
        drpm.adaptive_ref_pic_marking_mode_flag = get_bit(s)
        if drpm.adaptive_ref_pic_marking_mode_flag then
            local memory_management_control_operation
            repeat
                memory_management_control_operation = get_ue_golomb(s)
                if     memory_management_control_operation == 1
                    or memory_management_control_operation == 3 then
                    drpm.difference_of_pic_nums_minus1 = get_ue_golomb(s)
                elseif memory_management_control_operation == 2 then
                    drpm.long_term_pic_num = get_ue_golomb(s)
                elseif memory_management_control_operation == 3
                    or memory_management_control_operation == 6 then
                    drpm.long_term_frame_idx = get_ue_golomb(s)
                elseif memory_management_control_operation == 4 then
                    drpm.max_long_term_frame_idx_plus1 = get_ue_golomb(s)
                end
            until memory_management_control_operation ~= 0
        end
    end
    return drpm
end

local function _pred_weight_table(s, max, ChromaArrayType)
    local luma_weight   = {}
    local luma_offset   = {}
    local chroma_weight = {}
    local chroma_offset = {}
    for i=1,max+1 do
        local luma_weight_flag = get_bit(s)
        if luma_weight_flag then
            wt.luma_weight[i] = get_se_golomb(s)
            wt.luma_offset[i] = get_se_golomb(s)
        end
        if ChromaArrayType ~= 0 then
            local chroma_weight_flag = get_bit(s)
            if chroma_weight_flag then
                wt.chroma_weight[i] = {}
                wt.chroma_offset[i] = {}
                for j=1,2 do
                    wt.chroma_weight[i][j] = get_se_golomb(s)
                    wt.chroma_offset[i][j] = get_se_golomb(s)
                end
            end
        end
    end
    return luma_weight, luma_offset, chroma_weight, chroma_offset
end

local function pred_weight_table(s, self)
    local wt = {}

    wt.luma_log2_weight_denom = get_ue_golomb(s)
    if sps.ChromaArrayType ~= 0 then
        wt.chroma_log2_weight_denom = get_ue_golomb(s)
    end

    wt.luma_weight_l0,
    wt.luma_offset_l0,
    wt.chroma_weight_l0,
    wt.chroma_offset_l0 = _pred_weight_table(
        s, 
        self.header.num_ref_idx_l0_active_minus1,
        self.sps.ChromaArrayType
    )

    if self.header.slice_type % 5 == 1 then
        wt.luma_weight_l1,
        wt.luma_offset_l1,
        wt.chroma_weight_l1,
        wt.chroma_offset_l1 = _pred_weight_table(
            s, 
            self.header.num_ref_idx_l1_active_minus1, 
            self.sps.ChromaArrayType
        )
    end

    return wt
end

function PlayC:slice_header(s, nal_unit_type, nal_ref_idc, is_idr)
    local h = {}
    h.first_mb_in_slice    = get_ue_golomb(s)
    h.slice_type           = get_ue_golomb(s)
    h.pic_parameter_set_id = get_ue_golomb(s)
    h.IdrPicFlag           = (nal_unit_type == 5)
    if self.sps.seperate_colour_plane_flag then
        h.colour_plane_id = read_bits(s, 2)
    end
    h.frame_num            = get_ue_golomb(s)  -- u(v) ?

    if self.sps.frame_mbs_only_flag then
        h.field_pic_flag = get_bit(s)
        if h.field_pic_flag then
            h.bottom_field_flag = get_bit(s)
        end
    end

    if is_idr then
        h.idr_pic_id = get_ue_golomb(s)
    end

    if self.sps.pic_order_cnt_type == 0 then
        h.pic_order_cnt_lsb = get_ue_golomb(s)
        if self.pic.bottom_field_pic_order_in_frame_present_flag 
            and not h.field_pic_flag then
            h.delta_pic_order_cnt_bottom = get_se_golomb(s)
        end
    elseif self.sps.pic_order_cnt_type == 1 
        and not self.sps.delta_pic_always_zero_flag then
        h.delta_pic_order_cnt = {}
        h.delta_pic_order_cnt[1] = get_se_golomb(s)
        if self.pic.bottom_field_pic_order_in_frame_present_flag 
            and not h.field_pic_flag then
            h.delta_pic_order_cnt[2] = get_se_golomb(s)
        end
    end

    if self.pic.redundant_pic_cnt_present_flag then
        h.redundant_pic_cnt = get_ue_golomb(s)
    end

    if     h.slice_type == B then
        h.direct_spatial_mv_pred_flag = get_bit(s)
    elseif h.slice_type == P or h.slice_type == SP or h.slice_type == B then
        h.num_ref_idx_active_override_flag = get_bit(s)
        if h.num_ref_idx_active_override_flag then
            h.num_ref_idx_l0_active_minus1 = get_ue_golomb(s)
            if h.slice_type == B then
                h.num_ref_idx_l1_active_minus1 = get_ue_golomb(s)
            end
        end
    end

    if nal_unit_type == 20 then
        -- TODO
        h.rplmm = ref_pic_list_mvc_modification(s)
    else
        h.rplm  = ref_pic_list_modification(s, h.slice_type)
    end

    if     (self.pic.weighted_pred_flag and 
            (h.slice_type == P or h.slice_type == SP))
        or (self.pic.weighted_bipred_idc == 1 and h.slice_type == B) 
    then
        h.pwt = pred_weight_table(s, self)
    end

    if nal_ref_idc ~= 0 then
        h.drpm = dec_ref_pic_marking(s, IdrPicFlag)
    end

    if      self.pic.entropy_coding_mode_flag    
        and h.slice_type ~= I 
        and h.slice_type ~= SI then
        h.cabac_init_idc = get_ue_golomb(s)
    end

    h.slice_qp_data = get_se_golomb(s)
    if h.slice_ype == SP or h.slice_type == SI then
        if h.slice_type == SP then
            h.sp_for_switch_flag = get_bit(s)
        end
        h.slice_qs_data = get_se_golomb(s)
    end

    if self.pic.deblocking_filter_control_present_flag then
        h.disable_deblocking_filter_idc = get_ue_golomb(s)
        if h.disable_deblocking_filter_idc ~= 1 then
            h.slice_alpha_c0_offset_div2 = get_se_golomb(s)
            h.slice_beta_offset_div2     = get_se_golomb(s)
        end
    end

    if      self.pic.num_slice_groups_minus1 > 0
        and self.pic.slice_group_map_type >= 3
        and self.pic.slice_group_map_type <= 5 then
        h.slice_group_change_cycle = get_ue_golomb(s)
    end

    self.sps.PicHeightInMbs = self.sps.FrameHeightInMbs/(1 + (h.field_pic_flag and 1 or 0))
    self.sps.PicSizeInMbs   = self.sps.PicWidthInMbs * self.sps.PicHeightInMbs

    --[[
    local MapUnitsInSliceGroup0 = min(
        h.slice_group_change_cycle * (self.pic.slice_group_change_rate_minus1 + 1),
        self.sps.PicSizeInMapUnits
    )
    local sizeOfUpperLeftGroup = self.pic.slice_group_change_direction_flag
        and (self.sps.PicSizeInMapUnits - MapUnitsInSliceGroup0)
        or  MapUnitsInSliceGroup0
    --]]

    return h
end

function PlayC:write(_, nal_unit)
    print("NAL data length:"..#(nal_unit).."\n")
    local get_bit, s = bit.iterator(nal_unit)

    -- determine main nal_unit_type
    local forbidden_zero_bit = get_bit(s)
    local nal_ref_idc        = read_bits(s, 2)
    local nal_unit_type      = read_bits(s, 5)
    print(
        "nal_ref_idc:\t",     nal_ref_idc   or "<nil>",
        "\tnal_unit_type:\t", nal_unit_type or "<nil>", "\n"
    )

    if nal_unit_type == 14 or nal_unit_type == 20 then
        svc_extension_flag = get_bit(s) 
        if svc_extension_flag then
            self.svc_extension = nal_unit_header_svc_extension(s)
        else
            self.mvc_extension = nal_unit_header_mvc_extension(s)
        end
    end

    -- start decoding the rbsp data itself
    if     nal_unit_type == 1 then
        self:slice_layer_without_partitioning_rbsp(
            s, nal_unit_type, nal_ref_idc, false
        )
    elseif nal_unit_type == 5 then
        self:slice_layer_without_partitioning_rbsp(
            s, nal_unit_type, nal_ref_idc, true
        )
    elseif nal_unit_type == 7 then
        self.sps     = decode_seq_parameter_set(s)
    elseif nal_unit_type == 8 then
        self.pic     = pic_parameter_set(s, self.sps)
    elseif nal_unit_type == 6 then
        self.sei     = sei_rbsp(s)
    end

end

function PlayC:new(data)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

return PlayC 
