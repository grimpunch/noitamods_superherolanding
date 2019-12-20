dofile( "data/scripts/lib/coroutines.lua" )
dofile( "data/scripts/lib/utilities.lua" )
dofile( "data/scripts/perks/perk_list.lua" )

-- all functions below are optional and can be left out

--[[

function OnModPreInit()
	print("Mod - OnModPreInit()") -- First this is called for all mods
end

function OnModInit()
	print("Mod - OnModInit()") -- After that this is called for all mods
end

function OnModPostInit()
	print("Mod - OnModPostInit()") -- Then this is called for all mods
end

function OnPlayerSpawned( player_entity ) -- This runs when player entity has been created
	GamePrint( "OnPlayerSpawned() - Player entity id: " .. tostring(player_entity) )
end

function OnWorldInitialized() -- This is called once the game world is initialized. Doesn't ensure any world chunks actually exist. Use OnPlayerSpawned to ensure the chunks around player have been loaded or created.
	GamePrint( "OnWorldInitialized() " .. tostring(GameGetFrameNum()) )
end

function OnWorldPreUpdate() -- This is called every time the game is about to start updating the world
	GamePrint( "Pre-update hook " .. tostring(GameGetFrameNum()) )
end

function OnWorldPostUpdate() -- This is called every time the game has finished updating the world
	GamePrint( "Post-update hook " .. tostring(GameGetFrameNum()) )
end

]]--

-- This code runs when all mods' filesystems are registered
-- ModLuaFileAppend( "data/scripts/gun/gun_actions.lua", "mods/example/files/actions.lua" ) -- Basically dofile("mods/example/files/actions.lua") will appear at the end of gun_actions.lua
-- ModMagicNumbersFileAdd( "mods/example/files/magic_numbers.xml" ) -- Will override some magic numbers using the specified file
-- ModRegisterAudioEventMappings( "mods/example/files/audio_events.txt" ) -- Use this to register custom fmod events. Event mapping files can be generated via File -> Export GUIDs in FMOD Studio.
-- ModMaterialsFileAdd( "mods/example/files/materials_rainbow.xml" ) -- Adds a new 'rainbow' material to materials

--print("Example mod init done")

ModLuaFileAppend( "data/scripts/perks/perk_list.lua", "data/perks/superlandperk.lua" )

local playerYVel = 0;
local stompMin = 4.8;
local gonnaStomp = false;
local repelEnt = nil;

function AddRepelCharge(entityToAttachTo)
	local x,y = EntityGetTransform( entityToAttachTo )
	repelEnt = EntityLoad( "mods/superherolanding/data/entities/repel_field.xml", x, y )
	EntityAddChild( entityToAttachTo, repelEnt )
end

function RemoveRepelCharge(entityToRemoveFrom)
	EntityRemoveFromParent(repelEnt)
	if(repelEnt ~= nil) then
		EntityKill(repelEnt)
	end
	repelEnt = nil
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
				print( "Landing threshold reached: ", vel_y )
				ComponentSetValue(player_data, "destroy_ground", 500)
				ComponentSetValue(player_data, "eff_hg_damage_max", 2500)
				ComponentSetValue(player_data, "eff_hg_damage_min", 1000)
				ComponentSetValue(player_data, "eff_hg_size_x", 12)
				ComponentSetValue(player_data, "eff_hg_size_y", 4)
				AddRepelCharge(player_entity)
				gonnaStomp = true;
			end
			if(gonnaStomp and onGround ~= 1) then
				GameScreenshake( playerYVel )
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
			if (onGround == 1 and gonnaStomp == true) then 
				print( "Reseting SUPERHERO_LANDING")
				GameScreenshake( 4 * playerYVel, 2 * playerYVel, 2 )
				ComponentSetValue(player_data, "destroy_ground", 0)
				ComponentSetValue(player_data, "eff_hg_damage_max", 95)
				ComponentSetValue(player_data, "eff_hg_damage_min", 10)
				ComponentSetValue(player_data, "eff_hg_size_x", 6.42)
				ComponentSetValue(player_data, "eff_hg_size_y", 5.14)
				gonnaStomp = false;
				RemoveRepelCharge(player_entity)
			end		
		end
	end
end

