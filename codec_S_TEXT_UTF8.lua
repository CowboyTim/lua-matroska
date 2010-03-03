local C = {}

function C:close()
    return self.fh:close()
end

function C:write(data)
    return data
end

function C:new(fh, data)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    self.fh = fh

    return o
end

return C
