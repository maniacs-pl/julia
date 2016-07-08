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

# Linear algebra

b1 = bitrand(v1)
b2 = bitrand(v1)
@check_bit_operation dot(b1, b2) Int

b1 = bitrand(n1, n2)
for k = -n1 : n2
    @check_bit_operation tril(b1, k) BitMatrix
    @check_bit_operation triu(b1, k) BitMatrix
end

b1 = bitrand(n1, n1)
@check_bit_operation istril(b1) Bool
b1 = bitrand(n1, n2)
@check_bit_operation istril(b1) Bool
b1 = bitrand(n2, n1)
@check_bit_operation istril(b1) Bool

b1 = tril(bitrand(n1, n1))
@check_bit_operation istril(b1) Bool
b1 = tril(bitrand(n1, n2))
@check_bit_operation istril(b1) Bool
b1 = tril(bitrand(n2, n1))
@check_bit_operation istril(b1) Bool

b1 = bitrand(n1, n1)
@check_bit_operation istriu(b1) Bool
b1 = bitrand(n1, n2)
@check_bit_operation istriu(b1) Bool
b1 = bitrand(n2, n1)
@check_bit_operation istriu(b1) Bool

b1 = triu(bitrand(n1, n1))
@check_bit_operation istriu(b1) Bool
b1 = triu(bitrand(n1, n2))
@check_bit_operation istriu(b1) Bool
b1 = triu(bitrand(n2, n1))
@check_bit_operation istriu(b1) Bool

b1 = bitrand(n1,n1)
b1 |= b1.'
@check_bit_operation issymmetric(b1) Bool
@check_bit_operation ishermitian(b1) Bool

b1 = bitrand(n1)
b2 = bitrand(n2)
@check_bit_operation kron(b1, b2) BitVector

b1 = bitrand(s1, s2)
b2 = bitrand(s3, s4)
@check_bit_operation kron(b1, b2) BitMatrix

#b1 = bitrand(v1)
#@check_bit_operation diff(b1) Vector{Int}
#b1 = bitrand(n1, n2)
#@check_bit_operation diff(b1) Vector{Int}

timesofar("linalg")

#qr and svd

A = bitrand(10,10)
uA = Array(A)
@test svd(A) == svd(uA)
@test qr(A) == qr(uA)

#gradient
A = bitrand(10)
fA = Array(A)
@test gradient(A) == gradient(fA)
@test gradient(A,1.0) == gradient(fA,1.0)

#diag and diagm

v = bitrand(10)
uv = Array(v)
@test Array(diagm(v)) == diagm(uv)
v = bitrand(10,2)
uv = Array(v)
@test_throws DimensionMismatch diagm(v)

B = bitrand(10,10)
uB = Array(B)
@test diag(uB) == Array(diag(B))

