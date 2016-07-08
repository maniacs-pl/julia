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

# vectors size
v1 = 260
# matrices size
n1, n2 = 17, 20
# arrays size
s1, s2, s3, s4 = 5, 8, 3, 7

allsizes = [((), BitArray{0}), ((v1,), BitVector),
            ((n1,n2), BitMatrix), ((s1,s2,s3,s4), BitArray{4})]


## Data movement ##

b1 = bitrand(s1, s2, s3, s4)
for d = 1 : 4
    j = rand(1:size(b1, d))
    #for j = 1 : size(b1, d)
        @check_bit_operation slicedim(b1, d, j) BitArray{4}
    #end
    @check_bit_operation flipdim(b1, d) BitArray{4}
end
@check_bit_operation flipdim(b1, 5) BitArray{4}

b1 = bitrand(n1, n2)
for k = 1 : 4
    @check_bit_operation rotl90(b1, k) BitMatrix
end

for m = 0 : v1
    b1 = bitrand(m)
    @check_bit_operation reverse(b1) BitVector
end

b1 = bitrand(v1)
for m = [rand(1:v1)-1 0 1 63 64 65 191 192 193 v1-1]
    @test isequal(b1 << m, [ b1[m+1:end]; falses(m) ])
    @test isequal(b1 >>> m, [ falses(m); b1[1:end-m] ])
    @test isequal(rol(b1, m), [ b1[m+1:end]; b1[1:m] ])
    @test isequal(ror(b1, m), [ b1[end-m+1:end]; b1[1:end-m] ])
    @test isequal(ror(b1, m), rol(b1, -m))
    @test isequal(rol(b1, m), ror(b1, -m))
end

b = bitrand(v1)
i = bitrand(v1)
for m = [rand(1:v1) 63 64 65 191 192 193 v1-1]
    j = rand(1:m)
    b1 = ror!(i, b, j)
    i1 = ror!(b, j)
    @test b1 == i1
    b2 = rol!(i1, b1, j)
    i2 = rol!(b1, j)
    @test b2 == i2
end

timesofar("datamove")

## countnz & find ##

for m = 0:v1, b1 in Any[bitrand(m), trues(m), falses(m)]
    @check_bit_operation countnz(b1) Int

    @check_bit_operation findfirst(b1) Int

    @check_bit_operation findfirst(b1, true)  Int
    @check_bit_operation findfirst(b1, false) Int
    @check_bit_operation findfirst(b1, 3)     Int

    @check_bit_operation findfirst(x->x, b1)     Int
    @check_bit_operation findfirst(x->!x, b1)    Int
    @check_bit_operation findfirst(x->true, b1)  Int
    @check_bit_operation findfirst(x->false, b1) Int

    @check_bit_operation find(b1) Vector{Int}
end

b1 = trues(v1)
for i = 0:v1-1
    @test findfirst(b1 >> i) == i+1
    @test Base.findfirstnot(~(b1 >> i)) == i+1
end

for i = 3:v1-1
    for j = 2:i
        submask = b1 << (v1-j+1)
        @test findnext((b1 >> i) | submask, j) == i+1
        @test Base.findnextnot((~(b1 >> i)) $ submask, j) == i+1
    end
end

b1 = bitrand(n1, n2)
@check_bit_operation findnz(b1) Tuple{Vector{Int}, Vector{Int}, BitArray}

timesofar("nnz&find")

## Findnext/findprev ##
B = trues(100)
B′ = falses(100)
for i=1:100
    @test findprev(B,i)     == findprev(B,true,i) == findprev(identity,B,i)
          Base.findprevnot(B′,i) == findprev(!,B′,i)   == i
end

odds = bitbroadcast(isodd, 1:2000)
evens = bitbroadcast(iseven, 1:2000)
for i=1:2:2000
    @test findprev(odds,i)  == Base.findprevnot(evens,i) == i
    @test findnext(odds,i)  == Base.findnextnot(evens,i) == i
    @test findprev(evens,i) == Base.findprevnot(odds,i)  == i-1
    @test findnext(evens,i) == Base.findnextnot(odds,i)  == (i < 2000 ? i+1 : 0)
end
for i=2:2:2000
    @test findprev(odds,i)  == Base.findprevnot(evens,i) == i-1
    @test findprev(evens,i) == Base.findprevnot(odds,i)  == i
    @test findnext(evens,i) == Base.findnextnot(odds,i)  == i
    @test findnext(odds,i)  == Base.findnextnot(evens,i) == (i < 2000 ? i+1 : 0)
end

elts = (1:64:64*64+1) .+ (0:64)
B1 = falses(maximum(elts))
B1[elts] = true
B1′ = ~B1
B2 = fill!(Array{Bool}(maximum(elts)), false)
B2[elts] = true
@test B1 == B2
@test all(B1 .== B2)
for i=1:length(maximum(elts))
    @test findprev(B1,i) == findprev(B2, i) == Base.findprevnot(B1′, i) == findprev(!, B1′, i)
    @test findnext(B1,i) == findnext(B2, i) == Base.findnextnot(B1′, i) == findnext(!, B1′, i)
end
B1 = ~B1
B2 = ~B2
B1′ = ~B1
@test B1 == B2
@test all(B1 .== B2)
for i=1:length(maximum(elts))
    @test findprev(B1,i) == findprev(B2, i) == Base.findprevnot(B1′, i) == findprev(!, B1′, i)
    @test findnext(B1,i) == findnext(B2, i) == Base.findnextnot(B1′, i) == findnext(!, B1′, i)
end

B = falses(1000)
B[77] = true
B[777] = true
B′ = ~B
@test_throws BoundsError findprev(B, 1001)
@test_throws BoundsError Base.findprevnot(B′, 1001)
@test_throws BoundsError findprev(!, B′, 1001)
@test_throws BoundsError findprev(identity, B, 1001)
@test_throws BoundsError findprev(x->false, B, 1001)
@test_throws BoundsError findprev(x->true, B, 1001)
@test findprev(B, 1000) == Base.findprevnot(B′, 1000) == findprev(!, B′, 1000) == 777
@test findprev(B, 777)  == Base.findprevnot(B′, 777)  == findprev(!, B′, 777)  == 777
@test findprev(B, 776)  == Base.findprevnot(B′, 776)  == findprev(!, B′, 776)  == 77
@test findprev(B, 77)   == Base.findprevnot(B′, 77)   == findprev(!, B′, 77)   == 77
@test findprev(B, 76)   == Base.findprevnot(B′, 76)   == findprev(!, B′, 76)   == 0
@test findprev(B, -1)   == Base.findprevnot(B′, -1)   == findprev(!, B′, -1)   == 0
@test findprev(identity, B, -1) == findprev(x->false, B, -1) == findprev(x->true, B, -1) == 0
@test_throws BoundsError findnext(B, -1)
@test_throws BoundsError Base.findnextnot(B′, -1)
@test_throws BoundsError findnext(!, B′, -1)
@test_throws BoundsError findnext(identity, B, -1)
@test_throws BoundsError findnext(x->false, B, -1)
@test_throws BoundsError findnext(x->true, B, -1)
@test findnext(B, 1)    == Base.findnextnot(B′, 1)    == findnext(!, B′, 1)    == 77
@test findnext(B, 77)   == Base.findnextnot(B′, 77)   == findnext(!, B′, 77)   == 77
@test findnext(B, 78)   == Base.findnextnot(B′, 78)   == findnext(!, B′, 78)   == 777
@test findnext(B, 777)  == Base.findnextnot(B′, 777)  == findnext(!, B′, 777)  == 777
@test findnext(B, 778)  == Base.findnextnot(B′, 778)  == findnext(!, B′, 778)  == 0
@test findnext(B, 1001) == Base.findnextnot(B′, 1001) == findnext(!, B′, 1001) == 0
@test findnext(identity, B, 1001) == findnext(x->false, B, 1001) == findnext(x->true, B, 1001) == 0

@test findlast(B) == Base.findlastnot(B′) == 777
@test findfirst(B) == Base.findfirstnot(B′) == 77

emptyvec = BitVector(0)
@test findprev(x->true, emptyvec, -1) == 0
@test_throws BoundsError findprev(x->true, emptyvec, 1)
@test_throws BoundsError findnext(x->true, emptyvec, -1)
@test findnext(x->true, emptyvec, 1) == 0

B = falses(10)
@test findprev(x->true, B, 5) == 5
@test findnext(x->true, B, 5) == 5
@test findprev(x->true, B, -1) == 0
@test findnext(x->true, B, 11) == 0
@test findprev(x->false, B, 5) == 0
@test findnext(x->false, B, 5) == 0
@test findprev(x->false, B, -1) == 0
@test findnext(x->false, B, 11) == 0
@test_throws BoundsError findprev(x->true, B, 11)
@test_throws BoundsError findnext(x->true, B, -1)

for l = [1,63,64,65,127,128,129]
    f = falses(l)
    t = trues(l)
    @test findprev(f, l) == Base.findprevnot(t, l) == 0
    @test findprev(t, l) == Base.findprevnot(f, l) == l
    B = falses(l)
    B[end] = true
    B′ = ~B
    @test findprev(B, l) == Base.findprevnot(B′, l) == l
    @test Base.findprevnot(B, l) == findprev(B′, l) == l-1
    if l > 1
        B = falses(l)
        B[end-1] = true
        B′ = ~B
        @test findprev(B, l) == Base.findprevnot(B′, l) == l-1
        @test Base.findprevnot(B, l) == findprev(B′, l) == l
    end
end

## Reductions ##

let
    b1 = bitrand(s1, s2, s3, s4)
    m1 = 1
    m2 = 3
    @check_bit_operation maximum(b1, (m1, m2)) BitArray{4}
    @check_bit_operation minimum(b1, (m1, m2)) BitArray{4}
    @check_bit_operation sum(b1, (m1, m2)) Array{Int,4}

    @check_bit_operation maximum(b1) Bool
    @check_bit_operation minimum(b1) Bool
    @check_bit_operation any(b1) Bool
    @check_bit_operation all(b1) Bool
    @check_bit_operation sum(b1) Int

    b0 = falses(0)
    @check_bit_operation any(b0) Bool
    @check_bit_operation all(b0) Bool
    @check_bit_operation sum(b0) Int
end

timesofar("reductions")

## map over bitarrays ##

p = falses(4)
q = falses(4)
p[1:2] = true
q[[1,3]] = true

@test map(~, p) == map(x->~x, p) == ~p
@test map(identity, p) == map(x->x, p) == p

@test map(&, p, q) == map((x,y)->x&y, p, q) == p & q
@test map(|, p, q) == map((x,y)->x|y, p, q) == p | q
@test map($, p, q) == map((x,y)->x$y, p, q) == p $ q

@test map(^, p, q) == map((x,y)->x^y, p, q) == p .^ q
@test map(*, p, q) == map((x,y)->x*y, p, q) == p .* q

@test map(min, p, q) == map((x,y)->min(x,y), p, q) == min(p, q)
@test map(max, p, q) == map((x,y)->max(x,y), p, q) == max(p, q)

@test map(<, p, q)  == map((x,y)->x<y, p, q)  == (p .< q)
@test map(<=, p, q) == map((x,y)->x<=y, p, q) == (p .<= q)
@test map(==, p, q) == map((x,y)->x==y, p, q) == (p .== q)
@test map(>=, p, q) == map((x,y)->x>=y, p, q) == (p .>= q)
@test map(>, p, q)  == map((x,y)->x>y, p, q)  == (p .> q)
@test map(!=, p, q) == map((x,y)->x!=y, p, q) == (p .!= q)

# map!
r = falses(4)
@test map!(~, r, p) == map!(x->~x, r, p) == ~p == r
@test map!(!, r, p) == map!(x->!x, r, p) == ~p == r
@test map!(identity, r, p) == map!(x->x, r, p) == p == r
@test map!(zero, r, p) == map!(x->false, r, p) == falses(4) == r
@test map!(one, r, p) == map!(x->true, r, p) == trues(4) == r

@test map!(&, r, p, q) == map!((x,y)->x&y, r, p, q) == p & q == r
@test map!(|, r, p, q) == map!((x,y)->x|y, r, p, q) == p | q == r
@test map!($, r, p, q) == map!((x,y)->x$y, r, p, q) == p $ q == r

@test map!(^, r, p, q) == map!((x,y)->x^y, r, p, q) == p .^ q == r
@test map!(*, r, p, q) == map!((x,y)->x*y, r, p, q) == p .* q == r

@test map!(min, r, p, q) == map!((x,y)->min(x,y), r, p, q) == min(p, q) == r
@test map!(max, r, p, q) == map!((x,y)->max(x,y), r, p, q) == max(p, q) == r

@test map!(<, r, p, q)  == map!((x,y)->x<y, r, p, q)  == (p .< q)  == r
@test map!(<=, r, p, q) == map!((x,y)->x<=y, r, p, q) == (p .<= q) == r
@test map!(==, r, p, q) == map!((x,y)->x==y, r, p, q) == (p .== q) == r
@test map!(>=, r, p, q) == map!((x,y)->x>=y, r, p, q) == (p .>= q) == r
@test map!(>, r, p, q)  == map!((x,y)->x>y, r, p, q)  == (p .> q)  == r
@test map!(!=, r, p, q) == map!((x,y)->x!=y, r, p, q) == (p .!= q) == r

for l=[0,1,63,64,65,127,128,129,255,256,257,6399,6400,6401]
    p = bitrand(l)
    q = bitrand(l)
    @test map(~, p) == ~p
    @test map(identity, p) == p
    @test map(&, p, q) == p & q
    @test map(|, p, q) == p | q
    @test map($, p, q) == p $ q
    r = BitVector(l)
    @test map!(~, r, p) == ~p == r
    @test map!(identity, r, p) == p == r
    @test map!(~, r) == ~p == r
    @test map!(&, r, p, q) == p & q == r
    @test map!(|, r, p, q) == p | q == r
    @test map!($, r, p, q) == p $ q == r
end

## Filter ##

# TODO

## Transpose ##

b1 = bitrand(v1)
@check_bit_operation transpose(b1) BitMatrix

for m1 = 0 : n1
    for m2 = 0 : n2
        b1 = bitrand(m1, m2)
        @check_bit_operation transpose(b1) BitMatrix
    end
end

timesofar("transpose")

## Permutedims ##

b1 = bitrand(s1, s2, s3, s4)
p = randperm(4)
@check_bit_operation permutedims(b1, p) BitArray{4}
@check_bit_operation permutedims(b1, tuple(p...)) BitArray{4}

timesofar("permutedims")

## Concatenation ##

b1 = bitrand(v1)
b2 = bitrand(v1)
@check_bit_operation hcat(b1, b2) BitMatrix
for m = 1 : v1 - 1
    @check_bit_operation vcat(b1[1:m], b1[m+1:end]) BitVector
end
@test_throws DimensionMismatch hcat(b1,trues(n1+1))
@test_throws DimensionMismatch hcat(hcat(b1, b2),trues(n1+1))

b1 = bitrand(n1, n2)
b2 = bitrand(n1)
b3 = bitrand(n1, n2)
b4 = bitrand(1, n2)
@check_bit_operation hcat(b1, b2, b3) BitMatrix
@check_bit_operation vcat(b1, b4, b3) BitMatrix
@test_throws DimensionMismatch vcat(b1, b4, trues(n1,n2+1))

b1 = bitrand(s1, s2, s3, s4)
b2 = bitrand(s1, s3, s3, s4)
b3 = bitrand(s1, s2, s3, s1)
@check_bit_operation cat(2, b1, b2) BitArray{4}
@check_bit_operation cat(4, b1, b3) BitArray{4}
@check_bit_operation cat(6, b1, b1) BitArray{6}

b1 = bitrand(1, v1, 1)
@check_bit_operation cat(2, 0, b1, 1, 1, b1) Array{Int,3}
@check_bit_operation cat(2, 3, b1, 4, 5, b1) Array{Int,3}
@check_bit_operation cat(2, false, b1, true, true, b1) BitArray{3}

b1 = bitrand(n1, n2)
for m1 = 1 : n1 - 1
    for m2 = 1 : n2 - 1
        @test isequal([b1[1:m1,1:m2] b1[1:m1,m2+1:end]; b1[m1+1:end,1:m2] b1[m1+1:end,m2+1:end]], b1)
    end
end

timesofar("cat")

# issue #7515
@test sizeof(BitArray(64)) == 8
@test sizeof(BitArray(65)) == 16

#one
@test Array(one(BitMatrix(2,2))) == eye(2,2)
@test_throws DimensionMismatch one(BitMatrix(2,3))

#reshape
a = trues(2,5)
b = reshape(a,(5,2))
@test b == trues(5,2)
@test_throws DimensionMismatch reshape(a, (1,5))

#resize!

a = trues(5)
@test_throws BoundsError resize!(a,-1)
resize!(a, 3)
@test a == trues(3)
resize!(a, 5)
@test a == append!(trues(3),falses(2))

#flipbits!

a = trues(5,5)
flipbits!(a)
@test a == falses(5,5)

# findmax, findmin
a = trues(0)
@test_throws ArgumentError findmax(a)
@test_throws ArgumentError findmin(a)

a = falses(6)
@test findmax(a) == (false,1)
a = trues(6)
@test findmin(a) == (true,1)
a = BitArray([1,0,1,1,0])
@test findmin(a) == (false,2)
@test findmax(a) == (true,1)
a = BitArray([0,0,1,1,0])
@test findmin(a) == (false,1)
@test findmax(a) == (true,3)

# test non-Int dims constructor
A = BitArray(Int32(10))
B = BitArray(Int64(10))
@test A == B

A = trues(Int32(10))
B = trues(Int64(10))
@test A == B

A = falses(Int32(10))
B = falses(Int64(10))
@test A == B
