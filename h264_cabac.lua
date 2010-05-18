
local _REQUIREDNAME = "cabac"
if _G[_REQUIREDNAME] then
    return _G[_REQUIREDNAME]
end

local cabac = {}
_G[_REQUIREDNAME] = cabac

local ceil = math.ceil
local cci, ctxIdxInit  = require("cabac_init_values")

local function clip3(x,y,z)
    return z < x and x or (z > y and y) or z
end

-- TODO: check the >>4 shift right bit implementation with divide and ceil
--       here
local function cabac_init_context(init_qp_minus26, slice_qs_delta, n, m)
    local SliceQPy    = 26 + init_qp_minus26 + slice_qs_delta
    local preCtxState = clip3(1, 126, ceil((m * clip3(0, 51, SliceQPy))/(2*2*2*2)) + n)
    local valMPS, pStateIdx
    if preCtxState <= 63 then
        pStateIdx = 63 - preCtxState
        valMPS = 0
    else
        pStateIdx = preCtxState - 64
        valMPS = 1
    end
    return pStateIdx, valMPS
end

cabac.init = function(method, pic, header, cabac_init_idc)
    local ctxIdx = ctxIdxInit[header.slice_type][method]
    for i=ctxIdx[1],ctxIdx[2] do
        local n = cci.n[cabac_init_context][i]
        local m = cci.m[cabac_init_context][i]
        local a, b = cabac_init_context(pic.init_qp_minus26, header.slice_qs_delta, n, m)
    end

end

return cabac
