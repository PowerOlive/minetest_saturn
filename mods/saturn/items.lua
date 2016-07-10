local default_enemy_item_possible_modifications = {
		weight = {-10,10}, -- Given values define a scale of pseudogaussian random value
		volume = {-1,1},
		traction = {-1000,1000},
		rated_power = {-10,10},
		damage = {-10,10},
		cooldown = {-0.1,0.1},
		generated_power = {-10,10},
	}

local default_enemy_generator_item_possible_modifications = {
		weight = {-10,10}, -- Given values define a scale of pseudogaussian random value
		volume = {-1,1},
		traction = {-1000,1000},
		damage = {-10,10},
		cooldown = {-0.1,0.1},
		generated_power = {-10,10},
	}


local default_enemy_weapon_item_possible_modifications = {
		weight = {-10,10},
		volume = {-1,1},
		rated_power = {-10,10},
		damage = {-10,10},
		cooldown = {-0.1,0.1},
	}

local function register_wearable_item(registry_name, tool_definition, stats)
        tool_definition.wield_image = "null.png"
        tool_definition.stack_max = 1
	tool_definition.on_drop = function(itemstack, player, pos)
		minetest.sound_play("saturn_item_drop", {to_player = player:get_player_name()})
		saturn.throw_item(itemstack, player, pos)
		itemstack:clear()
		return itemstack
	end
	minetest.register_tool(registry_name, tool_definition)
	saturn.set_item_stats(registry_name, stats)
	if stats.is_market_item then
		table.insert(saturn.market_items,registry_name)
	end
	if stats.is_enemy_item then
		table.insert(saturn.enemy_items,registry_name)
	end
end

-- Hulls

register_wearable_item("saturn:basic_ship_hull",{
		description = "Basic ship hull",
		inventory_image = "saturn_basic_ship_hull.png",
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
	},{
	weight = 40000,
	volume = 400,
	free_space = 100,
	price = 500,
	max_wear = 100, -- out of 65535
	engine_slots = 1,
	power_generator_slots = 1,
	droid_slots = 0,
	scaner_slots = 0,
	forcefield_generator_slots = 0,
	special_equipment_slots = 0,
	is_market_item = true,
	player_visual = {
		mesh = "basic_ship.b3d",
		textures = {"basic_ship.png", "basic_ship.png", "basic_ship.png", "basic_ship.png"},
		visual = "mesh",
		visual_size = {x=10, y=10},
	},
})

register_wearable_item("saturn:basic_ship_hull_me",{
		description = "Basic ship hull military edition",
		inventory_image = "saturn_basic_ship_hull_me.png",
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
	},{
	weight = 60000,
	volume = 400,
	free_space = 100,
	price = 2000,
	max_wear = 400, -- out of 65535
	engine_slots = 2,
	power_generator_slots = 2,
	droid_slots = 0,
	scaner_slots = 0,
	forcefield_generator_slots = 1,
	special_equipment_slots = 0,
	is_market_item = true,
	player_visual = {
		mesh = "basic_ship.b3d",
		textures = {"basic_ship_military_edition.png", "basic_ship_military_edition.png", "basic_hull_military_edition.png", "basic_hull_military_edition.png"},
		visual = "mesh",
		visual_size = {x=10, y=10},
	},
})

register_wearable_item("saturn:escape_pod",{
		description = "Escape pod",
		inventory_image = "saturn_escape_pod.png",
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
	},{
	weight = 1000,
	volume = 0,
	free_space = 0,
	price = 0,
	max_wear = 65535, -- out of 65535
	engine_slots = 0,
	power_generator_slots = 0,
	droid_slots = 0,
	scaner_slots = 0,
	forcefield_generator_slots = 0,
	special_equipment_slots = 0,
	player_visual = {
		mesh = "escape_pod.b3d",
		textures = {"basic_ship.png"},
		visual = "mesh",
		visual_size = {x=10, y=10},
	},
})

-- Retractors
local retractor_on_use = function(stack, player, pointed_thing)
	local return_value = true -- can use secondary
	local stats = saturn.get_item_stats(stack:get_name())
	local max_wear = stats['max_wear']
	local rated_power = stats['rated_power']
	local metadata = minetest.deserialize(stack:get_metadata())
	if metadata then
		if metadata['rated_power'] then
			rated_power = rated_power + metadata['rated_power']
		end
	end
	local ship_obj = player:get_attach()
	if ship_obj then
		local ship_lua = ship_obj:get_luaentity()
		if ship_lua['free_power'] - ship_lua['recharging_equipment_power_consumption'] >= rated_power then
		    local time_of_last_shoot = 0
		    local cooldown = stats['cooldown']
		    local range = stats['range']
		    if metadata then
			if metadata['time_of_last_shoot'] then
			    time_of_last_shoot = metadata['time_of_last_shoot']
			end
			if metadata['cooldown'] then
			    cooldown = cooldown + metadata['cooldown']
			end
			if metadata['range'] then
			    range = range + metadata['range']
			end
		    else
			metadata = {}
		    end
		    if ship_lua.total_modificators['cooldown'] then
			cooldown = math.max(cooldown + ship_lua.total_modificators['cooldown'], 0.05) -- cannot be zero
		    end
		    local current_time = minetest.get_gametime()
		    local timediff = current_time - time_of_last_shoot
		    if timediff >= cooldown then
			if ship_lua.total_modificators['range'] then
			    damage = damage + ship_lua.total_modificators['range']
			end
			local name = player:get_player_name()
			local search_area = range
			local p_pos = player:getpos()
			p_pos.y = p_pos.y + 1.6
			local player_look_vec = vector.multiply(player:get_look_dir(),search_area)
			local abs_player_look = vector.add(p_pos,player_look_vec)
			local objs = minetest.env:get_objects_inside_radius(abs_player_look, search_area)
			local shoot_miss = true
			for k, obj in pairs(objs) do
			    local lua_entity = obj:get_luaentity()
			    if lua_entity then
				if lua_entity.name == "saturn:throwable_item_entity" then
				    local threshold = 0.75
				    local object_pos = obj:getpos()
				    local player_look_to_obj = vector.multiply(player:get_look_dir(),vector.length(vector.subtract(object_pos,p_pos)))		
				    local target_pos = vector.add(p_pos,player_look_to_obj)
				    if math.abs(object_pos.x-target_pos.x)<threshold and  
				    math.abs(object_pos.y-target_pos.y)<threshold and
				    math.abs(object_pos.z-target_pos.z)<threshold then
					shoot_miss = false
					local is_clear, node_pos = minetest.line_of_sight(p_pos, object_pos, 2)
					if is_clear then 
						local inv = player:get_inventory()
						if inv and lua_entity.itemstring ~= '' then
							inv:add_item("main", lua_entity.itemstring)
							stack:add_wear(saturn.MAX_ITEM_WEAR / max_wear)
						end
						lua_entity.itemstring = ''
						obj:remove()
						minetest.sound_play({name="saturn_retractor", gain=0.5}, {to_player = name})
						return_value = false
					else
						object_pos = vector.subtract(node_pos, player:get_look_dir())
						local node_info = minetest.get_node(node_pos)
						if node_info.name == "saturn:fog" then
							minetest.remove_node(node_pos)
						end
					end
					minetest.add_particle({
						pos = object_pos,
						velocity = {x=0, y=0, z=0},
						acceleration = {x=0, y=0, z=0},
						expirationtime = 1.0,
						size = 16,
						collisiondetection = false,
						vertical = false,
						texture = "saturn_green_halo.png"
					})
				    end
				end
			    end
			end
			if shoot_miss then
				local is_clear, node_pos = minetest.line_of_sight(p_pos, abs_player_look, 1)
				if not is_clear then 
					local player_look_to_obj = vector.multiply(player:get_look_dir(),vector.length(vector.subtract(node_pos,p_pos)))		
					local target_pos = vector.add(p_pos,player_look_to_obj)
					local object_pos = vector.subtract(target_pos, player:get_look_dir())
					minetest.add_particle({
						pos = object_pos,
						velocity = {x=0, y=0, z=0},
						acceleration = {x=0, y=0, z=0},
						expirationtime = 1.0,
						size = 16,
						collisiondetection = false,
						vertical = false,
						texture = "saturn_green_halo.png"
					})
					local node_info = minetest.get_node(node_pos)
					if node_info.name == "saturn:fog" then
						minetest.remove_node(node_pos)
					end
				end
			end
			metadata['time_of_last_shoot'] = current_time
			stack:set_metadata(minetest.serialize(metadata))
			stack:add_wear(saturn.MAX_ITEM_WEAR / max_wear)
			saturn.hotbar_cooldown[name][player:get_wield_index()] = cooldown
			ship_lua['recharging_equipment_power_consumption'] = ship_lua['recharging_equipment_power_consumption'] + rated_power
			saturn.refresh_energy_hud(ship_lua.driver)
			minetest.after(cooldown, saturn.release_delayed_power_and_try_to_shoot_again, ship_lua, rated_power, player:get_wield_index())
		    else
			return_value = false
		    end
		else
			minetest.chat_send_player(player:get_player_name(), "Not enought free power to use this retractor!")
			return_value = false
		end
	return return_value
	end
end


local retractor_on_secondary_use = function(stack, player, pointed_thing)
	local stats = saturn.get_item_stats(stack:get_name())
	local max_wear = stats['max_wear']
	local rated_power = stats['rated_power']
	if player:get_attach() then
		local ship_lua = player:get_attach():get_luaentity()
		if ship_lua['free_power'] >= rated_power then
			local objs = minetest.env:get_objects_inside_radius(vector.add(player:getpos(),player:get_look_dir()), 4)
			for k, obj in pairs(objs) do
				local lua_entity = obj:get_luaentity()
				if lua_entity then
					if lua_entity.name == "saturn:throwable_item_entity" then
						local inv = player:get_inventory()
						if inv and lua_entity.itemstring ~= '' then
							inv:add_item("main", lua_entity.itemstring)
							stack:add_wear(saturn.MAX_ITEM_WEAR / max_wear)
						end
						lua_entity.itemstring = ''
						obj:remove()
						minetest.sound_play({name="saturn_retractor", gain=0.5}, {to_player = name})
					end
				end
			end
		else
			minetest.chat_send_player(player:get_player_name(), "Not enought free power to use this retractor!")
		end
	return stack
	end
end

register_wearable_item("saturn:basic_retractor",{
		description = "Basic retractor",
		inventory_image = "saturn_basic_retractor.png",
	        range = 4.0,
		tool_capabilities = {
	            full_punch_interval = 1.0,
	            max_drop_level=0,
	            groupcaps={
	                cracky={times={[1]=3.00, [2]=2.00, [3]=1.30}, uses=2000, maxlevel=1},
	            },
    		},
		on_secondary_use = function(stack, player, pointed_thing)
			if retractor_on_use(stack, player, pointed_thing) then
				return retractor_on_secondary_use(stack, player, pointed_thing)
			else
				return stack
			end
		end,
	},{
	weight = 400,
	volume = 1,
	price = 100,
	cooldown = 0.5,
	range = 10,
	max_wear = 2000, -- out of 65535
	rated_power = 1, -- MW, megawatts
	is_market_item = true,
})

register_wearable_item("saturn:retractor_scr2",{
		description = "Retractor SCR-2",
		inventory_image = "saturn_retractor_scr2.png",
	        range = 4.0,
		tool_capabilities = {
	            full_punch_interval = 1.0,
	            max_drop_level=0,
	            groupcaps={
	                cracky={times={[1]=1.50, [2]=1.00, [3]=0.60}, uses=2000, maxlevel=1},
	            },
    		},
		on_secondary_use = function(stack, player, pointed_thing)
			if retractor_on_use(stack, player, pointed_thing) then
				return retractor_on_secondary_use(stack, player, pointed_thing)
			else
				return stack
			end
		end,
	},{
	weight = 800,
	volume = 1.5,
	price = 200,
	cooldown = 0.5,
	range = 16,
	max_wear = 2000, -- out of 65535
	rated_power = 2, -- MW, megawatts
	is_market_item = true,
})

-- Engines

register_wearable_item("saturn:ionic_engine",{
		description = "Ionic engine",
		inventory_image = "saturn_ionic_engine.png",
	        range = 0.0,
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
	},{
	weight = 400,
	volume = 4,
	price = 100,
	traction = 80000,
	max_wear = 65535, -- out of 65535
	rated_power = 4, -- MW, megawatts
	is_market_item = true,
})

register_wearable_item("saturn:enemy_engine",{
		description = "Enemy engine",
		inventory_image = "saturn_enemy_engine.png",
	        range = 0.0,
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
	},{
	weight = 440,
	volume = 5,
	price = 1000,
	traction = 81000,
	max_wear = 65535, -- out of 65535
	rated_power = 4, -- MW, megawatts
	is_enemy_item = true,
	possible_modifications = default_enemy_item_possible_modifications,
})

-- Power generators

register_wearable_item("saturn:mmfnr", {
	description = "Miniature maintenance free reactor",
	inventory_image = "saturn_mmfnr.png",
	        range = 0.0,
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
	},{
	weight = 2000, -- 1000 kg
	volume = 10, -- 1000 cubic meter
	generated_power = 6,
	max_wear = 65535,
	price = 100,
	is_market_item = true,
})

register_wearable_item("saturn:mmfnr2", {
	description = "Miniature maintenance free reactor MMFNR2",
	inventory_image = "saturn_mmfnr2.png",
	        range = 0.0,
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
	},{
	weight = 7800, -- 1000 kg
	volume = 38, -- 1000 cubic meter
	generated_power = 24,
	max_wear = 65535,
	price = 1600,
	is_market_item = true,
})

register_wearable_item("saturn:enemy_power_generator", {
	description = "Enemy power generator",
	inventory_image = "saturn_enemy_power_generator.png",
	        range = 0.0,
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
	},{
	weight = 7000, -- 1000 kg
	volume = 50, -- 1000 cubic meter
	generated_power = 20,
	max_wear = 65535,
	price = 10000,
	is_enemy_item = true,
	possible_modifications = default_enemy_generator_item_possible_modifications,
})

-- Weapons

local cdbcemw_on_use = function(stack, player, pointed_thing)
	local stats = saturn.get_item_stats(stack:get_name())
	local max_wear = stats['max_wear']
	local rated_power = stats['rated_power']
	local metadata = minetest.deserialize(stack:get_metadata())
	if metadata then
		if metadata['rated_power'] then
			rated_power = rated_power + metadata['rated_power']
		end
	end
	local ship_obj = player:get_attach()
	if ship_obj then
		local ship_lua = ship_obj:get_luaentity()
		if ship_lua['free_power'] - ship_lua['recharging_equipment_power_consumption'] >= rated_power then
		    local time_of_last_shoot = 0
		    local cooldown = stats['cooldown']
		    local damage = stats['damage']
		    if metadata then
			if metadata['time_of_last_shoot'] then
			    time_of_last_shoot = metadata['time_of_last_shoot']
			end
			if metadata['cooldown'] then
			    cooldown = cooldown + metadata['cooldown']
			end
			if metadata['damage'] then
			    damage = damage + metadata['damage']
			end
		    else
			metadata = {}
		    end
		    if ship_lua.total_modificators['cooldown'] then
			cooldown = math.max(cooldown + ship_lua.total_modificators['cooldown'], 0.05) -- cannot be zero
		    end
		    local current_time = minetest.get_gametime()
		    if current_time - time_of_last_shoot >= cooldown then
			if ship_lua.total_modificators['damage'] then
			    damage = damage + ship_lua.total_modificators['damage']
			end
			local name = player:get_player_name()
			local search_area = 64
			local p_pos = player:getpos()
			p_pos.y = p_pos.y + 1.6
			local player_look_vec = vector.multiply(player:get_look_dir(),search_area)
			local abs_player_look = vector.add(p_pos,player_look_vec)
			local objs = minetest.env:get_objects_inside_radius(abs_player_look, search_area)
			local shoot_miss = true
			for k, obj in pairs(objs) do
			    local lua_entity = obj:get_luaentity()
			    if lua_entity then
				if lua_entity.name ~= "saturn:spaceship" or lua_entity.driver ~= player then
				    local threshold = 0.75
				    local object_pos = obj:getpos()
				    local player_look_to_obj = vector.multiply(player:get_look_dir(),vector.length(vector.subtract(object_pos,p_pos)))		
				    local target_pos = vector.add(p_pos,player_look_to_obj)
				    if math.abs(object_pos.x-target_pos.x)<threshold and  
				    math.abs(object_pos.y-target_pos.y)<threshold and
				    math.abs(object_pos.z-target_pos.z)<threshold then
					shoot_miss = false
					local is_clear, node_pos = minetest.line_of_sight(p_pos, object_pos, 2)
					if is_clear then 
						saturn.punch_object(obj, player, damage)
					else
						object_pos = vector.subtract(node_pos, player:get_look_dir())
						local node_info = minetest.get_node(node_pos)
						if node_info.name == "saturn:fog" then
							minetest.remove_node(node_pos)
						end
					end
					saturn.create_hit_effect(0.2, 1, target_pos)
				    end
				end
			    end
			end
			if shoot_miss then
				local is_clear, node_pos = minetest.line_of_sight(p_pos, abs_player_look, 1)
				if not is_clear then 
					local player_look_to_obj = vector.multiply(player:get_look_dir(),vector.length(vector.subtract(node_pos,p_pos)))		
					local target_pos = vector.add(p_pos,player_look_to_obj)
					local object_pos = vector.subtract(target_pos, player:get_look_dir())
					saturn.create_hit_effect(0.2, 1, object_pos)
					local node_info = minetest.get_node(node_pos)
					if node_info.name == "saturn:fog" then
						minetest.remove_node(node_pos)
					end
				end
			end
			metadata['time_of_last_shoot'] = current_time
			stack:set_metadata(minetest.serialize(metadata))
			stack:add_wear(saturn.MAX_ITEM_WEAR / max_wear)
			saturn.hotbar_cooldown[name][player:get_wield_index()] = cooldown
			minetest.sound_play({name="saturn_plasm_accelerator", gain=0.5}, {to_player = name})
			ship_lua['recharging_equipment_power_consumption'] = ship_lua['recharging_equipment_power_consumption'] + rated_power
			saturn.refresh_energy_hud(ship_lua.driver)
			minetest.after(cooldown, saturn.release_delayed_power_and_try_to_shoot_again, ship_lua, rated_power, player:get_wield_index())
		    end
		else
			minetest.chat_send_player(player:get_player_name(), "Not enought free power to use this weapon!")
		end
	return stack
	end
end

register_wearable_item("saturn:cdbcemw",{
		description = "Carbon dioxide based coherent electromagnetic wave emitter",
		inventory_image = "saturn_cdbcemw.png",
	        range = 0.0,
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
		on_use = function(stack, player, pointed_thing)
			return cdbcemw_on_use(stack, player, pointed_thing)
		end,
	},{
	weight = 400,
	damage = 25,
	cooldown = 1.5, -- seconds
	volume = 5,
	price = 200,
	max_wear = 2000, -- out of 65535
	rated_power = 6, -- MW, megawatts
	is_market_item = true,
})

register_wearable_item("saturn:enemy_particle_emitter",{
		description = "Enemy particle emitter",
		inventory_image = "saturn_enemy_particle_emitter.png",
	        range = 0.0,
		tool_capabilities = {
		        max_drop_level = 0,
		        groupcaps = {},
    		},
		on_use = function(stack, player, pointed_thing)
			return cdbcemw_on_use(stack, player, pointed_thing)
		end,
	},{
	weight = 500,
	damage = 27,
	cooldown = 1.5, -- seconds
	volume = 7,
	price = 2000,
	max_wear = 2000, -- out of 65535
	rated_power = 6, -- MW, megawatts
	is_enemy_item = true,
	possible_modifications = default_enemy_weapon_item_possible_modifications,
})

minetest.register_chatcommand("give_enemy_item", {
	params = "",
	description = "Give to me random enemy item",
	privs = {give = true},
	func = function(name, param)
		local itemstack = saturn.generate_random_enemy_item()
		local leftover = minetest.get_player_by_name(name):get_inventory():add_item("main", itemstack)
		local partiality
		if leftover:is_empty() then
			partiality = ""
		elseif leftover:get_count() == itemstack:get_count() then
			partiality = "could not be "
		else
			partiality = "partially "
		end
		local stackstring = itemstack:to_string()
		return true, ("%q %sadded to inventory.")
			:format(stackstring, partiality)
	end,
})

-- Craft items

local function register_craft_item(registry_name, item_definition, stats)
        item_definition.wield_image = "null.png"
	item_definition.on_drop = function(itemstack, player, pos)
		minetest.sound_play("saturn_item_drop", {to_player = player:get_player_name()})
		saturn.throw_item(itemstack, player, pos)
		itemstack:clear()
		return itemstack
	end
	minetest.register_craftitem(registry_name, item_definition)
	saturn.set_item_stats(registry_name, stats)
	if stats.is_market_item then
		table.insert(saturn.market_items,registry_name)
	end
	if stats.is_enemy_item then
		table.insert(saturn.enemy_items,registry_name)
	end
	if stats.is_ore then
		table.insert(saturn.ore_market_items, registry_name)
	end
end

register_craft_item("saturn:enemy_hull_shard_a",{
		description = "Enemy hull shard A",
		inventory_image = "saturn_enemy_hull_shards.png^[verticalframe:4:1",
	},{
	weight = 400,
	volume = 10,
	price = 100,
	max_wear = 2000, -- out of 65535
	is_enemy_item = true,
})

register_craft_item("saturn:enemy_hull_shard_b",{
		description = "Enemy hull shard B",
		inventory_image = "saturn_enemy_hull_shards.png^[verticalframe:4:2",
	},{
	weight = 500,
	volume = 10,
	price = 120,
	max_wear = 2000, -- out of 65535
	is_enemy_item = true,
})

register_craft_item("saturn:enemy_hull_shard_c",{
		description = "Enemy hull shard C",
		inventory_image = "saturn_enemy_hull_shards.png^[verticalframe:4:3",
	},{
	weight = 400,
	volume = 10,
	price = 100,
	max_wear = 2000, -- out of 65535
	is_enemy_item = true,
})

register_craft_item("saturn:enemy_hull_shard_d",{
		description = "Enemy hull shard D",
		inventory_image = "saturn_enemy_hull_shards.png^[verticalframe:4:4",
	},{
	weight = 400,
	volume = 10,
	price = 100,
	max_wear = 2000, -- out of 65535
	is_enemy_item = true,
})

register_craft_item("saturn:clean_water",{
		description = "Clean water",
		inventory_image = "saturn_cells.png^[verticalframe:64:1",
	},{
	weight = 10,
	volume = 0.01,
	price = 1,
	is_ore = true,
})

register_craft_item("saturn:heavy_water",{
		description = "Heavy water",
		inventory_image = "saturn_cells.png^[verticalframe:64:2",
	},{
	weight = 10,
	volume = 0.01,
	price = 10,
	is_ore = true,
})

register_craft_item("saturn:silicate_mix",{
		description = "Silicate mix",
		inventory_image = "saturn_cells.png^[verticalframe:64:3",
	},{
	weight = 10,
	volume = 0.01,
	price = 1,
	is_ore = true,
})

