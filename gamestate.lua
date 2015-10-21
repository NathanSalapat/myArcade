
-- Array to hold all the running game states
mypacman.games = {}

---------------------------------------------------------
-- Public functions (these can be called from any other place)

-- Start the game from the spawn block at position "pos" activated by "player"
function mypacman.game_start(pos, player)
	-- create an id unique for the given position
	local id = minetest.pos_to_string(pos)

	-- make sure any previous game with the same id has ended
	if mypacman.games[id] then
		mypacman.game_end(id)
	end

	-- Create a new game state with that id and add it to the game list
	local gamestate = {
		id = id,
		player_name = player:get_player_name(),
		pos = pos,
		start = {x=pos.x+14,y=pos.y+0.5,z=pos.z+16},
		pellet_count = 0,
		level = 1,
		speed = 2,
		lives = 3,
	}
 	mypacman.games[id] = gamestate
	minetest.log("action","New pacman game started at " .. id .. " by " .. gamestate.player_name)

	-- place schematic
	local schem = minetest.get_modpath("mypacman").."/schems/mypacman_3.mts"
	minetest.place_schematic({x=pos.x,y=pos.y-1,z=pos.z-2},schem,0, "air", true)

	-- Set start positions
	mypacman.game_reset(id, player)
	minetest.sound_play("mypacman_beginning", {pos = pos,max_hear_distance = 40,gain = 10.0,})
end

-- Finish the game with the given id
function mypacman.game_end(id)
	mypacman.remove_ghosts(id)
	-- Clear the data
	mypacman.games[id] = nil
end

-- Resets the game to the start positions
function mypacman.game_reset(id, player)
	local gamestate = mypacman.games[id]
	minetest.log("action", "resetting game " .. id)

	-- Position the player
	local player = player or minetest.get_player_by_name(gamestate.player_name)
	player:setpos(gamestate.start)

	-- Spawn the ghosts and assign the game id to each ghost
	minetest.after(2, function()
		local pos = vector.add(gamestate.pos, {x=13,y=0.5,z=19})
		local ghost = minetest.add_entity(pos, "mypacman:inky")
		ghost:get_luaentity().gameid = id
	end)
	minetest.after(12, function()
		local pos = vector.add(gamestate.pos, {x=15,y=0.5,z=19})
		local ghost = minetest.add_entity(pos, "mypacman:pinky")
		ghost:get_luaentity().gameid = id
	end)
	minetest.after(22, function()
		local pos = vector.add(gamestate.pos, {x=13,y=0.5,z=18})
		local ghost = minetest.add_entity(pos, "mypacman:blinky")
		ghost:get_luaentity().gameid = id
	end)
	minetest.after(32, function()
		local pos = vector.add(gamestate.pos, {x=15,y=0.5,z=18})
		local ghost = minetest.add_entity(pos, "mypacman:clyde")
		ghost:get_luaentity().gameid = id
	end)
end

-- Remove all the ghosts from the board with the given id
function mypacman.remove_ghosts(id)
	local gamestate = mypacman.games[id]
	if not gamestate then return end

	-- Remove all non-players (ghosts!)
	local boardcenter = vector.add(gamestate.pos, {x=13,y=0.5,z=15})
	for index, object in ipairs(minetest.get_objects_inside_radius(boardcenter,20)) do
		if object:is_player() ~= true then
		object:remove()
		end
	end
end

-- A player got a pellet, update the state
function mypacman.on_player_got_pellet(player)
	local name = player:get_player_name()
	local gamestate = mypacman.get_game_by_player(name)
	if not gamestate then return end

	gamestate.pellet_count = gamestate.pellet_count + 1
	if gamestate.pellet_count >= 20 then -- 252
		minetest.chat_send_player(name, "You cleared the board!")

		mypacman.remove_ghosts(gamestate.id)
		gamestate.pellet_count = 0
		gamestate.level = gamestate.level + 1
		gamestate.speed = gamestate.level + 1

		minetest.after(3.0, function()
			minetest.chat_send_player(name, "Starting Level "..gamestate.level)
			-- place schematic
			local schem = minetest.get_modpath("mypacman").."/schems/mypacman_3.mts"
			minetest.place_schematic(vector.add(gamestate.pos, {x=0,y=-1,z=-2}),schem,0, "air", true)

			-- Set start positions
			mypacman.game_reset(gamestate.id, player)
			minetest.sound_play("mypacman_beginning", {pos = pos,max_hear_distance = 40,gain = 10.0,})
		end)
	end

end

-- Get the game that the given player is playing
function mypacman.get_game_by_player(player_name)
	for _,gamestate in pairs(mypacman.games) do
		if gamestate.player_name == player_name then
			return gamestate
		end
	end
end

---------------------------------------------------------
--- Private functions (only can be used inside this file)

-- Save Table
local function gamestate_save()
	local data = mypacman.games
	local f, err = io.open(minetest.get_worldpath().."/mypacman_data", "w")
    if err then return err end
	f:write(minetest.serialize(data))
	f:close()
end

--Read Table
local function gamestate_load()
	local f, err = io.open(minetest.get_worldpath().."/mypacman_data", "r")
	if f then
		local data = minetest.deserialize(f:read("*a"))
		f:close()
		return data
	else
		return nil
	end
end

-------------------
--- Execution code

-- load the gamestate from disk
mypacman.games = gamestate_load() or {}

local tmr = 0
--Save Table every 10 seconds
minetest.register_globalstep(function(dtime)
	tmr = tmr + dtime;
	if tmr >= 10 then
		tmr = 0
		gamestate_save()
	end
end)