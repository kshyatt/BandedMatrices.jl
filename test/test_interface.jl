using BandedMatrices, LinearAlgebra, LazyArrays, Test
import BandedMatrices: banded_mul!, isbanded, AbstractBandedLayout, BandedStyle
import LazyArrays: MemoryLayout


struct PseudoBandedMatrix{T} <: AbstractMatrix{T}
    data::Array{T}
    l::Int
    u::Int
end


Base.size(A::PseudoBandedMatrix) = size(A.data)
function Base.getindex(A::PseudoBandedMatrix, j::Int, k::Int)
    l, u = bandwidths(A)
    if -l ≤ k-j ≤ u
        A.data[j, k]
    else
        zero(eltype(A.data))
    end
end
function Base.setindex!(A::PseudoBandedMatrix, v, j::Int, k::Int)
    l, u = bandwidths(A)
    if -l ≤ k-j ≤ u
        A.data[j, k] = v
    else
        error("out of band.")
    end
end

struct PseudoBandedLayout <: AbstractBandedLayout end
Base.BroadcastStyle(::Type{<:PseudoBandedMatrix}) = BandedStyle()
BandedMatrices.MemoryLayout(::PseudoBandedMatrix) = PseudoBandedLayout()
BandedMatrices.isbanded(::PseudoBandedMatrix) = true
BandedMatrices.bandwidths(A::PseudoBandedMatrix) = (A.l , A.u)
BandedMatrices.inbands_getindex(A::PseudoBandedMatrix, j::Int, k::Int) = A.data[j, k]
BandedMatrices.inbands_setindex!(A::PseudoBandedMatrix, v, j::Int, k::Int) = setindex!(A.data, v, j, k)

@testset "banded matrix interface" begin
    @test isbanded(Zeros(5,6))
    @test bandwidths(Zeros(5,6)) == (0,0)
    @test BandedMatrices.inbands_getindex(Zeros(5,6), 1,2) == 0

    @test isbanded(Eye(5))
    @test bandwidths(Eye(5)) == (0,0)
    @test BandedMatrices.inbands_getindex(Eye(5), 1,1) == 1

    A = Diagonal(ones(5,5))
    @test isbanded(A)
    @test bandwidths(A) == (0,0)
    @test BandedMatrices.inbands_getindex(A, 1,1) == 1
    BandedMatrices.inbands_setindex!(A, 2, 1,1)
    @test A[1,1] == 2
    @test A[1,2] == 0
    @test BandedMatrices.@inbands(A[1,2]) == 2

    A = SymTridiagonal([1,2,3],[4,5])
    @test isbanded(A)
    @test bandwidths(A) == (1,1)
    @test BandedMatrices.inbands_getindex(A, 1,1) == 1
    BandedMatrices.inbands_setindex!(A, 2, 1,1)
    @test A[1,1] == 2

    A = PseudoBandedMatrix(rand(5, 4), 2, 2)
    B = rand(5, 4)
    C = copy(B)

    @test Matrix(B .= 2.0 .* A .+ B) ≈ 2*Matrix(A) + C

    A = PseudoBandedMatrix(rand(5, 4), 1, 2)
    B = (z -> exp(z)-1).(A)
    @test B isa BandedMatrix
    @test bandwidths(B) == bandwidths(A)
    @test B == (z -> exp(z)-1).(Matrix(A))

    A = PseudoBandedMatrix(rand(5, 4), 1, 2)
    B = A .* 2
    @test B isa BandedMatrix
    @test bandwidths(B) == bandwidths(A)
    @test B == 2Matrix(A) == (2 .* A)

    A = PseudoBandedMatrix(rand(5, 4), 1, 2)
    B = PseudoBandedMatrix(rand(5, 4), 2, 1)

    @test A .+ B isa BandedMatrix
    @test bandwidths(A .+ B) == (2,2)
    @test A .+ B == Matrix(A) + Matrix(B)

    A = PseudoBandedMatrix(rand(5, 4), 1, 2)
    B = PseudoBandedMatrix(rand(5, 4), 2, 3)
    C = deepcopy(B)
    @test Matrix(C .= 2.0 .* A .+ C) ≈ 2*Matrix(A) + B ≈ 2*A + Matrix(B) ≈ 2*Matrix(A) + Matrix(B) ≈ 2*A + B

    y = rand(4)
    z = zeros(5)
    z .= Mul(A, y)
    @test z ≈ A*y ≈ Matrix(A)*y

    B = PseudoBandedMatrix(rand(4, 4), 2, 3)
    C = PseudoBandedMatrix(zeros(5, 4), 3, 4)
    D = zeros(5, 4)

    @test (C .= Mul(A, B)) ≈ (D .= Mul(A, B)) ≈ A*B

    @test bandwidths(BandedMatrix(A)) ==
            bandwidths(BandedMatrix{Float64}(A)) ==
            bandwidths(BandedMatrix{Float64,Matrix{Float64}}(A)) ==
            bandwidths(convert(BandedMatrix{Float64}, A)) ==
            bandwidths(convert(BandedMatrix{Float64,Matrix{Float64}},A)) ==
            bandwidths(A)
end


@testset "Diagonal interface" begin
    D = Diagonal(randn(5))
    @test bandwidths(D) == (0,0)

    A =  brand(5,5,1,1)

    @test A*D isa BandedMatrix
    @test A*D == Matrix(A)*D

    @test D*A isa BandedMatrix
    @test D*A == D*Matrix(A)

    D = Diagonal(rand(Int,10))
    B = brand(10,10,-1,2)
    J = SymTridiagonal(randn(10), randn(9))
    T = Tridiagonal(randn(9), randn(10), randn(9))
    @test Base.BroadcastStyle(Base.BroadcastStyle(typeof(B)), Base.BroadcastStyle(typeof(D))) ==
        Base.BroadcastStyle(Base.BroadcastStyle(typeof(D)), Base.BroadcastStyle(typeof(B))) ==
        Base.BroadcastStyle(Base.BroadcastStyle(typeof(B)), Base.BroadcastStyle(typeof(T))) ==
        Base.BroadcastStyle(Base.BroadcastStyle(typeof(T)), Base.BroadcastStyle(typeof(B))) ==
        Base.BroadcastStyle(Base.BroadcastStyle(typeof(B)), Base.BroadcastStyle(typeof(J))) ==
        Base.BroadcastStyle(Base.BroadcastStyle(typeof(J)), Base.BroadcastStyle(typeof(B))) ==
            BandedStyle()


    A = B .+ D
    Ã = D .+ B
    @test A isa BandedMatrix
    @test Ã isa BandedMatrix
    @test bandwidths(A) == bandwidths(Ã) == (0,2)
    @test Ã == A == Matrix(B) + Matrix(D)

    A = B .+ J
    Ã = J .+ B
    @test A isa BandedMatrix
    @test Ã isa BandedMatrix
    @test bandwidths(A) == bandwidths(Ã) == (1,2)
    @test Ã == A == Matrix(B) + Matrix(J)

    A = B .+ T
    Ã = T .+ B
    @test A isa BandedMatrix
    @test Ã isa BandedMatrix
    @test bandwidths(A) == bandwidths(Ã) == (1,2)
    @test Ã == A == Matrix(B) + Matrix(T)
end

@testset "Vcat Zeros special case" begin
    A = BandedMatrices._BandedMatrix((1:10)', 10, -1,1)
    x = Vcat(1:3, Zeros(10-3))
    @test typeof(A*x) <: Vcat{Float64,1,<:Tuple{<:Vector,<:Zeros}}
    @test length((A*x).arrays[1]) == length(x.arrays[1]) + bandwidth(A,1) == 2
    @test A*x == A*Vector(x)

    A = BandedMatrices._BandedMatrix(randn(3,10), 10, 1,1)
    x = Vcat(randn(10), Zeros(0))
    @test typeof(A*x) <: Vcat{Float64,1,<:Tuple{<:Vector,<:Zeros}}
    @test length((A*x).arrays[1]) == 10
    @test A*x == A*Vector(x)
end

@testset "MulMatrix" begin
    A = brand(6,5,0,1)
    B = brand(5,5,1,0)
    M = MulArray(A,B)

    @test isbanded(M)
    @test bandwidths(M) == bandwidths(M.applied)
    @test BandedMatrix(M) == A*B

    @test M .+ A isa BandedMatrix

    @test M isa BandedMatrices.MulBandedMatrix

    V = view(M,1:4,1:4)
    @test bandwidths(V) == (1,1)
    @test MemoryLayout(V) == MemoryLayout(M)
    @test M[1:4,1:4] isa BandedMatrix

    A = brand(5,5,0,1)
    B = brand(6,5,1,0)
    @test_throws DimensionMismatch MulArray(A,B)

    A = brand(6,5,0,1)
    B = brand(5,5,1,0)
    C = brand(5,6,2,2)
    M = Mul(A,B,C)
    @test @inferred(eltype(M)) == Float64
    @test bandwidths(M) == (3,3)
    @test M[1,1] ≈ (A*B*C)[1,1]

    M = @inferred(MulArray(A,B,C))
    @test @inferred(eltype(M)) == Float64
    @test bandwidths(M) == (3,3)
    @test BandedMatrix(M) ≈ A*B*C
end
