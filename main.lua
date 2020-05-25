--[[
    GD50 2018
    Pong Remake

    pong-13
    "The AI Update"
    Updated by Tommy Scheper
    tdscheper@gmail.com
    Allows single player to play against AI on easy, medium, or hard difficulty

    -- Main Program --
    Author: Colton Ogden
    cogden@cs50.harvard.edu
    Originally programmed by Atari in 1972. Features two
    paddles, controlled by players, with the goal of getting
    the ball past your opponent's edge. First to 10 points wins.
    This version is built to more closely resemble the NES than
    the original Pong machines or the Atari 2600 in terms of
    resolution, though in widescreen (16:9) so it looks nicer on 
    modern systems.
]]

-- push is a library that will allow us to draw our game at a virtual
-- resolution, instead of however large our window is; used to provide
-- a more retro aesthetic
--
-- https://github.com/Ulydev/push
push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
--
-- https://github.com/vrld/hump/blob/master/class.lua
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

-- size of our actual window
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

-- size we're trying to emulate with push
VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

-- margin between paddles and left/right edge of screen
HORIZONTAL_MARGIN = 10

-- size of paddle
PADDLE_WIDTH = 5
PADDLE_HEIGHT = 20

-- size of ball
BALL_WIDTH = 4
BALL_HEIGHT = 4

-- defualt paddle positions
P1_X = HORIZONTAL_MARGIN
P1_Y = VIRTUAL_HEIGHT / 2 - PADDLE_HEIGHT / 2
P2_X = VIRTUAL_WIDTH - HORIZONTAL_MARGIN - PADDLE_WIDTH
P2_Y = VIRTUAL_HEIGHT / 2 - PADDLE_HEIGHT / 2

-- default ball position: middle of screen
BALL_X = VIRTUAL_WIDTH / 2 - BALL_WIDTH / 2
BALL_Y = VIRTUAL_HEIGHT / 2 - BALL_HEIGHT / 2

-- paddle movement speed
PADDLE_SPEED = 200
EASY_AI_PADDLE_SPEED = 100
MEDIUM_AI_PADDLE_SPEED = 150
HARD_AI_PADDLE_SPEED = 200

-- ball movement speed multiplier
DX_INCREASE = 1.03

--[[
    Called just once at the beginning of the game; used to set up
    game objects, variables, etc. and prepare the game world.
]]
function love.load()
    -- set love's default filter to "nearest-neighbor", which essentially
    -- means there will be no filtering of pixels (blurriness), which is
    -- important for a nice crisp, 2D look
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- set the title of our application window
    love.window.setTitle('Pong')

    -- seed the RNG so that calls to random are always random
    math.randomseed(os.time())

    -- initialize our nice-looking retro text fonts
    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf', 16)
    scoreFont = love.graphics.newFont('font.ttf', 32)
    love.graphics.setFont(smallFont)

    -- set up our sound effects; later, we can just index this table and
    -- call each entry's `play` method
    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['wall_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static'),
        ['choice'] = love.audio.newSource('sounds/menu_select.wav', 'static'),
        ['play'] = love.audio.newSource('sounds/play.wav', 'static'),
        ['start'] = love.audio.newSource('sounds/start.wav', 'static')
    }
    
    -- initialize our virtual resolution, which will be rendered within our
    -- actual window no matter its dimensions
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, { 
        fullscreen = false,
        resizable = true,
        vsync = true,
        canvas = false 
    })

    -- initialize our player paddles; make them global so that they can be
    -- detected by other functions and modules
    player1 = Paddle(P1_X, P1_Y, PADDLE_WIDTH, PADDLE_HEIGHT, 'Player 1')
    if gameMode == '2' then
        player2 = Paddle(P2_X, P2_Y, PADDLE_WIDTH, PADDLE_HEIGHT, 'Player 2')
    else
        player2 = Paddle(P2_X, P2_Y, PADDLE_WIDTH, PADDLE_HEIGHT, 'CPU')
    end

    -- place a ball in the middle of the screen
    ball = Ball(BALL_X, BALL_Y, BALL_WIDTH, BALL_HEIGHT)

    -- initialize score variables
    player1Score = 0
    player2Score = 0

    -- either going to be 1 or 2; whomever is scored on gets to serve the
    -- following turn
    servingPlayer = 1

    -- player who won the game; not set to a proper value (1 or 2) until we
    -- reach that state in the game
    winningPlayer = 0

    -- the state of our game; can be any of the following:
    -- 1. 'choose mode' (user chooses single or two player)
    -- 2. 'choose difficulty' (user chooses AI difficulty)
    -- 3. 'start' (the beginning of the game, before first serve)
    -- 4. 'serve' (waiting on a key press to serve the ball)
    -- 5. 'play' (the ball is in play, bouncing between paddles)
    -- 6. 'done' (the game is over, with a victor, ready for restart)
    gameState = 'choose mode'
end

--[[
    Called whenever we change the dimensions of our window, as by dragging
    out its bottom corner, for example. In this case, we only need to worry
    about calling out to `push` to handle the resizing. Takes in a `w` and
    `h` variable representing width and height, respectively.
]]
function love.resize(w, h)
    push:resize(w, h)
end

--[[
    Called every frame, passing in `dt` since the last frame. `dt`
    is short for `deltaTime` and is measured in seconds. Multiplying
    this by any changes we wish to make in our game will allow our
    game to perform consistently across all hardware; otherwise, any
    changes we make will be applied as fast as possible and will vary
    across system hardware.
]]
function love.update(dt)
    if gameState == 'serve' then
        -- before switching to play, initialize ball's velocity based
        -- on player who last scored
        ball.dy = math.random(-50, 50)
        if servingPlayer == 1 then
            ball.dx = math.random(140, 200)
        else
            ball.dx = -math.random(140, 200)
        end
    elseif gameState == 'play' then
        -- detect ball collision with paddles, reversing dx if true and
        -- slightly increasing it, then altering the dy based on the position
        -- at which it collided, then playing a sound effect
        if ball:collides(player1) then
            ball.dx = -ball.dx * DX_INCREASE
            ball.x = player1.x + PADDLE_WIDTH

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end
        if ball:collides(player2) then
            ball.dx = -ball.dx * DX_INCREASE
            ball.x = player2.x - BALL_WIDTH

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end

        -- detect upper and lower screen boundary collision, playing a sound
        -- effect and reversing dy if true
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        if ball.y >= VIRTUAL_HEIGHT - BALL_HEIGHT then
            ball.y = VIRTUAL_HEIGHT - BALL_HEIGHT
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- if we reach the left or right edge of the screen, go back to serve
        -- and update the score and serving player
        if ball.x < 0 then
            servingPlayer = 1
            player2Score = player2Score + 1
            sounds['score']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player2Score == 10 then
                winningPlayer = 2
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end

        if ball.x > VIRTUAL_WIDTH then
            servingPlayer = 2
            player1Score = player1Score + 1
            sounds['score']:play()

            if player1Score == 10 then
                winningPlayer = 1
                gameState = 'done'
            else
                gameState = 'serve'
                ball:reset()
            end
        end
    end

    -- paddles can move no matter what state we're in
    -- player 1
    if love.keyboard.isDown('w') then
        player1.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown('s') then
        player1.dy = PADDLE_SPEED
    else
        player1.dy = 0
    end

    -- player 2
    if gameMode == '2' then
        if love.keyboard.isDown('up') then
            player2.dy = -PADDLE_SPEED
        elseif love.keyboard.isDown('down') then
            player2.dy = PADDLE_SPEED
        else
            player2.dy = 0
        end
    -- AI
    else
        -- Easy difficulty
        if difficulty == 'e' then
            if ball.y < player2.y and ball.x >= VIRTUAL_WIDTH / 2 then
                player2.dy = -EASY_AI_PADDLE_SPEED
            elseif ball.y > player2.y and ball.x >= VIRTUAL_WIDTH / 2 then
                player2.dy = EASY_AI_PADDLE_SPEED
            else
                player2.dy = 0
            end
        -- Medium difficulty
        elseif difficulty == 'm' then
            if ball.y < player2.y and ball.x >= VIRTUAL_WIDTH / 2 then
                player2.dy = -MEDIUM_AI_PADDLE_SPEED
            elseif ball.y > player2.y and ball.x >= VIRTUAL_WIDTH / 2 then
                player2.dy = MEDIUM_AI_PADDLE_SPEED
            else
                player2.dy = 0
            end
        -- Hard difficulty
        elseif difficulty == 'h' then
            if ball.y < player2.y and ball.x >= VIRTUAL_WIDTH / 2 then
                player2.dy = -HARD_AI_PADDLE_SPEED
            elseif ball.y > player2.y and ball.x >= VIRTUAL_WIDTH / 2 then
                player2.dy = HARD_AI_PADDLE_SPEED
            else
                player2.dy = 0
            end
        end
    end
    -- update our ball based on its DX and DY only if we're in play state;
    -- scale the velocity by dt so movement is framerate-independent
    if gameState == 'play' then
        ball:update(dt)
    end

    player1:update(dt)
    player2:update(dt)
end

--[[
    A callback that processes key strokes as they happen, just the once.
    Does not account for keys that are held down, which is handled by a
    separate function (`love.keyboard.isDown`). Useful for when we want
    things to happen right away, just once, like when we want to quit.
]]
function love.keypressed(key)
    -- `key` will be whatever key this callback detected as pressed
    if key == 'escape' then
        -- the function LÖVE2D uses to quit the application
        love.event.quit()
    -- press 1 or 2 for single/two player
    elseif key == '1' or key == '2' then
        if gameState == 'choose mode' then
            sounds['choice']:play()
            gameMode = key
            if gameMode == '2' then
                gameState = 'start'
            else
                gameState = 'choose difficulty'
            end
        end
    -- press E, M, or H for easy/medium/hard difficulty
    elseif key == 'e' or key == 'm' or key == 'h' then
        sounds['choice']:play()
        difficulty = key
        gameState = 'start'
    -- if we press enter during either the start or serve phase, it should
    -- transition to the next appropriate state
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            sounds['play']:play()
            gameState = 'serve'
        elseif gameState == 'serve' then
            sounds['start']:play()
            gameState = 'play'
        elseif gameState == 'done' then
            -- game is simply in a restart phase here, but will set the serving
            -- player to the opponent of whomever won for fairness!
            sounds['play']:play()
            gameState = 'serve'

            ball:reset()

            -- reset scores to 0
            player1Score = 0
            player2Score = 0

            -- decide serving player as the opposite of who won
            if winningPlayer == 1 then
                servingPlayer = 2
            else
                servingPlayer = 1
            end
        end
    end
end

--[[
    Called each frame after update; is responsible simply for
    drawing all of our game objects and more to the screen.
]]
function love.draw()
    -- begin drawing with push, in our virtual resolution
    push:start()

    love.graphics.clear(40, 45, 52, 255)

    -- render different things depending on which part of the game we're in
    if gameState == 'choose mode' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press 1 for single player', 0, 20, VIRTUAL_WIDTH, 
                             'center')
        love.graphics.printf('Press 2 for two player', 0, 30, VIRTUAL_WIDTH, 
                             'center')
    elseif gameState == 'choose difficulty' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press E for easy difficulty', 0, 20, 
                             VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press M for medium difficulty', 0, 30, 
                             VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press H for hard difficulty', 0, 40, 
                             VIRTUAL_WIDTH, 'center')
    elseif gameState == 'start' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to begin!', 0, 20, VIRTUAL_WIDTH, 
            'center')
    elseif gameState == 'serve' then
        -- UI messages
        love.graphics.setFont(smallFont)
        if servingPlayer == 1 then
            love.graphics.printf(player1.name .. "'s serve!", 0, 10, 
                                 VIRTUAL_WIDTH, 'center')
        else
            love.graphics.printf(player2.name .. "'s serve!", 0, 10, 
                                 VIRTUAL_WIDTH, 'center')
        end
        love.graphics.printf('Press Enter to serve!', 0, 20, VIRTUAL_WIDTH, 
                             'center')
    elseif gameState == 'play' then
        -- no UI messages to display in play
    elseif gameState == 'done' then
        -- UI messages
        love.graphics.setFont(largeFont)
        if winningPlayer == 1 then
            love.graphics.printf(player1.name .. ' wins!', 0, 10, VIRTUAL_WIDTH, 
                                 'center')
        else
            love.graphics.printf(player2.name .. ' wins!', 0, 10, VIRTUAL_WIDTH, 
                                 'center')
        end
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to restart!', 0, 30, VIRTUAL_WIDTH, 
                             'center')
    end

    -- show the score before ball is rendered so it can move over the text
    displayScore()
    
    player1:render()
    player2:render()
    ball:render()

    -- display FPS for debugging; simply comment out to remove
    displayFPS()

    -- end our drawing to push
    push:finish()
end

--[[
    Simple function for rendering the scores.
]]
function displayScore()
    -- score display
    love.graphics.setFont(scoreFont)

    score1 = tostring(player1Score)
    score2 = tostring(player2Score)

    p1_score_x = VIRTUAL_WIDTH / 3 - scoreFont:getWidth(score1) / 2
    p2_score_y = (2 / 3) * VIRTUAL_WIDTH - scoreFont:getWidth(score2) / 2
    score_y = VIRTUAL_HEIGHT / 3 - scoreFont:getHeight(score1) / 2

    love.graphics.print(score1, p1_score_x, score_y)
    love.graphics.print(score2, p2_score_x, score_y)
end

--[[
    Renders the current FPS.
]]
function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 255, 0, 255)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
    love.graphics.setColor(255, 255, 255, 255)
end
