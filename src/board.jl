mutable struct Position
    board::Matrix{Char}
    toplay::Int8
    # know duck position to remove it quickly
    Dx::Int8
    Dy::Int8
    # enpassant target
    epx::Int8
    # castling flags
    wcq::Bool   # white queenside castle
    wck::Bool   # white kingside castle
    bcq::Bool   # black queenside castle
    bck::Bool   # black kingside castle
    # evaluation parameters
    mgv::Int64  # mid-game value
    egv::Int64  # end-game value
    pcv::Int64  # piece value
    hash::UInt64
end

struct Move
    x0::Int8
    y0::Int8
    x1::Int8
    y1::Int8
    p::Char
    capture::Char
    promote::Char
end

const NOMOVE = Move(0,0,0,0,'N','O','M')

const INITIAL_SETUP = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"

# additional info needed to undo moves
struct BoardSecrets
    Dx::Int8
    Dy::Int8
    epx::Int8
    wcq::Bool
    wck::Bool
    bcq::Bool
    bck::Bool
    mgv::Int64
    egv::Int64
    pcv::Int64
    hash::UInt64
    BoardSecrets(pos::Position) = new(pos.Dx, pos.Dy, pos.epx, pos.wcq, pos.wck, pos.bcq, pos.bck, pos.mgv, pos.egv, pos.pcv, pos.hash)
end

function ispawn(p::Char)::Bool
    return (p == 'p') || (p == 'P')
end

function isking(p::Char)::Bool
    return (p == 'k') || (p == 'K')
end

@inbounds function isvacant(x::Integer, y::Integer, pos::Position)::Bool
    return pos.board[x,y] == '.'
end

@inbounds function isenemy(x::Integer, y::Integer, pos::Position)::Bool
    return color(pos.board[x,y]) == -pos.toplay
end

@inbounds function isblocked(x::Integer, y::Integer, pos::Position)::Bool
    return (pos.board[x,y] == 'D') || (color(pos.board[x,y]) == pos.toplay)
end

function color(p::Char)
    return @match p begin
        'K' || 'Q' || 'R' || 'B' || 'N' || 'P' =>  1
        'k' || 'q' || 'r' || 'b' || 'n' || 'p' => -1
         _  =>  0
    end
end

function rank(r::Integer, side::Integer)
    return (side == 1) ? r : 9-r
end

function withinboard(x::Integer, y::Integer)::Bool
    return (1 <= x <= 8) && (1 <= y <= 8)
end

function iscapture(move::Move)::Bool
    return move.capture != '.'
end

function ispromotion(move::Move)::Bool
    return move.promote != move.p
end

function isenpassant(move::Move, pos::Position)::Bool
    return ispawn(move.p) && (move.x1 == pos.epx) && (move.y1 == rank(6, pos.toplay))
end

function isdoublepush(move::Move)::Bool
    return ispawn(move.p) && (abs(move.y1 - move.y0) == 2)
end

function isqueencastle(move::Move)::Bool
    return isking(move.p) && (move.x0 == 5) && (move.x1 == 3)
end

function iskingcastle(move::Move)::Bool
    return isking(move.p) && (move.x0 == 5) && (move.x1 == 7)
end

@inbounds function domove!(pos::Position, move::Move)
    @assert (move != NOMOVE) "NOMOVE cannot be used as argument for domove! function"
    wck0 = pos.wck
    wcq0 = pos.wcq
    bck0 = pos.bck
    bcq0 = pos.bcq
    p = move.p
    pos.board[move.x1, move.y1] = move.promote
    pos.board[move.x0, move.y0] = '.'
    pos.hash = xor(pos.hash, get_hash(move.p, move.x0, move.y0))
    pos.hash = xor(pos.hash, get_hash(move.promote, move.x1, move.y1))
    pos.mgv += -get_mgv(move.p, move.x0, move.y0) + get_mgv(move.promote, move.x1, move.y1)
    pos.egv += -get_egv(move.p, move.x0, move.y0) + get_egv(move.promote, move.x1, move.y1)
    if isenpassant(move, pos)
        pos.board[move.x1, move.y0] = '.'
        pos.hash = xor(pos.hash, get_hash(move.capture, move.x1, move.y0))
        pos.mgv += get_mgv(move.capture, move.x1, move.y0)
        pos.egv += get_egv(move.capture, move.x1, move.y0)
    elseif iscapture(move) #standard capture
        pos.hash = xor(pos.hash, get_hash(move.capture, move.x1, move.y1))
        pos.mgv += get_mgv(move.capture, move.x1, move.y1)
        pos.egv += get_egv(move.capture, move.x1, move.y1)
        pos.pcv -= get_pcv(move.capture)
    end
    if pos.epx != 0
        pos.hash = xor(pos.hash, EPX_HASH[pos.epx])
    end
    if isdoublepush(move)
        pos.epx = move.x0
        pos.hash = xor(pos.hash, EPX_HASH[move.x0])
    else
        pos.epx = 0
    end
    # special king moves
    if isking(p)
        rook = (move.p == 'K' ? 'R' : 'r')
        if iskingcastle(move) # kingside castle
            pos.board[6, move.y0] = pos.board[8, move.y0]
            pos.board[8, move.y0] = '.'
            pos.hash = xor(pos.hash, get_hash(rook, 8, move.y0))
            pos.hash = xor(pos.hash, get_hash(rook, 6, move.y0))
            pos.mgv += -get_mgv(rook, 8, move.y0) + get_mgv(rook, 6, move.y0)
            pos.egv += -get_egv(rook, 8, move.y0) + get_egv(rook, 6, move.y0)
        elseif isqueencastle(move) # queenside castle
            pos.board[4, move.y0] = pos.board[1, move.y0]
            pos.board[1, move.y0] = '.'
            pos.hash = xor(pos.hash, get_hash(rook, 4, move.y0))
            pos.hash = xor(pos.hash, get_hash(rook, 1, move.y0))
            pos.mgv += -get_mgv(rook, 1, move.y0) + get_mgv(rook, 4, move.y0)
            pos.egv += -get_egv(rook, 1, move.y0) + get_egv(rook, 4, move.y0)
        end
        if p == 'K'
            pos.wck = false
            pos.wcq = false
        end 
        if p == 'k'
            pos.bck = false
            pos.bcq = false
        end 
    end
    # revoke castling right when a rook moves/is captured
    if (move.x0 == 1 && move.y0 == 1) || (move.x1 == 1 && move.y1 == 1)
        pos.wcq = false
    end
    if (move.x0 == 1 && move.y0 == 8) || (move.x1 == 1 && move.y1 == 8)
        pos.bcq = false
    end
    if (move.x0 == 8 && move.y0 == 1) || (move.x1 == 8 && move.y1 == 1)
        pos.wck = false
    end
    if (move.x0 == 8 && move.y0 == 8) || (move.x1 == 8 && move.y1 == 8)
        pos.bck = false
    end
    if pos.wck != wck0
        pos.hash = xor(pos.hash, WCK_HASH)
    end
    if pos.wcq != wcq0
        pos.hash = xor(pos.hash, WCQ_HASH)
    end
    if pos.bck != bck0
        pos.hash = xor(pos.hash, BCK_HASH)
    end
    if pos.bcq != bcq0
        pos.hash = xor(pos.hash, BCQ_HASH)
    end
    # promotion
    if ispromotion(move)
        pos.pcv += get_pcv(move.promote)
    end
    pos.hash = xor(pos.hash, BLACK_TOMOVE_HASH)
    pos.toplay *= -1
    pos.mgv *= -1
    pos.egv *= -1
    return
end

@inbounds function placeduck!(pos::Position, Dx::Integer, Dy::Integer)
    if withinboard(pos.Dx, pos.Dy)
        pos.board[pos.Dx, pos.Dy] = '.'
        pos.hash = xor(pos.hash, get_hash('D', pos.Dx, pos.Dy))
    end
    if withinboard(Dx, Dy)
        pos.board[Dx, Dy] = 'D'
        pos.hash = xor(pos.hash, get_hash('D', Dx, Dy))
    end
    pos.Dx = Dx
    pos.Dy = Dy
    return
end

@inbounds function undomove!(pos::Position, move::Move, bose::BoardSecrets)
    @assert (move != NOMOVE) "NOMOVE cannot be used as argument for undomove! function"
    placeduck!(pos, bose.Dx, bose.Dy)
    pos.toplay *= -1
    pos.wck = bose.wck
    pos.wcq = bose.wcq
    pos.bck = bose.bck
    pos.bcq = bose.bcq
    pos.epx = bose.epx
    pos.mgv = bose.mgv
    pos.egv = bose.egv
    pos.pcv = bose.pcv
    pos.hash = bose.hash
    pos.board[move.x0, move.y0] = move.p
    pos.board[move.x1, move.y1] = move.capture
    if isenpassant(move, pos)
        pos.board[move.x1, move.y1] = '.'
        pos.board[move.x1, move.y0] = move.capture
    elseif iscapture(move)
        pos.board[move.x1, move.y1] = move.capture
    end
    #castling
    if isking(move.p)
        if iskingcastle(move)
            pos.board[8, move.y0] = pos.board[6, move.y0]
            pos.board[6, move.y0] = '.'
        elseif isqueencastle(move)
            pos.board[1, move.y0] = pos.board[4, move.y0]
            pos.board[4, move.y0] = '.'
        end
   end
   return
end