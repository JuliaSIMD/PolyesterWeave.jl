function worker_bits()
  ws = nextpow2(num_threads())
  ifelse(Static.lt(ws,StaticInt{8}()), StaticInt{8}(), ws)
end
function worker_mask_count()
  bits = worker_bits()
  (bits + StaticInt{63}()) ÷ StaticInt{64}() # cld not defined on `StaticInt`
end
worker_size() = worker_bits() ÷ worker_mask_count()

_mask_type(::StaticInt{8}) = UInt8
_mask_type(::StaticInt{16}) = UInt16
_mask_type(::StaticInt{32}) = UInt32
_mask_type(::StaticInt{64}) = UInt64
worker_type() = _mask_type(worker_size())
worker_pointer_type() = Ptr{worker_type()}

worker_pointer() = Base.unsafe_convert(worker_pointer_type(), pointer_from_objref(WORKERS))

function free_threads!(freed_threads)
  _atomic_or!(worker_pointer(), freed_threads)
  nothing
end
@inline _remaining(x::Tuple) = Base.tail(x)
@inline _remaining(@nospecialize(x)) = nothing
@inline _first(x::Tuple{}) = nothing
@inline _first(x::Tuple{X,Vararg}) where {X<:Unsigned} = getfield(x,1)
@inline _first(x::Union{Unsigned,Nothing}) = x
@inline function _request_threads(num_requested::UInt32, wp::Ptr, ::StaticInt{N}, threadmask) where {N}
  ui, ft, num_requested, wp = __request_threads(num_requested, wp, _first(threadmask))
  uit, ftt = _request_threads(num_requested, wp, StaticInt{N}()-StaticInt{1}(), _remaining(threadmask))
  (ui, uit...), (ft, ftt...)
end
@inline function _request_threads(num_requested::UInt32, wp::Ptr, ::StaticInt{1}, threadmask)
  ui, ft, num_requested, wp = __request_threads(num_requested, wp, _first(threadmask))
  (ui, ), (ft, )
end
@inline function _exchange_mask!(wp, ::Nothing)
  all_threads = _atomic_xchg!(wp, zero(worker_type()))
  all_threads, all_threads
end
@inline function _exchange_mask!(wp, threadmask::Unsigned)
  all_threads = _atomic_xchg!(wp, zero(worker_type()))
  saved = all_threads & (~(threadmask%worker_type()))
  _atomic_store!(wp, saved)
  all_threads | saved, all_threads & threadmask
end
@inline function __request_threads(num_requested::UInt32, wp::Ptr, threadmask)
  no_threads = zero(worker_type())
  if (num_requested ≢ StaticInt{-1}()) && (num_requested % Int32 ≤ zero(Int32))
    return UnsignedIteratorEarlyStop(zero(worker_type()), 0x00000000), no_threads, 0x00000000, wp
  end
  # to get more, we xchng, setting all to `0`
  # then see which we need, and free those we aren't using.
  wpret = wp + 8 # (worker_type() === UInt64) | (worker_mask_count() === StaticInt(1)) #, so adding 8 is fine.
  # _all_threads = all_threads = _apply_mask(_atomic_xchg!(wp, no_threads), threadmask)
  _all_threads, all_threads = _exchange_mask!(wp, threadmask)
  additional_threads = count_ones(all_threads) % UInt32
  # num_requested === StaticInt{-1}() && return reserved_threads, all_threads
  if num_requested === StaticInt{-1}()
    return UnsignedIteratorEarlyStop(all_threads), all_threads, num_requested, wpret
  end
  nexcess = num_requested - additional_threads
  if signed(nexcess) ≥ 0
    return UnsignedIteratorEarlyStop(all_threads), all_threads, nexcess, wpret
  end
  # we need to return the `excess` to the pool.
  lz = leading_zeros(all_threads) % UInt32
  while true
    # start by trying to trim off excess from lz
    lz += (-nexcess)%UInt32
    m = (one(worker_type()) << (UInt32(last(worker_size())) - lz)) - one(worker_type())
    masked = (all_threads & m) ⊻ all_threads
    nexcess += count_ones(masked) % UInt32
    all_threads &= (~masked)
    nexcess == zero(nexcess) && break
  end
  _atomic_store!(wp, _all_threads & (~all_threads))
  return UnsignedIteratorEarlyStop(all_threads, num_requested), all_threads, 0x00000000, wpret
end

@inline function request_threads(num_requested, threadmask)
  _request_threads(num_requested % UInt32, worker_pointer(), worker_mask_count(), threadmask)
end
@inline request_threads(num_requested) = request_threads(num_requested, nothing)

