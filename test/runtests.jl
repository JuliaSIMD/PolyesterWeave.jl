using PolyesterWeave, Aqua
using Test

@testset "PolyesterWeave.jl" begin

  threads, torelease = PolyesterWeave.request_threads(Threads.nthreads()-1)
  @test threads isa NTuple{Int(PolyesterWeave.worker_mask_count()),PolyesterWeave.UnsignedIteratorEarlyStop{PolyesterWeave.worker_type()}}
  @test sum(map(length, threads)) == (PolyesterWeave.num_threads())-1
  map(PolyesterWeave.free_threads!, torelease)

  r1 = PolyesterWeave.request_threads(Sys.CPU_THREADS, 0x0a)
  @test (r1[2][1] & 0x0a) == r1[2][1]
  r2 = PolyesterWeave.request_threads(Sys.CPU_THREADS, 0xff)
  @test (r2[2][1] & 0xff) == r2[2][1]
  @test count_ones(r1[2][1] ⊻ r2[2][1]) ≤ min(8, Sys.CPU_THREADS)
  @test iszero(r1[2][1] & r2[2][1])
  PolyesterWeave.free_threads!(r1[2][1]); PolyesterWeave.free_threads!(r2[2][1])
  
  @testset "Valid State" begin
    @test sum(map(count_ones, PolyesterWeave.WORKERS[])) == min(512, PolyesterWeave.dynamic_thread_count() - 1)
  end
end
Aqua.test_all(PolyesterWeave)

