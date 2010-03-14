local PlayC = {}

function PlayC:write(...)
    io.stderr:write(unpack(arg))
end

function PlayC:new(data)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

return PlayC 
