# This file is a part of Julia. License is MIT: http://julialang.org/license

tc{N}(r1::NTuple{N}, r2::NTuple{N}) = all(x->tc(x...), [zip(r1,r2)...])
tc{N}(r1::BitArray{N}, r2::Union{BitArray{N},Array{Bool,N}}) = true
tc{T}(r1::T, r2::T) = true
tc(r1,r2) = false

bitcheck(b::BitArray) = length(b.chunks) == 0 || (b.chunks[end] == b.chunks[end] & Base._msk_end(b))
bitcheck(x) = true

function check_bitop(ret_type, func, args...)
    r1 = func(args...)
    r2 = func(map(x->(isa(x, BitArray) ? Array(x) : x), args)...)
    @test isa(r1, ret_type)
    @test tc(r1, r2)
    @test isequal(r1, convert(ret_type, r2))
    @test bitcheck(r1)
end

macro check_bit_operation(ex, ret_type)
    @assert Meta.isexpr(ex, :call)
    Expr(:call, :check_bitop, esc(ret_type), map(esc,ex.args)...)
end

let t0 = time()
    global timesofar
    function timesofar(str)
        return # no-op, comment to see timings
        t1 = time()
        println(str, ": ", t1-t0, " seconds")
        t0 = t1
    end
end

# empty bitvector
@test BitVector() == BitVector(0)

# vectors size
v1 = 260
# matrices size
n1, n2 = 17, 20
# arrays size
s1, s2, s3, s4 = 5, 8, 3, 7

allsizes = [((), BitArray{0}), ((v1,), BitVector),
            ((n1,n2), BitMatrix), ((s1,s2,s3,s4), BitArray{4})]

# trues and falses
for (sz,T) in allsizes
    a = falses(sz...)
    @test a == falses(sz)
    @test !any(a)
    @test sz == size(a)
    b = trues(sz...)
    @test b == trues(sz)
    @test all(b)
    @test sz == size(b)
    c = trues(a)
    @test all(c)
    @test !any(a)
    @test sz == size(c)
    d = falses(b)
    @test !any(d)
    @test all(b)
    @test sz == size(d)
end

## Conversions ##

for (sz,T) in allsizes
    b1 = rand!(falses(sz...))
    @test isequal(BitArray(Array(b1)), b1)
    @test isequal(convert(Array{Float64,ndims(b1)}, b1),
                  convert(Array{Float64,ndims(b1)}, Array(b1)))
    @test isequal(convert(AbstractArray{Float64,ndims(b1)}, b1),
                  convert(AbstractArray{Float64,ndims(b1)}, Array(b1)))

    i1 = rand!(zeros(Bool, sz...), false:true)
    @test isequal(Array(BitArray(i1)), i1)
end

timesofar("conversions")

## Indexing ##

# 0d
for (sz,T) in allsizes
    b1 = rand!(falses(sz...))
    @check_bit_operation getindex(b1)         Bool
    @check_bit_operation setindex!(b1, true)  T
    @check_bit_operation setindex!(b1, false) T
end

# linear
for (sz,T) in allsizes[2:end]
    l = *(sz...)
    b1 = rand!(falses(sz...))
    for j = 1:l
        @check_bit_operation getindex(b1, j) Bool
    end

    for j in [0, 1, 63, 64, 65, 127, 128, 129, 191, 192, 193, l-1, l]
        @check_bit_operation getindex(b1, 1:j)   BitVector
        @check_bit_operation getindex(b1, j+1:l) BitVector
    end
    for j in [1, 63, 64, 65, 127, 128, 129, div(l,2)]
        m1 = j:(l-j)
        @check_bit_operation getindex(b1, m1) BitVector
    end

    t1 = find(bitrand(l))
    @check_bit_operation getindex(b1, t1)        BitVector

    for j = 1:l
        x = rand(Bool)
        @check_bit_operation setindex!(b1, x, j) T
    end

    y = rand(0.0:1.0)
    @check_bit_operation setindex!(b1, y, 100) T

    for j in [1, 63, 64, 65, 127, 128, 129, 191, 192, 193, l-1]
        x = rand(Bool)
        @check_bit_operation setindex!(b1, x, 1:j) T
        b2 = bitrand(j)
        @check_bit_operation setindex!(b1, b2, 1:j) T
        x = rand(Bool)
        @check_bit_operation setindex!(b1, x, j+1:l) T
        b2 = bitrand(l-j)
        @check_bit_operation setindex!(b1, b2, j+1:l) T
    end
    for j in [1, 63, 64, 65, 127, 128, 129, div(l,2)]
        m1 = j:(l-j)
        x = rand(Bool)
        @check_bit_operation setindex!(b1, x, m1) T
        b2 = bitrand(length(m1))
        @check_bit_operation setindex!(b1, b2, m1) T
    end
    x = rand(Bool)
    @check_bit_operation setindex!(b1, x, 1:100) T
    b2 = bitrand(100)
    @check_bit_operation setindex!(b1, b2, 1:100) T

    y = rand(0.0:1.0)
    @check_bit_operation setindex!(b1, y, 1:100) T

    t1 = find(bitrand(l))
    x = rand(Bool)
    @check_bit_operation setindex!(b1, x, t1) T
    b2 = bitrand(length(t1))
    @check_bit_operation setindex!(b1, b2, t1) T

    y = rand(0.0:1.0)
    @check_bit_operation setindex!(b1, y, t1) T
end

# multidimensional

rand_m1m2() = rand(1:n1), rand(1:n2)

b1 = bitrand(n1, n2)

m1, m2 = rand_m1m2()
b2 = bitrand(m1, m2)
@check_bit_operation copy!(b1, b2) BitMatrix

function gen_getindex_data()
    m1, m2 = rand_m1m2()
    produce((m1, m2, Bool))
    m1, m2 = rand_m1m2()
    produce((m1, 1:m2, BitVector))
    produce((m1, :, BitVector))
    m1, m2 = rand_m1m2()
    produce((m1, randperm(m2), BitVector))
    m1, m2 = rand_m1m2()
    produce((1:m1, m2, BitVector))
    produce((:, m2, BitVector))
    m1, m2 = rand_m1m2()
    produce((1:m1, 1:m2, BitMatrix))
    produce((:, :, BitMatrix))
    m1, m2 = rand_m1m2()
    produce((1:m1, randperm(m2), BitMatrix))
    produce((:, randperm(m2), BitMatrix))
    m1, m2 = rand_m1m2()
    produce((randperm(m1), m2, BitVector))
    m1, m2 = rand_m1m2()
    produce((randperm(m1), 1:m2, BitMatrix))
    produce((randperm(m1), :, BitMatrix))
    m1, m2 = rand_m1m2()
    produce((randperm(m1), randperm(m2), BitMatrix))
end

for (k1, k2, T) in Task(gen_getindex_data)
    # println(typeof(k1), " ", typeof(k2), " ", T) # uncomment to debug
    @check_bit_operation getindex(b1, k1, k2) T
    @check_bit_operation getindex(b1, k1, k2, 1) T
end

function gen_setindex_data()
    m1, m2 = rand_m1m2()
    produce((rand(Bool), m1, m2))
    m1, m2 = rand_m1m2()
    produce((rand(Bool), m1, 1:m2))
    produce((rand(Bool), m1, :))
    produce((bitrand(m2), m1, 1:m2))
    m1, m2 = rand_m1m2()
    produce((rand(Bool), m1, randperm(m2)))
    produce((bitrand(m2), m1, randperm(m2)))
    m1, m2 = rand_m1m2()
    produce((rand(Bool), 1:m1, m2))
    produce((rand(Bool), :, m2))
    produce((bitrand(m1), 1:m1, m2))
    m1, m2 = rand_m1m2()
    produce((rand(Bool), 1:m1, 1:m2))
    produce((rand(Bool), :, :))
    produce((bitrand(m1, m2), 1:m1, 1:m2))
    m1, m2 = rand_m1m2()
    produce((rand(Bool), 1:m1, randperm(m2)))
    produce((rand(Bool), :, randperm(m2)))
    produce((bitrand(m1, m2), 1:m1, randperm(m2)))
    m1, m2 = rand_m1m2()
    produce((rand(Bool), randperm(m1), m2))
    produce((bitrand(m1), randperm(m1), m2))
    m1, m2 = rand_m1m2()
    produce((rand(Bool), randperm(m1), 1:m2))
    produce((rand(Bool), randperm(m1), :))
    produce((bitrand(m1,m2), randperm(m1), 1:m2))
    m1, m2 = rand_m1m2()
    produce((rand(Bool), randperm(m1), randperm(m2)))
    produce((bitrand(m1,m2), randperm(m1), randperm(m2)))
end

for (b2, k1, k2) in Task(gen_setindex_data)
    # println(typeof(b2), " ", typeof(k1), " ", typeof(k2)) # uncomment to debug
    @check_bit_operation setindex!(b1, b2, k1, k2) BitMatrix
end

m1, m2 = rand_m1m2()
b2 = bitrand(1, 1, m2)
@check_bit_operation setindex!(b1, b2, m1, 1:m2) BitMatrix
x = rand(Bool)
b2 = bitrand(1, m2, 1)
@check_bit_operation setindex!(b1, x, m1, 1:m2, 1)  BitMatrix
@check_bit_operation setindex!(b1, b2, m1, 1:m2, 1) BitMatrix

for p1 = [rand(1:v1) 1 63 64 65 191 192 193]
    for p2 = [rand(1:v1) 1 63 64 65 191 192 193]
        for n = 0 : min(v1 - p1 + 1, v1 - p2 + 1)
            b1 = bitrand(v1)
            b2 = bitrand(v1)
            @check_bit_operation copy!(b1, p1, b2, p2, n) BitVector
        end
    end
end

# logical indexing
b1 = bitrand(n1, n2)
t1 = bitrand(n1, n2)
@test isequal(Array(b1[t1]), Array(b1)[t1])
@test isequal(Array(b1[t1]), Array(b1)[Array(t1)])

t1 = bitrand(n1)
t2 = bitrand(n2)
@test isequal(Array(b1[t1, t2]), Array(b1)[t1, t2])
@test isequal(Array(b1[t1, t2]), Array(b1)[Array(t1), Array(t2)])


b1 = bitrand(n1, n2)
t1 = bitrand(n1, n2)
@check_bit_operation setindex!(b1, true, t1) BitMatrix

t1 = bitrand(n1, n2)
b2 = bitrand(countnz(t1))
@check_bit_operation setindex!(b1, b2, t1) BitMatrix

let m1 = rand(1:n1), m2 = rand(1:n2)
    t1 = bitrand(n1)
    b2 = bitrand(countnz(t1), m2)
    k2 = randperm(m2)
    @check_bit_operation setindex!(b1, b2, t1, 1:m2)       BitMatrix
    @check_bit_operation setindex!(b1, b2, t1, n2-m2+1:n2) BitMatrix
    @check_bit_operation setindex!(b1, b2, t1, k2)         BitMatrix

    t2 = bitrand(n2)
    b2 = bitrand(m1, countnz(t2))
    k1 = randperm(m1)
    @check_bit_operation setindex!(b1, b2, 1:m1, t2)       BitMatrix
    @check_bit_operation setindex!(b1, b2, n1-m1+1:n1, t2) BitMatrix
    @check_bit_operation setindex!(b1, b2, k1, t2)         BitMatrix
end

timesofar("indexing")

## Dequeue functionality ##

b1 = BitArray(0)
i1 = Bool[]
for m = 1 : v1
    x = rand(Bool)
    push!(b1, x)
    push!(i1, x)
    @test isequal(Array(b1), i1)
end

for m1 = 0 : v1
    for m2 = [0, 1, 63, 64, 65, 127, 128, 129]
        b1 = bitrand(m1)
        b2 = bitrand(m2)
        i1 = Array(b1)
        i2 = Array(b2)
        @test isequal(Array(append!(b1, b2)), append!(i1, i2))
        @test isequal(Array(append!(b1, i2)), append!(i1, b2))
    end
end

for m1 = 0 : v1
    for m2 = [0, 1, 63, 64, 65, 127, 128, 129]
        b1 = bitrand(m1)
        b2 = bitrand(m2)
        i1 = Array(b1)
        i2 = Array(b2)
        @test isequal(Array(prepend!(b1, b2)), prepend!(i1, i2))
        @test isequal(Array(prepend!(b1, i2)), prepend!(i1, b2))
    end
end

b1 = bitrand(v1)
i1 = Array(b1)
for m = 1 : v1
    jb = pop!(b1)
    ji = pop!(i1)
    @test jb == ji
    @test isequal(Array(b1), i1)
end
@test length(b1) == 0


b1 = BitArray(0)
i1 = Bool[]
for m = 1 : v1
    x = rand(Bool)
    unshift!(b1, x)
    unshift!(i1, x)
    @test isequal(Array(b1), i1)
end


b1 = bitrand(v1)
i1 = Array(b1)
for m = 1 : v1
    jb = shift!(b1)
    ji = shift!(i1)
    @test jb == ji
    @test isequal(Array(b1), i1)
end
@test length(b1) == 0

b1 = BitArray(0)
@test_throws BoundsError insert!(b1, 2, false)
@test_throws BoundsError insert!(b1, 0, false)
i1 = Array(b1)
for m = 1 : v1
    j = rand(1:m)
    x = rand(Bool)
    @test insert!(b1, j, x) === b1
    insert!(i1, j, x)
    @test isequal(Array(b1), i1)
end

b1 = bitrand(v1)
i1 = Array(b1)
for j in [63, 64, 65, 127, 128, 129, 191, 192, 193]
    x = rand(0:1)
    @test insert!(b1, j, x) === b1
    insert!(i1, j, x)
    @test isequal(Array(b1), i1)
end

b1 = bitrand(v1)
i1 = Array(b1)
for m = v1 : -1 : 1
    j = rand(1:m)
    b = splice!(b1, j)
    i = splice!(i1, j)
    @test isequal(Array(b1), i1)
    @test b == i
end
@test length(b1) == 0

b1 = bitrand(v1)
i1 = Array(b1)
for m = v1 : -1 : 1
    j = rand(1:m)
    deleteat!(b1, j)
    deleteat!(i1, j)
    @test isequal(Array(b1), i1)
end
@test length(b1) == 0
b1 = bitrand(v1)
@test_throws ArgumentError deleteat!(b1,[1 1 2])
@test_throws BoundsError deleteat!(b1,[1 length(b1)+1])

b1 = bitrand(v1)
i1 = Array(b1)
for j in [63, 64, 65, 127, 128, 129, 191, 192, 193]
    b = splice!(b1, j)
    i = splice!(i1, j)
    @test isequal(Array(b1), i1)
    @test b == i
end

b1 = bitrand(v1)
i1 = Array(b1)
for j in [63, 64, 65, 127, 128, 129, 191, 192, 193]
    deleteat!(b1, j)
    deleteat!(i1, j)
    @test isequal(Array(b1), i1)
end

b1 = bitrand(v1)
i1 = Array(b1)
for m1 = 1 : v1
    for m2 = m1 : v1
        b2 = copy(b1)
        i2 = copy(i1)
        b = splice!(b2, m1:m2)
        i = splice!(i2, m1:m2)
        @test isequal(Array(b2), i2)
        @test b == i
    end
end

b1 = bitrand(v1)
i1 = Array(b1)
for m1 = 1 : v1
    for m2 = m1 : v1
        b2 = copy(b1)
        i2 = copy(i1)
        deleteat!(b2, m1:m2)
        deleteat!(i2, m1:m2)
        @test isequal(Array(b2), i2)
    end
end

b1 = bitrand(v1)
i1 = Array(b1)
for m1 = 1 : v1 + 1
    for m2 = m1 - 1 : v1
        for v2::Int = [0, 1, 63, 64, 65, 127, 128, 129, 191, 192, 193, rand(1:v1)]
            b2 = copy(b1)
            i2 = copy(i1)
            b3 = bitrand(v2)
            i3 = Array(b3)
            b = splice!(b2, m1:m2, b3)
            i = splice!(i2, m1:m2, i3)
            @test isequal(Array(b2), i2)
            @test b == i
            b2 = copy(b1)
            i2 = copy(i1)
            i3 = map(Int,bitrand(v2))
            b = splice!(b2, m1:m2, i3)
            i = splice!(i2, m1:m2, i3)
            @test isequal(Array(b2), i2)
            @test b == i
            b2 = copy(b1)
            i2 = copy(i1)
            i3 = Dict(j => rand(0:1) for j = 1:v2)
            b = splice!(b2, m1:m2, values(i3))
            i = splice!(i2, m1:m2, values(i3))
            @test isequal(Array(b2), i2)
            @test b == i
        end
    end
end

b1 = bitrand(v1)
i1 = Array(b1)
for m1 = 1 : v1
    for v2 = [0, 1, 63, 64, 65, 127, 128, 129, 191, 192, 193, rand(1:v1)]
        b2 = copy(b1)
        i2 = copy(i1)
        b3 = bitrand(v2)
        i3 = Array(b3)
        b = splice!(b2, m1, b3)
        i = splice!(i2, m1, i3)
        @test isequal(Array(b2), i2)
        @test b == i
        b2 = copy(b1)
        i2 = copy(i1)
        i3 = map(Int,bitrand(v2))
        b = splice!(b2, m1:m2, i3)
        i = splice!(i2, m1:m2, i3)
        @test isequal(Array(b2), i2)
        @test b == i
        b2 = copy(b1)
        i2 = copy(i1)
        i3 = Dict(j => rand(0:1) for j = 1:v2)
        b = splice!(b2, m1:m2, values(i3))
        i = splice!(i2, m1:m2, values(i3))
        @test isequal(Array(b2), i2)
        @test b == i
    end
end

b1 = bitrand(v1)
i1 = Array(b1)
for m1 = 1 : v1 - 1
    for m2 = m1 + 1 : v1
        locs = bitrand(m2-m1+1)
        m = [m1:m2...][locs]
        b2 = copy(b1)
        i2 = copy(i1)
        deleteat!(b2, m)
        deleteat!(i2, m)
        @test isequal(Array(b2), i2)
    end
end

b1 = bitrand(v1)
i1 = Array(b1)
empty!(b1)
empty!(i1)
@test isequal(Array(b1), i1)

timesofar("dequeue")

