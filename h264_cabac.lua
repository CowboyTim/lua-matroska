
local _REQUIREDNAME = "cabac"
if _G[_REQUIREDNAME] then
    return _G[_REQUIREDNAME]
end

local cabac = {}
_G[_REQUIREDNAME] = cabac

local ceil  = math.ceil
local cinit = require("cabac_init_values")
require("h264_constants")

local P  = h264_constants.P
local B  = h264_constants.B
local I  = h264_constants.I
local SP = h264_constants.SP
local SI = h264_constants.SI

cabac.ctxIdx = cinit.ctxIdx
cabac.cci    = cinit.cci

io.stderr:write("cabac_init_values require:", tostring(cabac.cci), "\t", tostring(cabac.ctxIdx),"\n")

local function clip3(x,y,z)
    return z < x and x or (z > y and y) or z
end

-- TODO: check the >>4 shift right bit implementation with divide and ceil
--       here
local function cabac_init_context(init_qp_minus26, slice_qp_delta, n, m)
    local SliceQPy    = 26 + init_qp_minus26 + slice_qp_delta
    local preCtxState = clip3(1, 126, ceil((m * clip3(0, 51, SliceQPy))/(2*2*2*2)) + n)
    if preCtxState <= 63 then
        return 63 - preCtxState, 0
    else
        return preCtxState - 64, 1
    end
end

cabac.init = function(method, pic, header)
    io.stderr:write("slice_type:", header.slice_type, "\t", "method:",method,"\n")
    if method == "end_of_slice_flag" then
        -- i: 276
        return 63, 0
    end
    local cabac_init_idc = header.cabac_init_idc
    local ctxIdx = cabac.ctxIdx[header.slice_type][method]
    for i=ctxIdx[1],ctxIdx[2] do
        io.stderr:write("cabac.init: ctxIdx:",i,"\n")
        if I[header.slice_type] or SI[header.slice_type] then
            cabac_init_idc = -1
        end
        if not cabac_init_idc then
            -- FIXME: double check this
            cabac_init_idc = -1
        end
        local n = cabac.cci.n[cabac_init_idc][i]
        local m = cabac.cci.m[cabac_init_idc][i]
        local a, b = cabac_init_context(pic.init_qp_minus26, header.slice_qp_delta, n, m)
    end

end

cabac.get_ae = function(method, s, pic, header)
    cabac.init(method, pic, header)
end

return cabac
