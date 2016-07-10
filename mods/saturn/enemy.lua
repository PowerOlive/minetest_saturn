local enemy_player_tracking_range = 128
local enemy_player_tracking_interval = 20 -- seconds
local enemy_attack_interval = 5 -- seconds

local enemy_01 = {
	hp_max = 150,
	physical = true,
	collisionbox = {-1.0,-1.0,-1.0, 1.0, 1.0, 1.0},
	textures = {"enemy_01.png"},
	visual = "mesh",
	mesh = "enemy_01.b3d",
	visual_size = {x=5, y=5},
	velocity = {x=0, y=0, z=0},
	lastpos = {x=0, y=0, z=0},
	age = 0,
	acceleration = 0.8,
	target = nil,
}

function enemy_01:on_punch(puncher, time_from_last_punch, tool_capabilities, dir)
   local obj = puncher:get_attach()
   if obj then
	local lua_entity = obj:get_luaentity()
	if lua_entity then
	    if lua_entity.name == "saturn:spaceship" and not lua_entity.is_escape_pod then
		self.target = obj
	    end
	end
   end
   if self.object:get_hp() <= 0 then
	local drops_amount = math.floor(saturn.get_pseudogaussian_random(0, 1))
	if drops_amount > 0 then
	    for i=0, drops_amount do
		saturn.throw_item(saturn.generate_random_enemy_item(), self.object, self.object:getpos())
	    end
	end
	saturn.create_explosion_effect(self.object:getpos())
   end
end

local getVectorPitchAngle = saturn.get_vector_pitch_angle
local getVectorYawAngle = saturn.get_vector_yaw_angle

function enemy_01:on_step(dtime)
    self.age = self.age + dtime
    local self_pos = self.object:getpos()
    if self.target then
	local target_pos = self.target:getpos()
	if target_pos then
	    local target_velocity = self.target:getvelocity()
	    local vector_to_target = vector.subtract(target_pos,self_pos)
	    local self_velocity = self.object:getvelocity()
	    local distance_to_target = vector.length(vector_to_target)
	    local direction_to_target = vector.divide(vector_to_target,distance_to_target)
	    local realtive_to_target_speed = vector.subtract(self_velocity,target_velocity)
	    if distance_to_target > 8 then
		local v_normal_to_speed_direction = vector.divide(saturn.vector_multiply(realtive_to_target_speed,vector_to_target),distance_to_target)
		local speed_projection_v = vector.divide(saturn.vector_multiply(v_normal_to_speed_direction,vector_to_target),distance_to_target)
		local acceleration_v = vector.multiply(vector.normalize(vector.add(vector_to_target,speed_projection_v)),self.acceleration)
		self.object:setacceleration(acceleration_v)
	    else
	    	if vector.length(realtive_to_target_speed) > 0.5 then
			local acceleration_v = vector.multiply(vector.normalize(realtive_to_target_speed),-self.acceleration)
			self.object:setacceleration(acceleration_v)
	    	else
			self.object:setacceleration(vector.new(0,0,0))
	    	end
	    end
	    local yaw = -getVectorYawAngle(direction_to_target)
	    local pitch = -getVectorPitchAngle(direction_to_target)
	    self.object:set_bone_position("Head", {x=0,y=1,z=0}, {x=pitch*180/3.14159,y=0,z=yaw*180/3.14159})
	    if self.age % enemy_attack_interval < dtime then
		local lua_entity = self.target:get_luaentity()
		if lua_entity then
		    if lua_entity.is_escape_pod then
			self.target = nil
		    else
		        if lua_entity.driver then
			    local is_clear, node_pos = minetest.line_of_sight(self_pos, target_pos, 2)
			    if is_clear then
				if minetest.setting_getbool("enable_damage") then
				    saturn.punch_object(lua_entity.driver, self.object, 25)
				end
				minetest.sound_play("saturn_ship_hit", {to_player = lua_entity.driver_name})
			    else
				local node_info = minetest.get_node(node_pos)
				if node_info.name == "saturn:fog" then
					minetest.remove_node(node_pos)
				end
			    end
			    saturn.create_shooting_effect(self_pos, direction_to_target, 2)
			end
		    end
		end
	    end
	else
	    self.target = nil
	end
    else
	if self.age % enemy_player_tracking_interval < dtime then
	    local objs = minetest.env:get_objects_inside_radius(self.object:getpos(), enemy_player_tracking_range)
	    for k, obj in pairs(objs) do
		local lua_entity = obj:get_luaentity()
		if lua_entity then
		    if lua_entity.name == "saturn:spaceship" and not lua_entity.is_escape_pod then
			local is_clear, node_pos = minetest.line_of_sight(self_pos, obj:getpos(), 2)
			if is_clear then
			    self.target = obj
			    break
			end
		    end
		end
	    end
	end
    end
end


minetest.register_entity("saturn:enemy_01", enemy_01)
minetest.register_abm({
	nodenames = {"air"},
	neighbors = {"air"},
	interval = 10000.0,
	chance = 500,
	action = function(pos, node, active_object_count, active_object_count_wider)
		if active_object_count_wider == 0 and pos.z < -400 then
			-- mobs cannot spawn in protected areas when enabled
			if minetest.is_protected(pos, "") then
				return
			end
			-- only spawn away from player
			local objs = minetest.get_objects_inside_radius(pos, enemy_player_tracking_range)
			for n = 1, #objs do
				if objs[n]:is_player() then
					if vector.distance(pos, objs[n]:getpos()) < enemy_player_tracking_range*0.5 then
						return
					end
				else
				    local lua_entity = objs[n]:get_luaentity()
				    if lua_entity then
				        if lua_entity.name == "saturn:spaceship" and not lua_entity.is_escape_pod then
						if objs[n]:getvelocity().z < 0 and vector.distance(pos, vector.add(objs[n]:getpos(), vector.multiply(vector.normalize(objs[n]:getvelocity()),enemy_player_tracking_range)))  < enemy_player_tracking_range*0.25 then
							local entity = minetest.add_entity(pos, "saturn:enemy_01")
							local direction_velocity = vector.new(math.random()*10-5,math.random()*10-5,math.random()*10-5)
							if entity then
							    entity:setvelocity(direction_velocity)
							    local yaw = -getVectorYawAngle(direction_velocity)
							    local pitch = -getVectorPitchAngle(direction_velocity)
							    entity:set_bone_position("Head", {x=0,y=1,z=0}, {x=pitch*180/3.14159,y=0,z=yaw*180/3.14159})
							    return
							end
						end
					end
				    end
				end
			end
		end
	end,
})