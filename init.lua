dofile( "data/scripts/lib/coroutines.lua" )
dofile( "data/scripts/lib/utilities.lua" )
dofile( "data/scripts/perks/perk_list.lua" )

-- all functions below are optional and can be left out

--[[

function OnModPreInit()
	-- print("Mod - OnModPreInit()") -- First this is called for all mods
end

function OnModInit()
	-- print("Mod - OnModInit()") -- After that this is called for all mods
end

function OnModPostInit()
	-- print("Mod - OnModPostInit()") -- Then this is called for all mods
end

function OnPlayerSpawned( player_entity ) -- This runs when player entity has been created
	Game-- print( "OnPlayerSpawned() - Player entity id: " .. tostring(player_entity) )
end

function OnWorldInitialized() -- This is called once the game world is initialized. Doesn't ensure any world chunks actually exist. Use OnPlayerSpawned to ensure the chunks around player have been loaded or created.
	Game-- print( "OnWorldInitialized() " .. tostring(GameGetFrameNum()) )
end

function OnWorldPreUpdate() -- This is called every time the game is about to start updating the world
	Game-- print( "Pre-update hook " .. tostring(GameGetFrameNum()) )
end

function OnWorldPostUpdate() -- This is called every time the game has finished updating the world
	Game-- print( "Post-update hook " .. tostring(GameGetFrameNum()) )
end

]]--

-- This code runs when all mods' filesystems are registered
-- ModLuaFileAppend( "data/scripts/gun/gun_actions.lua", "mods/example/files/actions.lua" ) -- Basically dofile("mods/example/files/actions.lua") will appear at the end of gun_actions.lua
-- ModMagicNumbersFileAdd( "mods/example/files/magic_numbers.xml" ) -- Will override some magic numbers using the specified file
-- ModRegisterAudioEventMappings( "mods/example/files/audio_events.txt" ) -- Use this to register custom fmod events. Event mapping files can be generated via File -> Export GUIDs in FMOD Studio.
-- ModMaterialsFileAdd( "mods/example/files/materials_rainbow.xml" ) -- Adds a new 'rainbow' material to materials

---- print("Example mod init done")

ModLuaFileAppend( "data/scripts/perks/perk_list.lua", "data/perks/superlandperk.lua" )

local playerYVel = 0;
local stompMin = 4.8;
local stompMax = 5.7;
local gonnaStomp = false;
local bigStomp = false;
local repelEnt = nil;
local timeonground= 0;
local damagecheckdone = false;

local RADIUS = 50.0
local MAX_STRENGTH = 20.0
local MIN_STRENGTH = 2

local function distance(x, y, x2, y2)

	return math.sqrt(((x - x2)^2) + ((y - y2)^2))

end

local function length(x, y)

	return math.sqrt((x * x) + (y * y))

end

local function get_phys_ents(me, x, y, rad)

	local tbl = {}
	local near = EntityGetInRadius(x, y, rad)

	if (near == nil) then

		return tbl

	end

	for k,v in pairs(near) do

		local body = EntityGetComponent(v, "PhysicsBodyComponent")
    
		if (body ~= nil) then

			table.insert(tbl, v)
			
		end

	end

	return tbl

end

function AddRepelCharge(entityToAttachTo)
	local x,y = EntityGetTransform( entityToAttachTo )
	if(repelEnt == nil) then
		repelEnt = EntityLoad( "mods/superherolanding/data/entities/repel_field.xml", x, y )
		EntityAddChild( entityToAttachTo, repelEnt )
	end
end

function RemoveRepelCharge(entityToRemoveFrom)
	if(repelEnt ~= nil) then
		EntityRemoveFromParent(repelEnt)
		EntityKill(repelEnt)
	end
	repelEnt = nil
end


function dmgCheck()

	local player_entity = ( EntityGetWithTag( "player_unit" ) ) [1]
	if( player_entity ~= nil ) then
		local x, y = EntityGetTransform(player_entity)
		-- print("player y vel", playerYVel)
		-- print("bigStomp", tostring(bigStomp))
		shoot_projectile( player_entity, "data/entities/projectiles/deck/powerdigger.xml", x, y, -1,0 )
		if(bigStomp or playerYVel > stompMax) then
			-- print("bigStomp")
			shoot_projectile( player_entity, "mods/superherolanding/data/entities/landing_impact.xml", x, y+20, 0,0 )
			bigStomp = false;
		end
		
		local props = get_phys_ents(player_entity, x, y, RADIUS)
		for i, prop in pairs(props) do
			-- print("i",i)
			local x2, y2 = EntityGetTransform(prop)
			local dist = distance(x, y, x2, y2)
			-- print("dist ", dist)
			if (dist < RADIUS) then
				edit_component(prop, "DamageModelComponent", function(comp,vars)
					-- print ("comp ~=nil", tonumber(comp ~= nil))
					if(comp ~= nil) then
						local hp = tonumber(ComponentGetValue( comp, "hp" ))
						hp = hp -1
						-- print("hp ", hp)
						if(hp <= 0) then
							edit_component( prop, "ExplodeOnDamageComponent", function(incomp,invars)
							if( incomp ~= nil ) then
								EntityLoad( "data/entities/projectiles/explosion.xml", x2, y2 )
								damagecheckdone = true;
								end
							end)
							EntityKill(prop)
							--damagecheckdone = true;--
						else
							ComponentSetValue(comp, "hp", tostring(hp))
						end
					end
				end)
				
				local dir_x = x - x2
				local dir_y = y - y2
						
				local len = length(dir_x, dir_y)

				if (len == 0) then

					len = 0.001

				end
				
				local dir_x = dir_x / len
				local dir_y = dir_y / len
				
				local pot = EntityGetComponent(prop, "PotionComponent")
				if(pot ~= nil) then
					EntityKill(prop)
					--damagecheckdone = true;--
				end
				
			end

		end
	end

end

function OnWorldPreUpdate()
	--  --
	local player_entity = ( EntityGetWithTag( "player_unit" ) ) [1]
	if( player_entity ~= nil ) then
		local player_data = EntityGetFirstComponent(player_entity, "CharacterDataComponent") 
		if( player_data ~= nil and player_data ~= 0 and vel_comp_player ~= 0) then
			local vel_x,vel_y = GameGetVelocityCompVelocity(player_entity)
			local onGround = tonumber(ComponentGetValue(player_data,  "is_on_ground"))
			
			playerYVel = tonumber( vel_y )
			if(gonnaStomp == false and playerYVel > stompMin and GameHasFlagRun( get_perk_picked_flag_name( "SUPERHERO_LANDING" ) ) ) then
				-- -- print( "Landing threshold reached: ", vel_y ) --
				ComponentSetValue(player_data, "destroy_ground", 1200)
				ComponentSetValue(player_data, "eff_hg_damage_max", 4100)
				ComponentSetValue(player_data, "eff_hg_damage_min", 3000)
				ComponentSetValue(player_data, "eff_hg_size_x", 10)
				ComponentSetValue(player_data, "eff_hg_size_y", 8)
				AddRepelCharge(player_entity)
				if(playerYVel >= stompMax and bigStomp == false)then
					bigStomp = true;
					-- print("will big stomp", playerYVel)
				end
				gonnaStomp = true;
				damagecheckdone = false;
			end
			if(gonnaStomp and onGround ~= 1) then
				GameScreenshake( playerYVel )
				if(playerYVel < stompMin) then
					-- cancel stomp if player y velocity reduces --
					gonnaStomp = false;
					
					--damagecheckdone = true;--
					-- -- print( "Reseting SUPERHERO_LANDING") -- 
					ComponentSetValue(player_data, "destroy_ground", 0)
					ComponentSetValue(player_data, "eff_hg_damage_max", 95)
					ComponentSetValue(player_data, "eff_hg_damage_min", 10)
					ComponentSetValue(player_data, "eff_hg_size_x", 6.42)
					ComponentSetValue(player_data, "eff_hg_size_y", 5.14)
					RemoveRepelCharge(player_entity)		
					timeonground = 0;
				end
			end
		end
		
	end
end

function OnWorldPostUpdate() -- This is called every time the game has finished updating the world
	local player_entity = ( EntityGetWithTag( "player_unit" ) ) [1]
	if( player_entity ~= nil ) then
		local player_data = EntityGetFirstComponent(player_entity, "CharacterDataComponent") 
		if( player_data ~= nil) then
			local onGround = tonumber(ComponentGetValue(player_data,  "is_on_ground"))
			if(gonnaStomp == true and onGround == 1) then
				GameScreenshake( 12 * playerYVel, 2 * playerYVel, 2 )
				-- -- print( "SHAKE ") --
				timeonground = timeonground + 1
				if (gonnaStomp and timeonground < 5) then
					
					-- print ("begin dmg check") 
					dmgCheck()
					 -- print ("end dmg check") 
				end
				if(timeonground > 10) then
					gonnaStomp = false;
					bigStomp = false;
					damagecheckdone = true;
					-- -- print( "Reseting SUPERHERO_LANDING") --
					ComponentSetValue(player_data, "destroy_ground", 0)
					ComponentSetValue(player_data, "eff_hg_damage_max", 95)
					ComponentSetValue(player_data, "eff_hg_damage_min", 10)
					ComponentSetValue(player_data, "eff_hg_size_x", 6.42)
					ComponentSetValue(player_data, "eff_hg_size_y", 5.14)
					RemoveRepelCharge(player_entity)	
					timeonground = 0;
				end
			end
		end
	end
end


