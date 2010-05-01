
local cabac = {}

if _REQUIREDNAME == nil then
    _REQUIREDNAME = "cabac"
end
_G[_REQUIREDNAME] = cabac

local ceil = math.ceil
local cci  = require("cabac_init_values")

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

local init = {
    ["slice_data"]       = {cci[70], cci[71], cci[72]},
    ["macroblock_layer"] = {cci[5]}
}

cabac.init = function(method, pic, header)
    local n, m = n_m[header.slice_type][cabac_init_idc]()
    return cabac_init_context(pic, header, n, m)
end

cabac.cci = cci

return cabac
