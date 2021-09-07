using PolyesterWeave, Aqua
using Test

@testset "PolyesterWeave.jl" begin

  threads, torelease = PolyesterWeave.request_threads(Threads.nthreads()-1)
  @test threads isa NTuple{Int(PolyesterWeave.worker_mask_count()),PolyesterWeave.UnsignedIteratorEarlyStop{PolyesterWeave.worker_type()}}
  @test sum(map(length, threads)) == (PolyesterWeave.num_threads())-1
  map(PolyesterWeave.free_threads!, torelease)

  
  @testset "Valid State" begin
    @test sum(map(count_ones, PolyesterWeave.WORKERS[])) == min(512, PolyesterWeave.dynamic_thread_count() - 1)
  end
end
Aqua.test_all(PolyesterWeave)

