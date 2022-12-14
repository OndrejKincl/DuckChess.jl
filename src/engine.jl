const TOMOVE_SCORE = 20
const INFTY64 = 1_000_000_000_000
const NULL_DUCK_DELTA = 100

struct SearchResult
    move::Move
    Dx::Int8
    Dy::Int8
    score::Int64
    depth::Int64
end

const NORESULT = SearchResult(NOMOVE, Int8(0), Int8(0), 0, 0)

const Cache = Dict{UInt64, SearchResult}

function search(pos::Position, max_depth::Integer; verbose::Bool=false)::SearchResult
    cache = Cache()
    res = NORESULT
    print("computer is thinking")
    for depth in 2:2:max_depth
        stats = @timed begin
            res = search(pos, depth, cache)
        end
        if verbose
            println()
            println("depth = ", depth)
            println("score = ", (res.score + TOMOVE_SCORE)/100)
            println("time = ", stats.time)
            println("nodes = ", length(cache))
            print_pv(pos, cache, depth)
            println("\n\n")
        else
            print(".")
        end
        if res.score >= WINNING_SCORE # if you found a checkmate, look for a better one 
            break
        end
    end
    println()
    if !withinboard(res.Dx, res.Dy) # engine can decide not to place duck anywhere, but I think this is not legal
        ((Dx, Dy), _) = Base.iterate(VacantSquares(pos))
        res = SearchResult(res.move, Dx, Dy, res.score, res.depth)
    end
    return res
end

function search(
        pos::Position,
        depth::Integer,
        cache::Cache,
        alpha::Integer = -INFTY64,
        beta::Integer  =  INFTY64,
        # store where last piece landed (important for quiesce search) 
        last_x1::Integer = Int8(0), 
        last_y1::Integer = Int8(0)
    )::SearchResult
    #result of previous search
    res0 = NORESULT
    if haskey(cache, pos.hash)
        res0 = cache[pos.hash]
        if res0.depth >= depth
            return res0
        end
    end
    bose = BoardSecrets(pos)
    res = SearchResult(NOMOVE, Int8(0), Int8(0), (depth <= 0) ? score(pos) : -INFTY64, depth)
    # first try the move which was best during previous search
    if res0.move != NOMOVE
        (res, alpha) = analyze_move(res, res0.move, pos, depth, cache, alpha, beta, last_x1, last_y1, bose)
    end
    lmr = (depth > 4 ? 1 : 0)
    for move in LegalMoves(pos)
        if move == res0.move
            continue
        end
        score_old = res.score
        (res, alpha) = analyze_move(res, move, pos, depth - lmr, cache, alpha, beta, last_x1, last_y1, bose)
        if (score_old < res.score) && (lmr != 0) #node increased alpha -> it is more interesting and we should probe deeper
            (res, alpha) = analyze_move(res, move, pos, depth, cache, alpha, beta, last_x1, last_y1, bose)
        end
        if res.score >= beta
            break
        end
    end
    # if no move was found (and not in quiesce search) then it's stalemate
    if (depth > 0) && (res.move == NOMOVE) 
        @warn "stalemate on the horizon?"
        res = SearchResult(NOMOVE, Int8(0),Int8(0), WINNING_SCORE, depth)
    end
    # store result into cache and return
    push!(cache, pos.hash => res)
    return res
end

function analyze_move(
    res::SearchResult,
    move::Move,
    pos::Position,
    depth::Integer,
    cache::Cache,
    alpha::Integer,
    beta::Integer,
    last_x1::Integer, 
    last_y1::Integer,
    bose::BoardSecrets
)::Tuple{SearchResult, Int64}
    if depth <= 0 && !((move.x1 == last_x1) && (move.y1 == last_y1)) # quiescing (recaptures only)
        return (res, alpha)
    end
    if isking(move.capture)
        res = SearchResult(move, Int8(0), Int8(0), WINNING_SCORE + depth, depth)
        return (res, alpha)
    end
    domove!(pos, move)
    placeduck!(pos, Int8(0), Int8(0))
    # scout for opponent's threat when no duck is placed
    threat = search(pos, depth-2, cache, -beta, -alpha, move.x1, move.y1)
    if -threat.score >= beta + NULL_DUCK_DELTA
        res = SearchResult(move, Int8(0), Int8(0), -threat.score, depth)
        undomove!(pos, move, bose)
        return (res, alpha)
    end
    placeduck!(pos, bose.Dx, bose.Dy)
    duck_limiter1 = DuckMoves(pos, threat.move, threat.Dx, threat.Dy)
    duck_limiter2 = duck_limiter1
    # search duck moves which prevent this threat
    for (Dx, Dy) in DuckMoves(pos, threat.move, threat.Dx, threat.Dy)
        if !isobstraction(Dx, Dy, duck_limiter2)
            continue
        end
        placeduck!(pos, Dx, Dy)
        reply = search(pos, depth-1, cache, -beta, -alpha, move.x1, move.y1)
        if -reply.score > res.score
            res = SearchResult(move, Dx, Dy, -reply.score, depth)
            duck_limiter2 = DuckMoves(pos, reply.move, reply.Dx, reply.Dy)
            if res.score > alpha
                alpha = res.score
            end
        end
        placeduck!(pos, bose.Dx, bose.Dy)
        if res.score >= beta
            undomove!(pos, move, bose)
            return (res, alpha)
        end
    end
    undomove!(pos, move, bose)
    return (res, alpha)
end

function isobstraction(Dx::Int8, Dy::Int8, limiter::DuckMoves)
    for (_Dx, _Dy) in limiter
        if (Dx == _Dx) && (Dy == _Dy)
            return true
        end
    end
    return false    
end

function print_pv(pos::Position, cache::Cache, depth::Integer)
    move_history = Move[]
    bose_history = BoardSecrets[]
    n = 0
    while haskey(cache, pos.hash)
        node = cache[pos.hash]
        if node.move == NOMOVE
            break
        end
        n += 1
        print_move(node.move, node.Dx, node.Dy)
        print("  ")
        push!(move_history, node.move)
        push!(bose_history, BoardSecrets(pos))
        domove!(pos, node.move)
        placeduck!(pos, node.Dx, node.Dy)
        if n > depth
            break
        end
    end
    for k in n:-1:1
        undomove!(pos, move_history[k], bose_history[k])
    end
end