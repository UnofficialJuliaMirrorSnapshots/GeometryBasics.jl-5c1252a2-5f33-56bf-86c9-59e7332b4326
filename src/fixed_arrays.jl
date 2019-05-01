export Mat
export Vec
export Point
export unit

const Mat = SMatrix

function unit(::Type{T}, i::Integer) where T <: StaticVector
    T(ntuple(Val(length(T))) do j
        ifelse(i == j, 1, 0)
    end)
end

macro fixed_vector(name, parent)
    esc(quote
        struct $(name){S, T} <: $(parent){S, T}
            data::NTuple{S, T}

            function $(name){S, T}(x::NTuple{S,T}) where {S, T}
                new{S, T}(x)
            end

            function $(name){S, T}(x::NTuple{S,Any}) where {S, T}
                new{S, T}(StaticArrays.convert_ntuple(T, x))
            end
        end
        size_or(::Type{$(name)}, or) = or
        eltype_or(::Type{$(name)}, or) = or
        eltype_or(::Type{$(name){S, T} where S}, or) where {T} = T
        eltype_or(::Type{$(name){S, T} where T}, or) where {S} = or
        eltype_or(::Type{$(name){S, T}}, or) where {S, T} = T

        size_or(::Type{$(name){S, T} where S}, or) where {T} = or
        size_or(::Type{$(name){S, T} where T}, or) where {S} = Size{(S,)}()
        size_or(::Type{$(name){S, T}}, or) where {S, T} = (S,)
        # Array constructor
        @inline function $(name){S}(x::AbstractVector{T}) where {S, T}
            @assert S <= length(x)
            $(name){S, T}(ntuple(i-> x[i], Val(S)))
        end
        @inline function $(name){S, T1}(x::AbstractVector{T2}) where {S, T1, T2}
            @assert S <= length(x)
            $(name){S, T1}(ntuple(i-> T1(x[i]), Val(S)))
        end

        @inline function $(name){S, T}(x) where {S, T}
            $(name){S, T}(ntuple(i-> T(x), Val(S)))
        end


        @inline function $(name){S}(x::T) where {S, T}
            $(name){S, T}(ntuple(i-> x, Val(S)))
        end
        @inline function $(name){1, T}(x::T) where T
            $(name){1, T}((x,))
        end
        @inline $(name)(x::NTuple{S}) where {S} = $(name){S}(x)
        @inline $(name)(x::T) where {S, T <: Tuple{Vararg{Any, S}}} = $(name){S, StaticArrays.promote_tuple_eltype(T)}(x)
        @inline function $(name){S}(x::T) where {S, T <: Tuple}
            $(name){S, StaticArrays.promote_tuple_eltype(T)}(x)
        end
        $(name){S, T}(x::StaticVector) where {S, T} = $(name){S, T}(Tuple(x))
        @generated function (::Type{$(name){S, T}})(x::$(name)) where {S, T}
            idx = [:(x[$i]) for i = 1:S]
            quote
                $($(name)){S, T}($(idx...))
            end
        end
        @generated function convert(::Type{$(name){S, T}}, x::$(name)) where {S, T}
            idx = [:(x[$i]) for i = 1:S]
            quote
                $($(name)){S, T}($(idx...))
            end
        end
        @generated function (::Type{SV})(x::StaticVector) where SV <: $(name)
            len = size_or(SV, size(x))[1]
            if length(x) == len
                :(SV(Tuple(x)))
            elseif length(x) > len
                elems = [:(x[$i]) for i = 1:len]
                :(SV($(Expr(:tuple, elems...))))
            else
                error("Static Vector too short: $x, target type: $SV")
            end
        end

        Base.@pure StaticArrays.Size(::Type{$(name){S, Any}}) where {S} = Size(S)
        Base.@pure StaticArrays.Size(::Type{$(name){S, T}}) where {S,T} = Size(S)

        Base.@propagate_inbounds function Base.getindex(v::$(name){S, T}, i::Int) where {S, T}
            v.data[i]
        end
        @inline Base.Tuple(v::$(name)) = v.data
        @inline Base.convert(::Type{$(name){S, T}}, x::NTuple{S, T}) where {S, T} = $(name){S, T}(x)
        @inline function Base.convert(::Type{$(name){S, T}}, x::Tuple) where {S, T}
            $(name){S, T}(convert(NTuple{S, T}, x))
        end

        @generated function StaticArrays.similar_type(::Type{SV}, ::Type{T}, s::Size{S}) where {SV <: $(name), T, S}
            if length(S) === 1
                $(name){S[1], T}
            else
                StaticArrays.default_similar_type(T,s(),Val{length(S)})
            end
        end

    end)
end
