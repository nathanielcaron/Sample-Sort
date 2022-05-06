using Base
using StatsBase

function sampleSort(a, m)
    p = Threads.nthreads()
    n = length(a)
    type = eltype(a)

    if p < 2
        println("This algorithm requires 2 threads or more.")
        return nothing
    end

    # Step 1: Pick a random sample array 's' of size 'm' from the array 'a'
    s = sample(a, m, replace=false)
    sort!(s)

    # Step 2: Choose splitters / dividers to divide the sample 's' into 'p' sub-arrays of equal size
    splitters = zeros(type, p-1)
    sNumElemPerGroup = cld(m,p)
    index = sNumElemPerGroup
    @inbounds for k in 1:p-1
        splitters[k] = s[index]
        index += sNumElemPerGroup
    end
    push!(splitters, typemax(type))

    # Step 3: Divide each sub-array into 'p' sub-groups based on the splitters / dividers
    # Number of elements in each sub-array
    aNumElemPerGroup = cld(n,p)
    # Array of sub-groups for all threads
    arrays = Vector{Vector{Vector{type}}}(undef, p)

    Threads.@threads for i in 1:p
        # Calculate start and end index for current thread
        startIndex = (i-1)*aNumElemPerGroup + 1
        endIndex = min((i-1)*aNumElemPerGroup + aNumElemPerGroup, n)

        result = splitSubArray(type, view(a, startIndex:endIndex), p, splitters)
        arrays[i] = result
    end

    # Join sub-groups from different threads together
    # e.g., join all first groups less than first splitter together
    bSegments = Vector{Vector{type}}()
    @inbounds for i in 1:p
        push!(bSegments, [])
        @inbounds for j in 1:p
            append!(bSegments[i], arrays[j][i])
        end
    end

    # Step 4: Sort sub-groups of b each on separate thread
    Threads.@threads for i in 1:p
        sort!(bSegments[i])
    end

    # Join sub-groups of b together to form sorted b array
    b = Vector{type}()
    @inbounds for i in 1:p
        append!(b, bSegments[i])
    end

    return b
end

# Function to be executed by each thread to divide its sub-array into p sub-groups
function splitSubArray(type, suba, numOfGroups, splitters)
    n = length(suba)
    m = length(splitters)

    # Initialize p sub-groups of elements
    groups = Vector{Vector{type}}()
    @inbounds for i in 1:numOfGroups
        push!(groups, [])
    end

    # Push elements to their corresponding sub-group based on the splitters
    @inbounds for i in 1:n
        @inbounds for j in 1:m
            if suba[i] <= splitters[j]
                push!(groups[j], suba[i])
                break
            end
        end
    end

    return groups
end
