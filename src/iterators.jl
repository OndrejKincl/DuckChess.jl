# forward direction first
const KNIGHT_MOVE_X = Int8.([ 1,-1, 2,-2, 2,-2, 1,-1])
const KNIGHT_MOVE_Y = Int8.([ 2, 2, 1, 1,-1,-1,-2,-2])
const PAWN_MOVE_X = Int8.([ 1,-1, 0, 0])
const PAWN_MOVE_Y = Int8.([ 1, 1, 2, 1])
const PROMOTING_PAWN_MOVE_X = Int8.([ 1,-1, 0, 1,-1, 0])
const PROMOTING_PAWN_MOVE_Y = Int8.([ 1, 1, 1, 1, 1, 1])
const WHITE_PAWN_PROMOTES = Int8.([ 'Q', 'Q', 'Q', 'N', 'N', 'N'])
const BLACK_PAWN_PROMOTES = Int8.([ 'q', 'q', 'q', 'n', 'n', 'n'])
const KING_MOVE_X  = Int8.([ 2, -2, 1,-1, 1,-1, 0, 1,-1, 0]) 
const KING_MOVE_Y  = Int8.([ 0,  0, 1, 1,-1,-1, 1, 0, 0,-1])
const QUEEN_MOVE_X  = Int8.([ 1,-1, 1,-1, 0, 1,-1, 0]) 
const QUEEN_MOVE_Y  = Int8.([ 1, 1,-1,-1, 1, 0, 0,-1])

const X_ARRAY_CENTRAL =  Int8.([4 5 4 5 4 5 3 6 3 6 4 5 3 6 3 6 4 5 2 7 2 7 4 5 3 6 2 7 2 7 3 6 4 5 2 7 1 8 1 8 2 7 4 5 3 6 1 8 1 8 3 6 2 7 1 8 1 8 2 7 1 8 1 8])
const Y_ARRAY_CENTRAL =  Int8.([4 4 5 5 3 3 4 4 5 5 6 6 3 3 6 6 2 2 4 4 5 5 7 7 2 2 3 3 6 6 7 7 1 1 2 2 4 4 5 5 7 7 8 8 1 1 3 3 6 6 8 8 1 1 2 2 7 7 8 8 1 1 8 8])
const X_ARRAY_AGGRESSIVE = Int8.([5 4 6 3 5 5 7 4 4 6 6 3 3 7 7 2 8 2 2 8 8 1 5 4 6 1 1 3 7 2 8 1 5 4 6 3 7 2 8 1 5 4 6 3 7 2 8 1 5 4 6 3 7 2 8 1 5 4 6 3 7 2 8 1])
const Y_ARRAY_AGGRESSIVE = Int8.([7 7 7 7 6 8 7 6 8 6 8 6 8 6 8 7 7 6 8 6 8 7 5 5 5 6 8 5 5 5 5 5 4 4 4 4 4 4 4 4 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1])

struct VacantSquares
	pos::Position
end

Base.eltype(::Type{VacantSquares}) = Tuple{Int8, Int8}

@inbounds Base.iterate(it::VacantSquares, k=1) = begin
	while k < 64
		x = X_ARRAY_AGGRESSIVE[k]
		y = Y_ARRAY_AGGRESSIVE[k]
		if it.pos.toplay == -1
			y = Int8(9) - y
		end
		if isvacant(x, y, it.pos)
			return ((x, y), k+1)
		end
		k += 1
	end
end

struct DuckMoves
	# iterator through all duck moves that prevent move::Move (assumes that hmove is legal)
	# begins with squares closest to the starting square (x0, y0)
	x0::Int8
	y0::Int8
	step_x::Int8
	step_y::Int8
	r_max::Int8
	Dx::Int8
	Dy::Int8
	pos::Position
	DuckMoves(pos::Position, move::Move, Dx::Integer, Dy::Integer) = begin
		x0 = move.x0
		y0 = move.y0
		step_x = sign(move.x1 - x0)
		step_y = sign(move.y1 - y0)
		r_max = max(abs(move.x1 - x0), abs(move.y1 - y0))
		p = move.p
		if p == 'N' || p == 'n' # different rules for knights
			r_max = 1
			step_x = move.x1 - x0
			step_y = move.y1 - y0
		end
		if iscapture(move)
			r_max -= 1
		end
		if isqueencastle(move) # only move which has additional blocking square
			r_max += 1
		end
		return new(x0, y0, step_x, step_y, r_max, Dx, Dy, pos)
	end
end

Base.eltype(::Type{DuckMoves}) = Tuple{Int8, Int8}

Base.iterate(it::DuckMoves, r=1) = begin
	first_search = (r == 1)
	while r <= it.r_max
		x = it.x0 + r*it.step_x
		y = it.y0 + r*it.step_y
		if isvacant(x, y, it.pos)
			return ((Int8(x), Int8(y)), r+1)
		end
		r += 1
	end
	if r == it.r_max + 1
		if withinboard(it.Dx, it.Dy) && isvacant(it.Dx, it.Dy, it.pos)
			return ((it.Dx, it.Dy), r+1)
		end
	end
	if first_search
		return ((Int8(0), Int8(0)), r+1)
	end
	return nothing
end


struct LegalMoves
	pos::Position
	LegalMoves(pos::Position) = new(pos)
end

Base.eltype(::Type{LegalMoves}) = Move

@inbounds Base.iterate(it::LegalMoves, state=(Int8(1),Int8(1),Int8(1))) = begin
	(k, n, r) = state
	while k <= 64
		x = X_ARRAY_CENTRAL[k]
		y = Y_ARRAY_CENTRAL[k]
		if color(it.pos.board[x,y]) != it.pos.toplay
			k += 1
			continue
		end
		mi = MoveIterator(x, y, it.pos)
		(move, n, r) = iterate(mi, it.pos, n, r)
		if move == NOMOVE
			k += Int8(1)
			n = Int8(1)
			r = Int8(1)
			continue
		else
			return (move, (Int8(k), Int8(n), Int8(r)))
		end
	end
	return nothing
end

struct MoveIterator
    x::Int8
    y::Int8
    p::Char
    MoveIterator(x::Int8, y::Int8, pos::Position) = new(x, y, pos.board[x,y])        
end

function iterate(it::MoveIterator, pos::Position, n::Integer, r::Integer)::Tuple{Move, Int8, Int8}
	return @match it.p begin
		'P' || 'p', if it.y != rank(7, pos.toplay) end => pawn_iterator(it.x, it.y, it.p, pos, n)
		'P' || 'p' => promoting_pawn_iterator(it.x, it.y, it.p, pos, n)
		'N' || 'n' => knight_iterator(it.x, it.y, it.p, pos, n)
		'B' || 'b' => slider_iterator(it.x, it.y, it.p, pos, n, r, 1, 4)
		'R' || 'r' => slider_iterator(it.x, it.y, it.p, pos, n, r, 5, 8)
		'Q' || 'q' => slider_iterator(it.x, it.y, it.p, pos, n, r, 1, 8)
		'K' || 'k' => king_iterator(it.x, it.y, it.p, pos, n)
		_ => (NOMOVE, 0, 0)
	end
end

@inbounds function pawn_iterator(x::Integer, y::Integer, p::Char, pos::Position, n::Integer)::Tuple{Move, Int8, Int8}
	while (n <= 4)
		x1 = x + PAWN_MOVE_X[n]
		y1 = y + pos.toplay*PAWN_MOVE_Y[n]
		if !withinboard(x1, y1)
		    n += 1
		    continue
		end
		#capture
		if (x1 != x) && isenemy(x1,y1,pos)
		    return (Move(x, y, x1, y1, p, pos.board[x1, y1], p), n+1, 1)
		end
		#en passant
		if (x1 != x) && (x1 == pos.epx) && (y1 == rank(6, pos.toplay)) && isvacant(x1, y1, pos)
			return (Move(x, y, x1, y1, p, pos.board[x1, y], p), n+1, 1)
		end
		if (x1 == x) && isvacant(x1, y1, pos)
		    #pawn double push
		    if (abs(y1 - y) == 2) && (y == rank(2, pos.toplay)) && isvacant(x, y + pos.toplay, pos)
				return (Move(x, y, x1, y1, p, '.', p), n+1, 1)
		    end
		    #pawn single push
		    if (abs(y1 - y) == 1)
		       return (Move(x, y, x1, y1, p, '.', p), n+1, 1)
		    end
		end
		n += 1
	end
	return (NOMOVE, 0, 0)
end

@inbounds function promoting_pawn_iterator(x::Integer, y::Integer, p::Char, pos::Position, n::Integer)::Tuple{Move, Int8, Int8}
	while (n <= 6)
		x1 = x + PROMOTING_PAWN_MOVE_X[n]
		y1 = y + pos.toplay*PROMOTING_PAWN_MOVE_Y[n]
		if !withinboard(x1, y1)
		    n += 1
		    continue
		end
		p1 = (pos.toplay == 1) ? WHITE_PAWN_PROMOTES[n] : BLACK_PAWN_PROMOTES[n]
		if (x1 != x) && isenemy(x1,y1,pos)
		    return (Move(x, y, x1, y1, p, pos.board[x1, y1], p1), n+1, 1)
		end
		if (x1 == x) && isvacant(x1, y1, pos)
		    return (Move(x, y, x1, y1, p, '.', p1), n+1, 1)
		end
		n += 1
	end
	return (NOMOVE, 0, 0)
end

@inbounds function knight_iterator(x::Integer, y::Integer, p::Char, pos::Position, n::Integer)::Tuple{Move, Int8, Int8}
	while n <= 8
		x1 = x + KNIGHT_MOVE_X[n]
		y1 = y + pos.toplay*KNIGHT_MOVE_Y[n]
		if withinboard(x1, y1) && !isblocked(x1, y1, pos)
			return (Move(x, y, x1, y1, p, pos.board[x1,y1], p), n+1, 1)
		end
		n += 1
	end
	return (NOMOVE, 0, 0)
end

@inbounds function king_iterator(x::Integer, y::Integer, p::Char, pos::Position, n::Integer)::Tuple{Move, Int8, Int8}
	while 1 <= n <= 10
		x1 = x + KING_MOVE_X[n]
		y1 = y + KING_MOVE_Y[n]
		if !withinboard(x1, y1)
		    n += 1
		    continue
		end
		if (n == 1) && (pos.toplay == 1 ? pos.wck : pos.bck) && isvacant(6, y, pos) && isvacant(7, y, pos)
			return (Move(x, y, x1, y1, p, '.', p), n+1, 1)
		end
		if (n == 2) && (pos.toplay == 1 ? pos.wcq : pos.bcq) && isvacant(4, y, pos) && isvacant(3, y, pos) && isvacant(2, y, pos)
			return (Move(x, y, x1, y1, p, '.', p), n+1, 1)
		end
		if (3 <= n <= 10) && !isblocked(x1, y1, pos)
		       return (Move(x, y, x1, y1, p, pos.board[x1,y1], p), n+1, 1)
		end
		n += 1
	end
	return (NOMOVE, 0, 0)
end

@inbounds function slider_iterator(x::Integer, y::Integer,  p::Char, pos::Position, n::Integer, r::Integer, n0::Integer, n1::Integer)::Tuple{Move, Int8, Int8}
	n = max(n, n0)
	while n <= n1
		while true
		    x1 = Int8(x + r*QUEEN_MOVE_X[n])
		    y1 = Int8(y + r*pos.toplay*QUEEN_MOVE_Y[n])
		    if withinboard(x1, y1) && !isblocked(x1, y1, pos)
				if isvacant(x1, y1, pos)
					r += 1
				else
					n += 1
					r = 1
				end
				n = Int8(n)
				r = Int8(r)
				return (Move(x, y, x1, y1, p, pos.board[x1,y1], p), n, r)
			else
				n += 1
				r = 1
				break
			end
		end
	end
	return (NOMOVE, 0, 0)
end