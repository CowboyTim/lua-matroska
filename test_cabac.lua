
local c, _ = require("cabac_init_values")

for i=0,#(c.m[0]) do 
    print("["..i.."]={"..
        (c.m[-1][i] or "nil")..","..(c.n[-1][i] or "nil")..","..
        (c.m[ 0][i] or "nil")..","..(c.n[ 0][i] or "nil")..","..
        (c.m[ 1][i] or "nil")..","..(c.n[ 1][i] or "nil")..","..
        (c.m[ 2][i] or "nil")..","..(c.n[ 2][i] or "nil").."}"
    )
end

