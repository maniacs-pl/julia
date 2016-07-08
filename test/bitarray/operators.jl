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


## Unary operators ##

b1 = bitrand(n1, n2)
@check_bit_operation (~)(b1)  BitMatrix
@check_bit_operation (!)(b1)  BitMatrix
@check_bit_operation (-)(b1)  Matrix{Int}
@check_bit_operation sign(b1) BitMatrix
@check_bit_operation real(b1) BitMatrix
@check_bit_operation imag(b1) BitMatrix
@check_bit_operation conj(b1) BitMatrix

b0 = falses(0)
@check_bit_operation (~)(b0)  BitVector
@check_bit_operation (!)(b0)  BitVector
@check_bit_operation (-)(b0)  Vector{Int}
@check_bit_operation sign(b0) BitVector

timesofar("unary arithmetic")

## Binary arithmetic operators ##

# Matrix{Bool}/Matrix{Bool}

b1 = bitrand(n1, n2)
b2 = bitrand(n1, n2)
@check_bit_operation (&)(b1, b2)  BitMatrix
@check_bit_operation (|)(b1, b2)  BitMatrix
@check_bit_operation ($)(b1, b2)  BitMatrix
@check_bit_operation (+)(b1, b2)  Matrix{Int}
@check_bit_operation (-)(b1, b2)  Matrix{Int}
@check_bit_operation (.*)(b1, b2) BitMatrix
@check_bit_operation (./)(b1, b2) Matrix{Float64}
@check_bit_operation (.^)(b1, b2) BitMatrix
@check_bit_operation (/)(b1,1) Matrix{Float64}

b2 = trues(n1, n2)
@check_bit_operation div(b1, b2) BitMatrix
@check_bit_operation mod(b1, b2) BitMatrix
@check_bit_operation div(b1,Array(b2)) BitMatrix
@check_bit_operation mod(b1,Array(b2)) BitMatrix
@check_bit_operation div(Array(b1),b2) BitMatrix
@check_bit_operation mod(Array(b1),b2) BitMatrix

while true
    global b1
    b1 = bitrand(n1, n1)
    if abs(det(Array{Float64}(b1))) > 1e-6
        break
    end
end
b2 = bitrand(n1, n1)

@check_bit_operation (*)(b1, b2) Matrix{Int}
@check_bit_operation (/)(b1, b1) Matrix{Float64}
@check_bit_operation (\)(b1, b1) Matrix{Float64}

b0 = falses(0)
@check_bit_operation (&)(b0, b0)  BitVector
@check_bit_operation (|)(b0, b0)  BitVector
@check_bit_operation ($)(b0, b0)  BitVector
@check_bit_operation (.*)(b0, b0) BitVector
@check_bit_operation (*)(b0, b0') Matrix{Int}

# Matrix{Bool}/Matrix{Int}
b1 = bitrand(n1, n2)
i2 = rand(1:10, n1, n2)
@check_bit_operation (&)(b1, i2)  Matrix{Int}
@check_bit_operation (|)(b1, i2)  Matrix{Int}
@check_bit_operation ($)(b1, i2)  Matrix{Int}
@check_bit_operation (+)(b1, i2)  Matrix{Int}
@check_bit_operation (-)(b1, i2)  Matrix{Int}
@check_bit_operation (.*)(b1, i2) Matrix{Int}
@check_bit_operation (./)(b1, i2) Matrix{Float64}
@check_bit_operation (.^)(b1, i2) BitMatrix
@check_bit_operation div(b1, i2)  Matrix{Int}
@check_bit_operation mod(b1, i2)  Matrix{Int}

# Matrix{Bool}/Matrix{Float64}
b1 = bitrand(n1, n2)
f2 = 1.0 .+ rand(n1, n2)
@check_bit_operation (.*)(b1, f2) Matrix{Float64}
@check_bit_operation (./)(b1, f2) Matrix{Float64}
@check_bit_operation (.^)(b1, f2) Matrix{Float64}
@check_bit_operation div(b1, f2)  Matrix{Float64}
@check_bit_operation mod(b1, f2)  Matrix{Float64}

# Number/Matrix
b2 = bitrand(n1, n2)
i1 = rand(1:10)
u1 = UInt8(i1)
f1 = Float64(i1)
ci1 = complex(i1)
cu1 = complex(u1)
cf1 = complex(f1)

@check_bit_operation (&)(i1, b2)  Matrix{Int}
@check_bit_operation (|)(i1, b2)  Matrix{Int}
@check_bit_operation ($)(i1, b2)  Matrix{Int}
@check_bit_operation (.+)(i1, b2)  Matrix{Int}
@check_bit_operation (.-)(i1, b2)  Matrix{Int}
@check_bit_operation (.*)(i1, b2) Matrix{Int}

@check_bit_operation (&)(u1, b2)  Matrix{UInt8}
@check_bit_operation (|)(u1, b2)  Matrix{UInt8}
@check_bit_operation ($)(u1, b2)  Matrix{UInt8}
@check_bit_operation (.+)(u1, b2)  Matrix{UInt8}
@check_bit_operation (.-)(u1, b2)  Matrix{UInt8}
@check_bit_operation (.*)(u1, b2) Matrix{UInt8}

for (x1,t1) = [(f1, Float64),
               (ci1, Complex{Int}),
               (cu1, Complex{UInt8}),
               (cf1, Complex128)]
    @check_bit_operation (.+)(x1, b2)  Matrix{t1}
    @check_bit_operation (.-)(x1, b2)  Matrix{t1}
    @check_bit_operation (.*)(x1, b2) Matrix{t1}
end

b2 = trues(n1, n2)
@check_bit_operation (./)(true, b2)  Matrix{Float64}
@check_bit_operation div(true, b2)   BitMatrix
@check_bit_operation mod(true, b2)   BitMatrix
@check_bit_operation (./)(false, b2) Matrix{Float64}
@check_bit_operation div(false, b2)  BitMatrix
@check_bit_operation mod(false, b2)  BitMatrix

@check_bit_operation (./)(i1, b2) Matrix{Float64}
@check_bit_operation div(i1, b2)  Matrix{Int}
@check_bit_operation mod(i1, b2)  Matrix{Int}

@check_bit_operation (./)(u1, b2) Matrix{Float64}
@check_bit_operation div(u1, b2)  Matrix{UInt8}
@check_bit_operation mod(u1, b2)  Matrix{UInt8}

@check_bit_operation (./)(f1, b2) Matrix{Float64}
@check_bit_operation div(f1, b2)  Matrix{Float64}
@check_bit_operation mod(f1, b2)  Matrix{Float64}

@check_bit_operation (./)(ci1, b2) Matrix{Complex128}
@check_bit_operation (./)(cu1, b2) Matrix{Complex128}
@check_bit_operation (./)(cf1, b2) Matrix{Complex128}

b2 = bitrand(n1, n2)
@check_bit_operation (.^)(false, b2) BitMatrix
@check_bit_operation (.^)(true, b2)  BitMatrix
@check_bit_operation (.^)(0x0, b2)   Matrix{UInt8}
@check_bit_operation (.^)(0x1, b2)   Matrix{UInt8}
@check_bit_operation (.^)(-1, b2)    Matrix{Int}
@check_bit_operation (.^)(0, b2)     Matrix{Int}
@check_bit_operation (.^)(1, b2)     Matrix{Int}
@check_bit_operation (.^)(0.0, b2)   Matrix{Float64}
@check_bit_operation (.^)(1.0, b2)   Matrix{Float64}
@check_bit_operation (.^)(0.0im, b2) Matrix{Complex128}
@check_bit_operation (.^)(1.0im, b2) Matrix{Complex128}
@check_bit_operation (.^)(0im, b2)   Matrix{Complex{Int}}
@check_bit_operation (.^)(1im, b2)   Matrix{Complex{Int}}
@check_bit_operation (.^)(0x0im, b2) Matrix{Complex{UInt8}}
@check_bit_operation (.^)(0x1im, b2) Matrix{Complex{UInt8}}

# Matrix/Number
b1 = bitrand(n1, n2)
i2 = rand(1:10)
u2 = UInt8(i2)
f2 = Float64(i2)
ci2 = complex(i2)
cu2 = complex(u2)
cf2 = complex(f2)
b2 = Array(bitrand(n1,n2))

@check_bit_operation (&)(b1, true)   BitMatrix
@check_bit_operation (&)(b1, false)  BitMatrix
@check_bit_operation (&)(true, b1)   BitMatrix
@check_bit_operation (&)(false, b1)  BitMatrix
@check_bit_operation (|)(b1, true)   BitMatrix
@check_bit_operation (|)(b1, false)  BitMatrix
@check_bit_operation (|)(true, b1)   BitMatrix
@check_bit_operation (|)(false, b1)  BitMatrix
@check_bit_operation ($)(b1, true)   BitMatrix
@check_bit_operation ($)(b1, false)  BitMatrix
@check_bit_operation ($)(true, b1)   BitMatrix
@check_bit_operation ($)(false, b1)  BitMatrix
@check_bit_operation (.+)(b1, true)   Matrix{Int}
@check_bit_operation (.+)(b1, false)  Matrix{Int}
@check_bit_operation (.-)(b1, true)   Matrix{Int}
@check_bit_operation (.-)(b1, false)  Matrix{Int}
@check_bit_operation (.*)(b1, true)  BitMatrix
@check_bit_operation (.*)(b1, false) BitMatrix
@check_bit_operation (.*)(true, b1)  BitMatrix
@check_bit_operation (.*)(false, b1) BitMatrix
@check_bit_operation (./)(b1, true)  Matrix{Float64}
@check_bit_operation (./)(b1, false) Matrix{Float64}
@check_bit_operation div(b1, true)   BitMatrix
@check_bit_operation mod(b1, true)   BitMatrix

@check_bit_operation (&)(b1, b2)  BitMatrix
@check_bit_operation (|)(b1, b2)  BitMatrix
@check_bit_operation ($)(b1, b2)  BitMatrix
@check_bit_operation (&)(b2, b1)  BitMatrix
@check_bit_operation (|)(b2, b1)  BitMatrix
@check_bit_operation ($)(b2, b1)  BitMatrix
@check_bit_operation (&)(b1, i2)  Matrix{Int}
@check_bit_operation (|)(b1, i2)  Matrix{Int}
@check_bit_operation ($)(b1, i2)  Matrix{Int}
@check_bit_operation (.+)(b1, i2)  Matrix{Int}
@check_bit_operation (.-)(b1, i2)  Matrix{Int}
@check_bit_operation (.*)(b1, i2) Matrix{Int}
@check_bit_operation (./)(b1, i2) Matrix{Float64}
@check_bit_operation div(b1, i2)  Matrix{Int}
@check_bit_operation mod(b1, i2)  Matrix{Int}

@check_bit_operation (&)(b1, u2)  Matrix{UInt8}
@check_bit_operation (|)(b1, u2)  Matrix{UInt8}
@check_bit_operation ($)(b1, u2)  Matrix{UInt8}
@check_bit_operation (.+)(b1, u2)  Matrix{UInt8}
@check_bit_operation (.-)(b1, u2)  Matrix{UInt8}
@check_bit_operation (.*)(b1, u2) Matrix{UInt8}
@check_bit_operation (./)(b1, u2) Matrix{Float64}
@check_bit_operation div(b1, u2)  Matrix{UInt8}
@check_bit_operation mod(b1, u2)  Matrix{UInt8}

@check_bit_operation (.+)(b1, f2)  Matrix{Float64}
@check_bit_operation (.-)(b1, f2)  Matrix{Float64}
@check_bit_operation (.*)(b1, f2) Matrix{Float64}
@check_bit_operation (./)(b1, f2) Matrix{Float64}
@check_bit_operation div(b1, f2)  Matrix{Float64}
@check_bit_operation mod(b1, f2)  Matrix{Float64}

@check_bit_operation (.+)(b1, ci2)  Matrix{Complex{Int}}
@check_bit_operation (.-)(b1, ci2)  Matrix{Complex{Int}}
@check_bit_operation (.*)(b1, ci2) Matrix{Complex{Int}}
@check_bit_operation (./)(b1, ci2) Matrix{Complex128}

@check_bit_operation (.+)(b1, cu2)  Matrix{Complex{UInt8}}
@check_bit_operation (.-)(b1, cu2)  Matrix{Complex{UInt8}}
@check_bit_operation (.*)(b1, cu2) Matrix{Complex{UInt8}}
@check_bit_operation (./)(b1, cu2) Matrix{Complex128}

@check_bit_operation (.+)(b1, cf2)  Matrix{Complex128}
@check_bit_operation (.-)(b1, cf2)  Matrix{Complex128}
@check_bit_operation (.*)(b1, cf2) Matrix{Complex128}
@check_bit_operation (./)(b1, cf2) Matrix{Complex128}

@check_bit_operation (.^)(b1, false) BitMatrix
@check_bit_operation (.^)(b1, true)  BitMatrix
@check_bit_operation (.^)(b1, 0x0)   BitMatrix
@check_bit_operation (.^)(b1, 0x1)   BitMatrix
@check_bit_operation (.^)(b1, 0)     BitMatrix
@check_bit_operation (.^)(b1, 1)     BitMatrix
@check_bit_operation (.^)(b1, -1.0)  Matrix{Float64}
@check_bit_operation (.^)(b1, 0.0)   Matrix{Float64}
@check_bit_operation (.^)(b1, 1.0)   Matrix{Float64}
@check_bit_operation (.^)(b1, 0.0im) Matrix{Complex128}
@check_bit_operation (.^)(b1, 0x0im) Matrix{Complex128}
@check_bit_operation (.^)(b1, 0im)   Matrix{Complex128}
@test_throws DomainError (.^)(b1, -1)

b1 = trues(n1, n2)
@check_bit_operation (.^)(b1, -1.0im) Matrix{Complex128}
@check_bit_operation (.^)(b1, 1.0im)  Matrix{Complex128}
@check_bit_operation (.^)(b1, -1im)   Matrix{Complex128}
@check_bit_operation (.^)(b1, 1im)    Matrix{Complex128}
@check_bit_operation (.^)(b1, 0x1im)  Matrix{Complex128}

timesofar("binary arithmetic")

## Binary comparison operators ##

b1 = bitrand(n1, n2)
b2 = bitrand(n1, n2)
@check_bit_operation (.==)(b1, b2) BitMatrix
@check_bit_operation (.!=)(b1, b2) BitMatrix
@check_bit_operation (.<)(b1, b2) BitMatrix
@check_bit_operation (.<=)(b1, b2) BitMatrix

timesofar("binary comparison")

