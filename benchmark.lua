
local function timethese(nr, methods)
    print("Benchmarking "..nr.." times")
    local x
    for k,f in pairs(methods) do
        x = os.clock()
        for i=0,nr-1 do
            f()
        end
        x = os.clock() - x
        print(string.format(
            "%5s: %.2f wallclock secs @ %.2f/s (n=%.f)",
            k,
            x,
            nr/x,
            nr
        ))
    end
end

return timethese
