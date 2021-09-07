module PolyesterWeave

using BitTwiddlingConvenienceFunctions: nextpow2
using ThreadingUtilities: _atomic_store!, _atomic_or!, _atomic_xchg!
using Static
using IfElse: ifelse
using CPUSummary: num_threads

export request_threads, free_threads!

@static if VERSION ≥ v"1.6.0-DEV.674"
  @inline function assume(b::Bool)
    Base.llvmcall(("""
      declare void @llvm.assume(i1)

      define void @entry(i8 %byte) alwaysinline {
      top:
        %bit = trunc i8 %byte to i1
        call void @llvm.assume(i1 %bit)
        ret void
      }
  """, "entry"), Cvoid, Tuple{Bool}, b)
  end
else
  @inline assume(b::Bool) = Base.llvmcall(("declare void @llvm.assume(i1)", "%b = trunc i8 %0 to i1\ncall void @llvm.assume(i1 %b)\nret void"), Cvoid, Tuple{Bool}, b)
end

const WORKERS = Ref{NTuple{8,UInt64}}(ntuple(((~) ∘ (zero ∘ UInt64)), Val(8)))

include("unsignediterator.jl")
include("request.jl")

dynamic_thread_count() = min((Sys.CPU_THREADS)::Int, Threads.nthreads())
reset_workers!() = WORKERS[] = ntuple(((~) ∘ (zero ∘ UInt64)), Val(8))
function __init__()
  reset_workers!()
end

end
