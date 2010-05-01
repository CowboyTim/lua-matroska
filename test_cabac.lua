
local c = require("h264_cabac")

c=c.cci

for i, _ in pairs(c.m[0]) do
    --print("cci.m[0]["..i.."] = "..c.m[0][i])
    --print("cci.n[0]["..i.."] = "..c.n[0][i])
    --print("cci.m[1]["..i.."] = "..c.m[1][i])
    --print("cci.n[1]["..i.."] = "..c.n[1][i])
    --print("cci.m[2]["..i.."] = "..c.m[2][i])
    --print("cci.n[2]["..i.."] = "..c.n[2][i])
    print("["..i.."]={"..  c.m[-1][i]..","..c.n[-1][i]..","..c.m[0][i]..","..c.n[0][i]..","..c.m[1][i]..","..c.n[1][i]..","..c.m[2][i]..","..c.n[2][i].."}")
end

