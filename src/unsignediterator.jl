struct UnsignedIterator{U}
    u::U
end

Base.IteratorSize(::Type{<:UnsignedIterator}) = Base.HasShape{1}()
Base.IteratorEltype(::Type{<:UnsignedIterator}) = Base.HasEltype()

Base.eltype(::UnsignedIterator) = UInt32
Base.length(u::UnsignedIterator) = count_ones(u.u)
Base.size(u::UnsignedIterator) = (count_ones(u.u),)

@inline function Base.iterate(u::UnsignedIterator, (i,uu) = (0x00000000,u.u))
  tz = trailing_zeros(uu) % UInt32
  tz == oftype(uu, 8*sizeof(uu)) && return nothing
  tz += 0x00000001
  i += tz
  uu >>>= tz
  (i, (i, uu))
end

"""
    UnsignedIteratorEarlyStop(thread_mask[, num_threads = count_ones(thread_mask)])

Iterator, returning `(i,t) = Tuple{UInt32,UInt32}`, where `i` iterates from `1,2,...,num_threads`, and `t` gives the threadids to call `ThreadingUtilities.taskpointer` with.


Unfortunately, codegen is suboptimal when used in the ergonomic `for (i,tid) ∈ thread_iterator` fashion. If you want to microoptimize,
You'd get better performance from a pattern like:
```julia
function sumk(u,l = count_ones(u) % UInt32)
    uu = ServiceSolicitation.UnsignedIteratorEarlyStop(u,l)
    s = zero(UInt32); state = ServiceSolicitation.initial_state(uu)
    while true
        iter = iterate(uu, state)
        iter === nothing && break
        (i,t),state = iter
        s += t
    end
    s
end
```

This iterator will iterate at least once; it's important to check and exit early with a single threaded version.
"""
struct UnsignedIteratorEarlyStop{U}
    u::U
    i::UInt32
end
UnsignedIteratorEarlyStop(u) = UnsignedIteratorEarlyStop(u, count_ones(u) % UInt32)
UnsignedIteratorEarlyStop(u, i) = UnsignedIteratorEarlyStop(u, i % UInt32)

@inline _popfirstthread(::Tuple{}, ::Tuple{}, offset) = 0, (), ()
@inline function _popfirstthread(
  u::Tuple{U,Vararg{U,K}}, a::Tuple{TT,Vararg{TT,K}}, offset
) where {K,T,TT<:UnsignedIterator{T},U<:UnsignedIteratorEarlyStop{T}}
  uf = first(u)
  af = first(a)
  u0 = uf.u
  if iszero(u0)
    tid0, tupi, tup = _popfirstthread(Base.tail(u), offset + 8sizeof(u0))
    return tid0, (uf, tupi...), (af, tup...)
  end
  tz = Base.trailing_zeros(u0)
  mask = one(u0)<<tz
  u0 &= ~mask
  a0 = af.u
  a0 |= mask
  tid1 = tz + offset
  (
    tid1,
    (UnsignedIteratorEarlyStop(u0,uf.i-1), Base.tail(u)...),
    (UnsignedIterator(a0), Base.tail(a)...)
  )
end

@inline function popfirstthread(
  t::Tuple{Tuple{A,Vararg{A,K}},Tuple{TT,Vararg{TT,K}},Tuple{T,Vararg{T,K}}}
) where {K, T<:Unsigned, TT<:UnsignedIterator{T}, A<:UnsignedIteratorEarlyStop{T}}
  a, b, c = t
  tid, a, b = _popfirstthread(a, b, 1)
  tid, (a, b, c)
end

mask(u::UnsignedIteratorEarlyStop) = getfield(u, :u)
Base.IteratorSize(::Type{<:UnsignedIteratorEarlyStop}) = Base.HasShape{1}()
Base.IteratorEltype(::Type{<:UnsignedIteratorEarlyStop}) = Base.HasEltype()

Base.eltype(::UnsignedIteratorEarlyStop) = Tuple{UInt32,UInt32}
Base.length(u::UnsignedIteratorEarlyStop) = getfield(u, :i)
Base.size(u::UnsignedIteratorEarlyStop) = (getfield(u, :i),)

@inline function initial_state(u::UnsignedIteratorEarlyStop)
  # LLVM should figure this out if you check?
  assume(0x00000000 ≠ u.i)
  (0x00000000,u.u)
end
@inline function iter(i, uu)
  assume(uu ≠ zero(uu))
  tz = trailing_zeros(uu) % UInt32
  tz += 0x00000001
  i += tz
  uu >>>= tz
  i, uu
end
@inline function Base.iterate(u::UnsignedIteratorEarlyStop, ((i,uu),j) = (initial_state(u),0x00000000))
  # assume(u.i ≤ 0x00000020)
  # assume(j ≤ count_ones(uu))
  # iszero(j) && return nothing
  j == u.i && return nothing
  j += 0x00000001
  i, uu = iter(i, uu)
  ((j, i), ((i, uu), j))
end
function Base.show(io::IO, u::UnsignedIteratorEarlyStop)
    l = length(u)
    s = Vector{Int}(undef, l)
    if l > 0
        s .= last.(u)
    end
    print("Thread ($l) Iterator: U", s)
end

# @inline function Base.iterate(u::UnsignedIteratorEarlyStop, (i,uu) = (0xffffffff,u.u))
#     tz = trailing_zeros(uu) % UInt32
#     tz == 0x00000020 && return nothing
#     tz += 0x00000001
#     i += tz
#     uu >>>= tz
#     (i, (i,uu))
# end
