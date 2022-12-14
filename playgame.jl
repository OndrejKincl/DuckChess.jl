module PlayGame

const IS_UNICODE_DEFAULT = false
const IS_BLITZMODE_DEFAULT = false
const IS_INVERT_DEFAULT = false
const CPU_DEFAULT_SIDE = 0 # 1 to play white, -1 to play black
const BLITZ_DEPTH = 6
const FULL_DEPTH = 8

include("src/DuckChess.jl")
using .DuckChess

mutable struct Game
    pos::Position
    move_history::Vector{Move}
    bose_history::Vector{BoardSecrets}
    fen_history::Vector{String}
    half_move_counter::Integer
    fifty_move_counter::Integer
    Game(fen::String) = new(read_FEN(fen), Move[], BoardSecrets[], [fen], 1, 0)
end

function add!(game::Game, move::Move)
    push!(game.bose_history, BoardSecrets(game.pos))
    push!(game.move_history, move)
    domove!(game.pos, move)
    push!(game.fen_history, get_FEN(game.pos))
    game.half_move_counter += 1
    if !iscapture(move) && !ispawn(move.p)
        game.fifty_move_counter += 1
    end 
    return
end

function remove!(game::Game, move::Move)
    game.half_move_counter -= 1
    undomove!(game.pos, pop!(game.move_history), pop!(game.bose_history))
    if !iscapture(move) && !ispawn(move.p)
        game.fifty_move_counter = max(0, game.fifty_move_counter - 1)
    end 
    pop!(game.fen_history)
end

function game_result(game::Game)::Int
    if !('K' in game.pos.board)
        return -1
    end
    if !('k' in game.pos.board)
        return  1
    end
    if isempty(LegalMoves(game.pos))
        return game.pos.toplay
    end
    for fen in game.fen_history
        if count(_fen -> fen == _fen, game.fen_history) >= 3
            return 2
        end
    end
    if game.fifty_move_counter >= 100
        return 3
    end
    return 0
end

function last_move(game::Game)::Move
    if isempty(game.move_history)
        return NOMOVE
    else
        return game.move_history[end]
    end    
end


function main()
    game = Game(INITIAL_SETUP)
    invert = IS_INVERT_DEFAULT
    blitzmode = IS_BLITZMODE_DEFAULT
    computer_side = CPU_DEFAULT_SIDE
    use_unicode = IS_UNICODE_DEFAULT
    while true
        if isodd(game.half_move_counter)
            println(div(game.half_move_counter + 1, 2), ".")
            println()
        end
        print_board(game.pos, lastmove = last_move(game), invert = invert, use_unicode = use_unicode)
        result = game_result(game)
        if result != 0
            computer_side = 0
        end
        if (game.pos.toplay == computer_side)
            max_depth = blitzmode ? BLITZ_DEPTH : FULL_DEPTH
            res = search(game.pos, max_depth)
            add!(game, res.move)
            placeduck!(game.pos, res.Dx, res.Dy)
        else
            while true
                if result == +1
                    print("White wins! Insert n to start a new game: ")
                elseif result == -1
                    print("Black wins! Insert n to start a new game: ")
                elseif result == 2
                    print("Draw by three-fold repetition. Insert n to start a new game: ")
                elseif result == 3
                    print("Draw by 50 move rule! Insert n to start a new game: ")
                else
                    print("Your move (h for help): ")
                end
                input = readline()
                input = filter(c -> !isspace(c), input)
                if input == "h"
                    println()
                    println("      HELP      ")
                    println("================")
                    println()
                    println("Enter a move using long algebraic notation: c2c4 is a good start :-)") 
                    println("l ... lists all legal moves")
                    println("u ... undo last move")
                    println("c ... make computer play for this side")
                    println("H ... human vs human mode")
                    println("b ... turn ", blitzmode ? "off" : "on", " blitzmode")
                    println("i ... invert the board")
                    println("a ... analyze position using computer")
                    println("n ... start new game")
                    println("d ... redraw the board")
                    println("f ... print out FEN code")
                    println("r ... read position from FEN")
                    println("U ... switch display mode between ASCII and Unicode")
                    println("q ... quit")
                    println("================")
                    println()
                    continue
                elseif input == "l" && result == 0
                    k = 1
                    println()
                    for move in LegalMoves(game.pos)
                        print_move(move)
                        print('\t')
                        if k > 3
                            k = 0
                            println()
                        end
                        k += 1
                    end
                    println()
                    continue
                elseif input == "q"
                    return
                elseif input == "f"
                    println(get_FEN(game.pos))
                    continue
                elseif input == "u"
                    if isempty(game.move_history)
                        @error "There is no move to undo!"
                        println()
                        continue
                    else
                        computer_side = 0
                        remove!(game, last_move(game))
                        break
                    end
                elseif input == "c"
                    computer_side = game.pos.toplay
                    break
                elseif input == "b"
                    blitzmode = !blitzmode
                    continue
                elseif input == "U"
                    use_unicode = !use_unicode
                    print_board(game.pos, lastmove = last_move(game), invert = invert, use_unicode = use_unicode)
                    continue
                elseif input == "i"
                    invert = !invert
                    print_board(game.pos, lastmove = last_move(game), invert = invert, use_unicode = use_unicode)
                    continue
                elseif input == "d"
                    print_board(game.pos, lastmove = last_move(game), invert = invert, use_unicode = use_unicode)
                    continue
                elseif input == "n"
                    game = Game(INITIAL_SETUP)
                    invert = false
                    computer_side = 0
                    break
                elseif input == "H"
                    computer_side = 0
                    break
                elseif input == "a"
                    res = search(game.pos, FULL_DEPTH)
                    score = res.score*game.pos.toplay
                    print("I would play ")
                    print_move(res.move, res.Dx, res.Dy)
                    println(" here.")
                    if 20 <= score < 80
                        print("White is slightly better. ")
                    elseif 80 <= score < 200
                        print("White is better. ")
                    elseif 200 <= score
                        print("White is completely winning. ")
                    elseif -20 >= score > -80
                        print("Black is slightly better. ")
                    elseif -80 >= score > -200
                        print("Black is better. ")
                    elseif -200 >= score
                        print("Black is completely winning. ")
                    else
                        print("This position is balanced. ")
                    end
                    println("(score = ", score/100, ")")
                    println()
                    continue
                elseif input == "r"
                    print("Insert FEN code (use D for duck): ") 
                    _game = game
                    try 
                        _game = Game(readline())
                    catch
                        @error "Inval FEN code!"
                        println()
                        continue
                    end
                    game = _game
                    invert = false
                    computer_side = 0
                    println()
                    println()
                    println("This is a beautiful position!")
                    println()
                    break
                elseif result == 0
                    move = move_from_LAN(input, game.pos)
                    if move != NOMOVE
                        add!(game, move)
                        print_board(game.pos, lastmove = last_move(game), invert = invert, use_unicode = use_unicode)
                        while true
                            print("Place the duck:  ")
                            input = readline()
                            if length(input) >= 2
                                Dx = Int8(input[1] - 'a' + 1)
                                Dy = Int8(input[2] - '1' + 1)
                                if withinboard(Dx, Dy) && isvacant(Dx, Dy, game.pos)
                                    placeduck!(game.pos, Dx, Dy)
                                    break
                                end
                            end
                            @error "Place the duck to an empty square!"
                        end
                        break
                    end
                end
                @error "Illegal command!"
            end  
        end
    end
end


PlayGame.main()

end
