# This **not included** file implements a dynamics version of `_request_threads`, without
# the typical dispatch cost (by doing the branching manually through recursion).
# This functionality might become necessary if we switch to dynamic allocation of
# `worker_bits` instead of the current static one.
# Such changes usually arise because we are fighting invalidations and TTFX due to
# redefinition of static variables.
# The current static solution does not have these issues because we simply overprovision
# enough static worker bits, always bigger than the number of available threads.

@inline function _request_threads_recurse(
  ::Tuple{},
  num_requested::UInt32,
  wp::Ptr,
  threadmask,
  ::Int,
)
  _request_threads(num_requested, wp, StaticInt{1}(), threadmask)
end
@inline function _request_threads_recurse(
  tup::Tuple{StaticInt{N},Vararg},
  num_requested::UInt32,
  wp::Ptr,
  threadmask,
  i::Int,
) where {N}
  if i == N
    _request_threads(num_requested, wp, StaticInt{N}(), threadmask)
  else
    _request_threads_recurse(Base.tail(tup), num_requested, wp, threadmask, i)
  end
end

@inline function _request_threads(num_requested::UInt32, wp::Ptr, i::Int, threadmask) # fallback in absence of static scheduling
  m = cld(CPUSummary.sys_threads(), static(8sizeof(UInt)))
  tup = ntuple(static ∘ Base.Fix1(-, m + 1), Val(Int(m) - 1))

  _request_threads_recurse(tup, num_requested, wp, threadmask, i)
end
