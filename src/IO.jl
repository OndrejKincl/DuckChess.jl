function print_board(pos::Position; lastmove = NOMOVE, invert = false)
    X = collect(1:8)
    Y = collect(1:8)
    reverse!(Y)
    if invert
        reverse!(X)
        reverse!(Y)
    end
    println()
    for y in Y
        print('\t', y, "|")
        for x in X
            p = pos.board[x,y]
            s = @match p begin
                'P' => '♟'
                'p' => '♙'
                'N' => '♞'
                'n' => '♘'
                'R' => '♜'
                'r' => '♖'
                'Q' => '♛'
                'q' => '♕'
                'B' => '♝'
                'b' => '♗'
                'K' => '♚'
                'k' => '♔'
                'D' => '☺'
                '.' => ' '
                 _  => '?'
            end
            if (s == ' ') && ((x,y) == (lastmove.x0, lastmove.y0))
                print(" *")
                continue
            end
            if (s == ' ') && isodd(x+y)
                s = '■'
            end
            if (x,y) == (lastmove.x1, lastmove.y1)
                print(s, "*")
            else
                print(s, " ")
            end
        end
        println()
    end
    print("\t  ")
    for x in X
        print("--")
    end
    println()
    print("\t ")
    for x in X
        print(" ", x - 1 + 'a')
    end
    println()
    println()
end

function move_from_LAN(input::String, pos::Position)::Move
    if length(input) >= 4
        x0 = Int8(input[1] - 'a' + 1)
        y0 = Int8(input[2] - '1' + 1)
        x1 = Int8(input[3] - 'a' + 1)
        y1 = Int8(input[4] - '1' + 1)
        if !withinboard(x0, y0) || !withinboard(x1, y1)
            return NOMOVE
        end
        p = pos.board[x0, y0]
        promote = p
        if length(input) >= 5
            promote = input[5]
        end
        if pos.toplay == -1 && promote == 'Q'
            promote = 'q'
        end
        if pos.toplay == -1 && promote == 'N'
            promote = 'n'
        end
        for move in LegalMoves(pos)
            if (move.x0 == x0) && (move.y0 == y0) && (move.x1 == x1) && (move.y1 == y1) && (move.promote == promote)
                return move
            end
        end
    end
    return NOMOVE
end

function print_move(move::Move)
    print('a' + move.x0 - 1, move.y0, 'a' + move.x1 - 1, move.y1)
    if ispromotion(move)
        print(move.promote)
    end
end

function print_move(move::Move, Dx::Integer, Dy::Integer)
    print_move(move)
    if Dx != 0
        print("/D", 'a' + Dx - 1, Dy)
    else
        print("/D??")
    end
end

function print_legal_moves(pos::Position)
    for move in LegalMoves(pos)
        print_move(move)
        println()
    end
end

function get_FEN(pos::Position)
    code = ""
    for y in 8:-1:1
        nempty = 0
        for x in 1:8
            p = pos.board[x,y]
            if p == '.'
                nempty += 1
            end
            if (nempty > 0) && ((p != '.') || (x == 8))
                code *= string(nempty)
                nempty = 0
            end
            if (p != '.')
                code *= p
            end
        end
        if y > 1
            code *= "/"
        end
    end
    code *= " "
    code *= (pos.toplay == 1 ? "w" : "b")
    code *= " "
    code *= (pos.wck == 1 ? "K" : "")
    code *= (pos.wcq == 1 ? "Q" : "")
    code *= (pos.bck == 1 ? "k" : "")
    code *= (pos.bcq == 1 ? "q" : "")
    code *= " "
    if pos.epx != 0
        code *= (pos.epx - 1 + 'a')
        code *= (pos.toplay == 1 ? '6' : '3')
    else
        code *= "-"
    end
end

function read_FEN(s::String)::Position
    board = ['.' for _ in 1:8, _ in 1:8]
    k = 1
    y = 8
    wck = false
    wcq = false
    bck = false
    bcq = false
    epx = 0
    toplay = 1
    Dx = 0
    Dy = 0
    while y > 0
        x = 1
        while x < 9
            p = s[k]
            k += 1
            if isdigit(p)
                x += parse(Int, p)
                continue
            elseif p != '/'
                board[x,y] = p
                if p == 'D'
                    Dx = x
                    Dy = y
                end
                x += 1
            end
        end
        y -= 1
    end
    while (k <= length(s))
        if s[k] == 'K'
            wck = true
        elseif s[k] == 'k'
            bck = true
        elseif s[k] == 'Q'
            wcq = true
        elseif s[k] == 'q'
            bcq = true
        elseif s[k] == 'b'
            toplay = -1
        elseif ('a' <= s[k] <= 'h')
            epx = s[k] - 'a' + 1
        end
        k += 1
    end
    pos = Position(board, toplay, Dx, Dy, epx, wcq, wck, bcq, bck, 0, 0, 0, 0)
    (pos.mgv, pos.egv, pos.pcv) = eval(pos)
    pos.hash = get_hash(pos)
    return pos 
end



