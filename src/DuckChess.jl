module DuckChess
using Match
using Random

include("board.jl")
export Position, Move, BoardSecrets, INITIAL_SETUP, NOMOVE, domove!, undomove!, withinboard, placeduck!, isvacant, isking, ispawn, iscapture
include("evaluation.jl")
include("hash.jl")
include("IO.jl")
export read_FEN, get_FEN, print_board, print_move, move_from_LAN
include("iterators.jl")
export LegalMoves
include("engine.jl")
export search

end