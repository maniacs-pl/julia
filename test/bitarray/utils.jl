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

# vectors size
v1 = 260
# matrices size
n1, n2 = 17, 20
# arrays size
s1, s2, s3, s4 = 5, 8, 3, 7

allsizes = [((), BitArray{0}), ((v1,), BitVector),
            ((n1,n2), BitMatrix), ((s1,s2,s3,s4), BitArray{4})]

b1 = bitrand(v1)
@test isequal(fill!(b1, true), trues(size(b1)))
@test isequal(fill!(b1, false), falses(size(b1)))

for (sz,T) in allsizes
    @test isequal(Array(trues(sz...)), ones(Bool, sz...))
    @test isequal(Array(falses(sz...)), zeros(Bool, sz...))

    b1 = rand!(falses(sz...))
    @test isa(b1, T)

    @check_bit_operation length(b1) Int
    @check_bit_operation ndims(b1)  Int
    @check_bit_operation size(b1)   Tuple{Vararg{Int}}

    b2 = similar(b1)
    u1 = Array(b1)
    @check_bit_operation copy!(b2, b1) T
    @check_bit_operation copy!(b2, u1) T
end

for n in [1; 1023:1025]
    b1 = falses(n)
    for m in [1; 10; 1023:1025]
        u1 = ones(Bool, m)
        for fu! in [u->fill!(u, true), u->rand!(u)]
            fu!(u1)
            c1 = convert(Vector{Int}, u1)
            for i1 in [1; 10; 53:65; 1013:1015; 1020:1025], i2 in [1; 3; 10; 511:513], l in [1; 5; 10; 511:513; 1023:1025]
                for fb! in [b->fill!(b, false), b->rand!(b)]
                    fb!(b1)
                    if i1 < 1 || i1 > n || (i2 + l - 1 > m) || (i1 + l - 1 > n)
                        @test_throws BoundsError copy!(b1, i1, u1, i2, l)
                    else
                        @check_bit_operation copy!(b1, i1, u1, i2, l) BitArray
                        @check_bit_operation copy!(b1, i1, c1, i2, l) BitArray
                    end
                end
            end
        end
    end
end

@test_throws BoundsError size(trues(5),0)

