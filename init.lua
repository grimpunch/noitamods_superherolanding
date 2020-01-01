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
				ComponentSetValue(player_data, "destroy_ground", 1200)
				ComponentSetValue(player_data, "eff_hg_damage_max", 4100)
				ComponentSetValue(player_data, "eff_hg_damage_min", 3000)
				ComponentSetValue(player_data, "eff_hg_size_x", 10)
				ComponentSetValue(player_data, "eff_hg_size_y", 8)
				AddRepelCharge(player_entity)
				gonnaStomp = true;
				damagecheckdone = false;
			end
			if(gonnaStomp and onGround ~= 1) then
				GameScreenshake( playerYVel )
				if(playerYVel < stompMin) then
					-- cancel stomp if player y velocity reduces --
					gonnaStomp = false;
					damagecheckdone = true;
					print( "Reseting SUPERHERO_LANDING")
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


function dmgCheck()

	local player_entity = ( EntityGetWithTag( "player_unit" ) ) [1]
	if( player_entity ~= nil ) then
		local x, y = EntityGetTransform(player_entity)

		local props = get_phys_ents(player_entity, x, y, RADIUS)
		for i, prop in pairs(props) do

			local x2, y2 = EntityGetTransform(prop)
			local dist = distance(x, y, x2, y2)
			
			if (dist < RADIUS) then
		
				local scale = 1.0 - (dist / RADIUS)
				local power = scale * MAX_STRENGTH

				if (power < MIN_STRENGTH) then
					power = MIN_STRENGTH
				end
				
				edit_component( prop, "ExplodeOnDamageComponent", function(comp,vars)
					if( comp ~= nil ) then
						EntityLoad( "data/entities/projectiles/explosion.xml", x2, y2 )
					end
				end)
				
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
				print( "SHAKE ")
				timeonground = timeonground + 1
				if (damagecheckdone == false) then
					damagecheckdone = true;
					print ("begin dmg check")
					dmgCheck()
					print ("end dmg check")
				end
				if(timeonground > 10) then
					gonnaStomp = false;
					print( "Reseting SUPERHERO_LANDING")
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


