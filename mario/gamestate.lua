
-- Array to hold all the running game states
mario.games = {}

-- Store all the currently playing players
mario.players = {}

-- Amount of points that will award a life
local score_for_life_award = 5000

---------------------------------------------------------
-- Public functions (these can be called from any other place)

-- Start the game from the spawn block at position "pos" activated by "player"
function mario.game_start(pos, player, gamedef)
	-- create an id unique for the given position
	local id = minetest.pos_to_string(pos)
	local player_name = player:get_player_name()

	-- make sure any previous game with the same id has ended
	local gamestate = mario.games[id]
	if gamestate then
		minetest.chat_send_player(name, "A game is already in progress for player " .. gamestate.player_name)
		return
	end

	-- Create a new game state with that id and add it to the game list
	gamedef = gamedef or {}
	gamestate = {
		id = id,
		player_name = player_name,
		pos = pos,
		player_start = vector.add(pos, (gamedef.player_start or {x=16,y=0,z=1})),
		turtle1_start = vector.add(pos, (gamedef.turtle_start or {x=3,y=0.5,z=12})),
		turtle2_start = vector.add(pos, (gamedef.turtle_start or {x=30,y=0.5,z=12})),
		coin_total =  gamedef.coin_total or 84,
		speed = gamedef.speed or 2,
		lives = gamedef.lives or 3,
		scorename = gamedef.scorename,
		level = 1,
		score = 0,
		awarded_lives = 0,
		coin_count = 0,
	}
 	mario.games[id] = gamestate
	mario.players[id] = player

	minetest.log("action","New mario game started at " .. id .. " by " .. gamestate.player_name)

	-- place schematic
	local schem = gamedef
	minetest.place_schematic({x=pos.x-1,y=pos.y-2,z=pos.z-2},gamedef.schematic,0, "air", true)

	-- Set start positions
	mario.game_reset(id, player)
	mario.update_hud(id, player)
	minetest.sound_play("mario-game-start", {pos = pos,max_hear_distance = 40,gain = 10.0,})
end

-- Finish the game with the given id
function mario.game_end(id)
	mario.remove_turtles(id)
	local gamestate = mario.games[id]
	local player = mario.players[id] or minetest.get_player_by_name(gamestate.player_name)
	if player then
		mario.remove_hud(player, gamestate.player_name)
		player:moveto(vector.add(gamestate.pos,{x=0.5,y=0.5,z=-1.5}))
	end
	-- Save score
	if gamestate.scorename then
		local ranking = myhighscore.save_score(gamestate.scorename, {
			player = gamestate.player_name,
			score = gamestate.score
		})
		if ranking then
			minetest.chat_send_player(gamestate.player_name, "You made it to the highscores! Your Ranking: " .. ranking)
		end
	end
	-- Clear the data
	mario.games[id] = nil
	mario.players[id] = nil
end

-- Resets the game to the start positions
function mario.game_reset(id, player)
	local gamestate = mario.games[id]
	minetest.log("action", "resetting game " .. id)

	-- Save the time when the game was last resetted (to solve timing issues)
	local last_reset = os.time()

	gamestate.last_reset = last_reset

	-- Position the player
	local player = player or minetest.get_player_by_name(gamestate.player_name)
	player:setpos(gamestate.player_start)

	-- Spawn the turtles and assign the game id to each turtle
	minetest.after(2, function()
		if mario.games[id] and last_reset == mario.games[id].last_reset then
			local turtle = minetest.add_entity(gamestate.turtle_start, "mario:turtle")
			turtle:get_luaentity().gameid = id
		end
	end)
	minetest.after(2, function()
		if mario.games[id] and last_reset == mario.games[id].last_reset then
			local turtle = minetest.add_entity(gamestate.turtle_start, "mario:turtle2")
			turtle:get_luaentity().gameid = id
		end
	end)
	minetest.after(45, function()
		if mario.games[id] and last_reset == mario.games[id].last_reset then
			local turtle = minetest.add_entity(gamestate.turtle_start, "mario:turtle3")
			turtle:get_luaentity().gameid = id
		end
	end)
	minetest.after(45, function()
		if mario.games[id] and last_reset == mario.games[id].last_reset then
			local turtle = minetest.add_entity(gamestate.turtle_start, "mario:turtle4")
			turtle:get_luaentity().gameid = id
		end
	end)
end

-- Remove all the turtles from the board with the given id
function mario.remove_turtles(id)
	local gamestate = mario.games[id]
	if not gamestate then return end

	-- Remove all non-players (turtles!)
	local boardcenter = vector.add(gamestate.pos, {x=13,y=0.5,z=15})
	for index, object in ipairs(minetest.get_objects_inside_radius(boardcenter,20)) do
		if object:is_player() ~= true then
		object:remove()
		end
	end
end

-- Add a mushroom to the game board
function mario.add_mushroom(id)
	local gamestate = mario.games[id]
	if not gamestate then return end
	local node = {}
	-- Different mushroom will be used depending on the level
	if gamestate.level == 1 then
		node.name = "mario:mushroom"
	end
	local pos = vector.add(gamestate.player_start,{x=0,y=12,z=0})
	minetest.set_node(pos, node)
	print(node.param2)
	-- Set the timer for the mushroom to disappear
	minetest.get_node_timer(pos):start(60)
end

-- A player got a coin, update the state
function mario.on_player_got_coin(player)
	local name = player:get_player_name()
	local gamestate = mario.get_game_by_player(name)
	if not gamestate then return end

	gamestate.coin_count = gamestate.coin_count + 1
	gamestate.score = gamestate.score + 10
	mario.update_hud(gamestate.id, player)
	minetest.sound_play("mario-coin", {object = player, max_hear_distance = 6})

	if gamestate.coin_count == 70 or gamestate.coin_count == 180 then
		mario.add_mushroom(gamestate.id)
	elseif gamestate.coin_count >= gamestate.coin_total then
		minetest.chat_send_player(name, "You cleared the board!")

		mario.remove_turtles(gamestate.id)
		gamestate.coin_count = 0
		gamestate.level = gamestate.level + 1
		gamestate.speed = gamestate.level + 1

		minetest.after(3.0, function()
			minetest.chat_send_player(name, "Starting Level "..gamestate.level)
			-- place schematic
			local schem = minetest.get_modpath("mario").."/schems/mario.mts"
			minetest.place_schematic(vector.add(gamestate.pos, {x=-1,y=-2,z=-2}),schem,0, "air", true)

			-- Set start positions
			mario.game_reset(gamestate.id, player)
			minetest.sound_play("mario-game-start", {pos = pos,max_hear_distance = 40,gain = 10.0,})
		end)
	end

	if gamestate.score / score_for_life_award >= 1 + gamestate.awarded_lives then
		minetest.chat_send_player(name, "You reached " .. gamestate.score .. " points and earned an extra life!")
		gamestate.lives = gamestate.lives + 1
		gamestate.awarded_lives = gamestate.awarded_lives + 1
	end
end

-- A player got a mushroom, update the state
function mario.on_player_got_mushroom(player, points)
	local name = player:get_player_name()
	local gamestate = mario.get_game_by_player(name)
	if not gamestate then return end
	gamestate.score = gamestate.score + points
	minetest.chat_send_player(name, points .. " bonus points!")
	minetest.sound_play("mario-bonus", {pos = pos, max_hear_distance = 6})
end

-- Get the game that the given player is playing
function mario.get_game_by_player(player_name)
	for _,gamestate in pairs(mario.games) do
		if gamestate.player_name == player_name then
			return gamestate
		end
	end
end

---------------------------------------------------------
--- Private functions (only can be used inside this file)


-- Called every 0.5 seconds for each player that is currently playing
local function on_player_gamestep(player, gameid)
	local player_pos = player:getpos()
	local positions = {
		{x=0.5,y=0.5,z=0.5},
		{x=-0.5,y=0.5,z=-0.5},
	}
	for _,pos in pairs(positions) do
		pos = vector.add(player_pos, pos)
		local node = minetest.get_node(pos)
		if node.name == "mario:coin_1" then
			minetest.remove_node(pos)
			mario.on_player_got_coin(player)
		elseif node.name == "mario:coin_2" then
			minetest.remove_node(pos)
			mario.on_player_got_power_coin(player)
		elseif node.name == "mario:cherrys" then
			minetest.remove_node(pos)
			mario.on_player_got_mushroom(player, 100)
		elseif node.name == "mario:strawberry" then
			minetest.remove_node(pos)
			mario.on_player_got_mushroom(player, 300)
		elseif node.name == "mario:orange" then
			minetest.remove_node(pos)
			mario.on_player_got_mushroom(player, 500)
		elseif node.name == "mario:apple" then
			minetest.remove_node(pos)
			mario.on_player_got_mushroom(player, 700)
		end
	end
end

-------------------
--- Execution code


-- Time counters
local tmr_gamestep = 0
minetest.register_globalstep(function(dtime)
	tmr_gamestep = tmr_gamestep + dtime;
	if tmr_gamestep > 0.2 then
		for id,player in pairs(mario.players) do
			on_player_gamestep(player, id)
		end
		tmr_gamestep = 0
	end
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	for id,game in pairs(mario.games) do
		if game.player_name == name then
			mario.game_end(id)
		end
	end
end)

minetest.register_on_shutdown(function()
	minetest.log("action", "Server shuts down. Ending all mario games")
	for id,game in pairs(mario.games) do
		mario.game_end(id)
	end
end)

-- Chatcommand to end the game for the current player
minetest.register_chatcommand("mario_exit", {
	params = "",
	description = "Loads and saves all rooms",
	func = function(name, param)
		local gamestate = mario.get_game_by_player(name)
		if gamestate then
			mario.game_end(gamestate.id)
			minetest.chat_send_player(name, "You are no longer playing mario")
		else
			minetest.chat_send_player(name, "You are not currently in a mario game")
		end
	end
})