using TiledIteration
using Base.Test

@testset "tiled iteration" begin
    sz = (3,5)
    for i1 = -3:2, i2 = -1:5
        for l1 = 2:13, l2 = 1:16
            inds = (i1:i1+l1-1, i2:i2+l2-1)
            A = zeros(Int, inds...)
            k = 0
            for tileinds in TileIterator(inds, sz)
                tile = A[tileinds...]
                @test !isempty(tile)
                @test all(tile .== 0)
                A[tileinds...] = (k+=1)
            end
            @test minimum(A) == 1
        end
    end
end

@testset "padded sizes" begin
    @test @inferred(padded_tilesize(UInt8, (1,))) == (2^14,)
    @test @inferred(padded_tilesize(UInt16, (1,))) == (2^13,)
    @test @inferred(padded_tilesize(Float64, (1,))) == (2^11,)
    @test @inferred(padded_tilesize(Float64, (1,1))) == (2^11, 1)
    @test @inferred(padded_tilesize(Float64, (2,1))) == (2^11, 1)
    shp = @inferred(padded_tilesize(Float64, (2,2)))
    @test all(x->x>2, shp)
    @test 2^13 <= prod(shp)*8 <= 2^14
    shp = @inferred(padded_tilesize(Float64, (3,3,3)))
    @test all(x->x>3, shp)
    @test 2^13 <= prod(shp)*8 <= 2^14
end

@testset "threads" begin
    function sumtiles(A, sz)
        indsA = indices(A)
        iter = TileIterator(indsA, sz)
        sums = zeros(eltype(A), length(iter))
        for (i,tileinds) in enumerate(iter)
            v = view(A, tileinds...)
            if sums[i] == 0
                sums[i] = sum(v)
            else
                sums[i] = -sum(v)
            end
        end
        sums
    end
    function sumtiles_threaded(A, sz)
        indsA = indices(A)
        iter = TileIterator(indsA, sz)
        allinds = collect(iter)
        sums = zeros(eltype(A), length(iter))
        Threads.@threads for i = 1:length(allinds)
            tileinds = allinds[i]
            v = view(A, tileinds...)
            if sums[i] == 0
                sums[i] = sum(v)
            else
                sums[i] = -sum(v)
            end
        end
        sums
    end

    Asz, tilesz = Base.JLOptions().can_inline == 1 ? ((1000,1000), (100,100)) : ((100,100), (10,10))
    A = rand(Asz)
    snt = sumtiles(A, tilesz)
    st = sumtiles_threaded(A, tilesz)
    @test snt == st
    @test all(st .> 0)
end

nothing