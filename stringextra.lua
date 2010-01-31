
local sprintf  = string.format
local subst    = string.gsub
local ord      = string.byte

_G.string.hex  = function (s)
    return subst(s,"(.)",function (x) return sprintf("%02X",ord(x)) end)
end
