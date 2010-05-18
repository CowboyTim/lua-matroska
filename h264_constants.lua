

local _REQUIREDNAME = "h264_constants"

if _G[_REQUIREDNAME] then
    return _G[_REQUIREDNAME]
end

local const = {}

_G[_REQUIREDNAME] = const

const.P  = {[0] = true, [5] = true}
const.B  = {[1] = true, [6] = true}
const.I  = {[2] = true, [7] = true}
const.SP = {[3] = true, [8] = true}
const.SI = {[4] = true, [9] = true}

const.reverse = {
    [0] = const.P,
    [5] = const.P,
    [1] = const.B,
    [6] = const.B,
    [2] = const.I,
    [7] = const.I,
    [3] = const.SP,
    [8] = const.SP,
    [4] = const.SI,
    [9] = const.SI
}

return const
