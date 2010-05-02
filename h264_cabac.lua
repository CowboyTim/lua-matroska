
local cabac = {}

if _REQUIREDNAME == nil then
    _REQUIREDNAME = "cabac"
end
_G[_REQUIREDNAME] = cabac

local ceil = math.ceil
local cci, ctxIdxInit  = require("cabac_init_values")

local function clip3(x,y,z)
    return z < x and x or (z > y and y) or z
end

-- TODO: check the >>4 shift right bit implementation with divide and ceil
--       here
local function cabac_init_context(pic, header, n, m)
    local SliceQPy    = 26 + pic.init_qp_minus26 + header.slice_qs_delta
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

cabac.init = function(method, pic, header)
    local ctxIdxList = ctxIdxInit[method][header.slice_type]

end

return cabac
