AddCSLuaFile()

/********************************************************
	SWEP Construction Kit base code
		Created by Clavus
	Available for public use, thread at:
	   facepunch.com/threads/1032378


	DESCRIPTION:
		This script is meant for experienced scripters
		that KNOW WHAT THEY ARE DOING. Dont come to me
		with basic Lua questions.

		Just copy into your SWEP or SWEP base of choice
		and merge with your own code.

		The SWEP.VElements, SWEP.WElements and
		SWEP.ViewModelBoneMods tables are all optional
		and only have to be visible to the client.
********************************************************/

function SWEP:Initialize()
	// other initialize code goes here
	self:SetHoldType(self.HoldType)
	if CLIENT then

		// Create a new table for every weapon instance
		self.VElements = table.FullCopy( self.VElements )
		self.WElements = table.FullCopy( self.WElements )
		self.ViewModelBoneMods = table.FullCopy( self.ViewModelBoneMods )

		self:CreateModels(self.VElements) // create viewmodels
		self:CreateModels(self.WElements) // create worldmodels

		// init view model bone build function
		if IsValid(self.Owner) then
			local vm = self.Owner:GetViewModel()
			if IsValid(vm) then
				self:ResetBonePositions(vm)
			end
		end

	end

end

function SWEP:Holster()

	if CLIENT and IsValid(self.Owner) then
		local vm = self.Owner:GetViewModel()
		if IsValid(vm) then
			self:ResetBonePositions(vm)
		end
		self:CleanupCLModels(self.VElements)
		if self.WElements~=nil then self:CleanupCLModels(self.WElements) end
	end

	return true
end

function SWEP:OnRemove()
	self:Holster()
end

function SWEP:CleanupCLModels(tbl)
	if SERVER then return end
	for k, v in pairs(tbl) do
		if v.modelEnt~=nil then
			SafeRemoveEntity(v.modelEnt)
		end
	end
end

if CLIENT then


	SWEP.vRenderOrder = nil
	function SWEP:ViewModelDrawn()

		local vm = self.Owner:GetViewModel()
		if !IsValid(vm) then return end

		if (!self.VElements) then return end

		self:UpdateBonePositions(vm)

		if (!self.vRenderOrder) then

			// we build a render order because sprites need to be drawn after models
			self.vRenderOrder = {}

			for k, v in pairs( self.VElements ) do
				if (v.type == "Model") then
					table.insert(self.vRenderOrder, 1, k)
				elseif (v.type == "Sprite" or v.type == "Quad") then
					table.insert(self.vRenderOrder, k)
				end
			end

		end

		for k, name in ipairs( self.vRenderOrder ) do

			local v = self.VElements[name]
			if (!v) then self.vRenderOrder = nil break end
			if (v.hide) then continue end

			local model = v.modelEnt
			local sprite = v.spriteMaterial

			if (!v.bone) then continue end

			local pos, ang = self:GetBoneOrientation( self.VElements, v, vm )

			if (!pos) then continue end

			if (v.type == "Model" and IsValid(model)) then

				model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)

				model:SetAngles(ang)
				//model:SetModelScale(v.size)
				local matrix = Matrix()
				matrix:Scale(v.size)
				model:EnableMatrix( "RenderMultiply", matrix )

				if (v.material == "") then
					model:SetMaterial("")
				elseif (model:GetMaterial() != v.material) then
					model:SetMaterial( v.material )
				end

				if (v.skin and v.skin != model:GetSkin()) then
					model:SetSkin(v.skin)
				end

				if (v.bodygroup) then
					for k, v in pairs( v.bodygroup ) do
						if (model:GetBodygroup(k) != v) then
							model:SetBodygroup(k, v)
						end
					end
				end

				if (v.surpresslightning) then
					render.SuppressEngineLighting(true)
				end

				render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
				render.SetBlend(v.color.a/255)
				model:DrawModel()
				render.SetBlend(1)
				render.SetColorModulation(1, 1, 1)

				if (v.surpresslightning) then
					render.SuppressEngineLighting(false)
				end

			elseif (v.type == "Sprite" and sprite) then

				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				render.SetMaterial(sprite)
				render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)

			elseif (v.type == "Quad" and v.draw_func) then

				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)

				cam.Start3D2D(drawpos, ang, v.size)
					v.info = {pos=drawpos,angle=ang}
					v.draw_func( self )
				cam.End3D2D()

			end

		end

	end

	SWEP.wRenderOrder = nil
	function SWEP:DrawWorldModel()

		if (self.ShowWorldModel == nil or self.ShowWorldModel) then
			self:DrawModel()
		end

		if (!self.WElements) then return end

		if (!self.wRenderOrder) then

			self.wRenderOrder = {}

			for k, v in pairs( self.WElements ) do
				if (v.type == "Model") then
					table.insert(self.wRenderOrder, 1, k)
				elseif (v.type == "Sprite" or v.type == "Quad") then
					table.insert(self.wRenderOrder, k)
				end
			end

		end

		if (IsValid(self.Owner)) then
			bone_ent = self.Owner
		else
			// when the weapon is dropped
			bone_ent = self
		end

		for k, name in pairs( self.wRenderOrder ) do

			local v = self.WElements[name]
			if (!v) then self.wRenderOrder = nil break end
			if (v.hide) then continue end

			local pos, ang

			if (v.bone) then
				pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent )
			else
				pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent, "ValveBiped.Bip01_R_Hand" )
			end

			if (!pos) then continue end

			local model = v.modelEnt
			local sprite = v.spriteMaterial

			if (v.type == "Model" and IsValid(model)) then

				model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)

				model:SetAngles(ang)
				//model:SetModelScale(v.size)
				local matrix = Matrix()
				matrix:Scale(v.size)
				model:EnableMatrix( "RenderMultiply", matrix )

				if (v.material == "") then
					model:SetMaterial("")
				elseif (model:GetMaterial() != v.material) then
					model:SetMaterial( v.material )
				end

				if (v.skin and v.skin != model:GetSkin()) then
					model:SetSkin(v.skin)
				end

				if (v.bodygroup) then
					for k, v in pairs( v.bodygroup ) do
						if (model:GetBodygroup(k) != v) then
							model:SetBodygroup(k, v)
						end
					end
				end

				if (v.surpresslightning) then
					render.SuppressEngineLighting(true)
				end

				render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
				render.SetBlend(v.color.a/255)
				model:DrawModel()
				render.SetBlend(1)
				render.SetColorModulation(1, 1, 1)

				if (v.surpresslightning) then
					render.SuppressEngineLighting(false)
				end

			elseif (v.type == "Sprite" and sprite) then

				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				render.SetMaterial(sprite)
				render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)

			elseif (v.type == "Quad" and v.draw_func) then

				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)

				cam.Start3D2D(drawpos, ang, v.size)
					v.draw_func( self )
				cam.End3D2D()

			end

		end

	end

	function SWEP:GetBoneOrientation( basetab, tab, ent, bone_override )

		local bone, pos, ang
		if (tab.rel and tab.rel != "") then

			local v = basetab[tab.rel]

			if (!v) then return end

			// Technically, if there exists an element with the same name as a bone
			// you can get in an infinite loop. Let's just hope nobody's that stupid.
			pos, ang = self:GetBoneOrientation( basetab, v, ent )

			if (!pos) then return end

			pos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)

		else

			bone = ent:LookupBone(bone_override or tab.bone)

			if (!bone) then return end

			pos, ang = Vector(0,0,0), Angle(0,0,0)
			local m = ent:GetBoneMatrix(bone)
			if (m) then
				pos, ang = m:GetTranslation(), m:GetAngles()
			end

			if (IsValid(self.Owner) and self.Owner:IsPlayer() and
				ent == self.Owner:GetViewModel() and self.ViewModelFlip) then
				ang.r = -ang.r // Fixes mirrored models
			end

		end

		return pos, ang
	end

	function SWEP:CreateModels( tab )

		if (!tab) then return end

		// Create the clientside models here because Garry says we cant do it in the render hook
		for k, v in pairs( tab ) do
			if (v.type == "Model" and v.model and v.model != "" and (!IsValid(v.modelEnt) or v.createdModel != v.model) and
					string.find(v.model, ".mdl") and file.Exists (v.model, "GAME") ) then

				v.modelEnt = ClientsideModel(v.model, RENDER_GROUP_VIEW_MODEL_OPAQUE)
				if (IsValid(v.modelEnt)) then
					v.modelEnt:SetPos(self:GetPos())
					v.modelEnt:SetAngles(self:GetAngles())
					v.modelEnt:SetParent(self)
					v.modelEnt:SetNoDraw(true)
					v.createdModel = v.model
				else
					v.modelEnt = nil
				end

			elseif (v.type == "Sprite" and v.sprite and v.sprite != "" and (!v.spriteMaterial or v.createdSprite != v.sprite)
				and file.Exists ("materials/"..v.sprite..".vmt", "GAME")) then

				local name = v.sprite.."-"
				local params = { ["$basetexture"] = v.sprite }
				// make sure we create a unique name based on the selected options
				local tocheck = { "nocull", "additive", "vertexalpha", "vertexcolor", "ignorez" }
				for i, j in pairs( tocheck ) do
					if (v[j]) then
						params["$"..j] = 1
						name = name.."1"
					else
						name = name.."0"
					end
				end

				v.createdSprite = v.sprite
				v.spriteMaterial = CreateMaterial(name,"UnlitGeneric",params)

			end
		end

	end

	local allbones
	local hasGarryFixedBoneScalingYet = false

	function SWEP:UpdateBonePositions(vm)

		if self.ViewModelBoneMods then

			if (!vm:GetBoneCount()) then return end

			// !! WORKAROUND !! //
			// We need to check all model names :/
			local loopthrough = self.ViewModelBoneMods
			if (!hasGarryFixedBoneScalingYet) then
				allbones = {}
				for i=0, vm:GetBoneCount() do
					local bonename = vm:GetBoneName(i)
					if (self.ViewModelBoneMods[bonename]) then
						allbones[bonename] = self.ViewModelBoneMods[bonename]
					else
						allbones[bonename] = {
							scale = Vector(1,1,1),
							pos = Vector(0,0,0),
							angle = Angle(0,0,0)
						}
					end
				end

				loopthrough = allbones
			end
			// !! ----------- !! //

			for k, v in pairs( loopthrough ) do
				local bone = vm:LookupBone(k)
				if (!bone) then continue end

				// !! WORKAROUND !! //
				local s = Vector(v.scale.x,v.scale.y,v.scale.z)
				local p = Vector(v.pos.x,v.pos.y,v.pos.z)
				local ms = Vector(1,1,1)
				if (!hasGarryFixedBoneScalingYet) then
					local cur = vm:GetBoneParent(bone)
					while(cur >= 0) do
						local pscale = loopthrough[vm:GetBoneName(cur)].scale
						ms = ms * pscale
						cur = vm:GetBoneParent(cur)
					end
				end

				s = s * ms
				// !! ----------- !! //

				if vm:GetManipulateBoneScale(bone) != s then
					vm:ManipulateBoneScale( bone, s )
				end
				if vm:GetManipulateBoneAngles(bone) != v.angle then
					vm:ManipulateBoneAngles( bone, v.angle )
				end
				if vm:GetManipulateBonePosition(bone) != p then
					vm:ManipulateBonePosition( bone, p )
				end
			end
		else
			self:ResetBonePositions(vm)
		end

	end

	function SWEP:ResetBonePositions(vm)

		if (!vm:GetBoneCount()) then return end
		for i=0, vm:GetBoneCount() do
			vm:ManipulateBoneScale( i, Vector(1, 1, 1) )
			vm:ManipulateBoneAngles( i, Angle(0, 0, 0) )
			vm:ManipulateBonePosition( i, Vector(0, 0, 0) )
		end

	end

	/**************************
		Global utility code
	**************************/

	// Fully copies the table, meaning all tables inside this table are copied too and so on (normal table.Copy copies only their reference).
	// Does not copy entities of course, only copies their reference.
	// WARNING: do not use on tables that contain themselves somewhere down the line or youll get an infinite loop
	function table.FullCopy( tab )

		if (!tab) then return nil end

		local res = {}
		for k, v in pairs( tab ) do
			if (type(v) == "table") then
				res[k] = table.FullCopy(v) // recursion ho!
			elseif (type(v) == "Vector") then
				res[k] = Vector(v.x, v.y, v.z)
			elseif (type(v) == "Angle") then
				res[k] = Angle(v.p, v.y, v.r)
			else
				res[k] = v
			end
		end

		return res

	end

end


SWEP.Base               = "weapon_base"
SWEP.WElements = {}
SWEP.VElements = {}
SWEP.offset = 0
SWEP.IronSightAng = Angle(0,0,0)
SWEP.IronSightPos = Vector(0,0,0)
SWEP.IronPos = Vector(0,0,0) -- dont edit this
SWEP.IronAng = Angle(0,0,0) -- dont edit this
SWEP.InspectSpeed = 1
SWEP.IronSpeed = 3
SWEP.InspectOnDeploy = false
SWEP.DeployInspectTime = 5
SWEP.Inspect = {
	{pos = Vector(0,0,0), ang = Angle(0,0,0), time = -1}, //default inspect position is the default position
}
SWEP.BoneInspect = {
	{
		{pos = Vector(0,0,0), ang = Angle(0,0,0),bone = "default"}, //allows you to manipulate the C model bones
	}
}
SWEP.Breath = 0
SWEP.Breathmult = 1
SWEP.IronEnable = true
SWEP.deploytime = 0
SWEP.Dist1Range = 500
SWEP.Dist2Range = 1000
SWEP.Dist3Range = 2000
SWEP.Dist4Range = 10000

function SWEP:PlayDRSound(sound1,distpath,pitch,range,overlap)
	if overlap == nil then
		overlap = false
	end
	local pos = self.Owner:GetPos()
	local distance = pos:Distance(self.Owner:GetPos())
	local dist = 1
	if distance > self.Dist1Range and distance < self.Dist2Range then dist = 2 end
	if distance > self.Dist2Range and distance < self.Dist3Range then dist = 3 end
	if distance > self.Dist3Range then dist = 4 end
	if CLIENT and IsFirstTimePredicted() then
		if overlap then
			sound.Play(Sound(sound1),self:GetPos(),85,pitch,1)
			sound.Play(Sound(distpath.."/dist1_"..math.random(1,3)..".wav"),self:GetPos(),85,pitch,1)
		end
		if !overlap then self:EmitSound(Sound(sound1),85,pitch) end
	end
	if SERVER then
		for k, v in pairs(player.GetAll()) do
			if v~=self.Owner then
				local distance = self.Owner:GetPos():Distance(v:GetPos())
				pos = v:GetPos()+(self.Owner:GetPos()-v:GetPos()):Angle():Forward()*(distance/8)
				if distance < 1000 then pos = self.Owner:GetPos() end
				--local dist = 1
				--if distance > self.Dist1Range and distance < self.Dist2Range then dist = 2 end
				--if distance > self.Dist2Range and distance < self.Dist3Range then dist = 3 end
				--if distance > self.Dist3Range then dist = 4 end
				local vol1 = 1
				local vol2 = 1
				local vol3 = 1
				local vol4 = 1
				vol1 = self.Dist1Range / (distance * 3)
				vol2 = self.Dist2Range / ((distance * 3) + self.Dist2Range)
				vol3 = self.Dist3Range / ((distance * 3) + self.Dist3Range)
				vol4 = self.Dist4Range / ((distance * 3) + self.Dist4Range)
				vol1 = math.Clamp(vol1,0,1)
				vol2 = math.Clamp(vol2,0,1)
				vol3 = math.Clamp(vol3,0,1)
				vol4 = math.Clamp(vol4,0,1)
				if v:Nick()=="Seris" then
					--print(math.Round(distance,3),math.Round(vol1,3),math.Round(vol2,3),math.Round(vol3,3),math.Round(vol4,3))
				end
				v:SendLua("local fsound = Sound('"..distpath.."/dist1_"..math.random(1,3)..".wav') sound.Play(fsound,Vector("..tostring(pos.x)..","..tostring(pos.y)..","..tostring(pos.z).."),"..range..","..pitch..","..vol1..")")
				v:SendLua("local fsound = Sound('"..distpath.."/dist2_"..math.random(1,3)..".wav') sound.Play(fsound,Vector("..tostring(pos.x)..","..tostring(pos.y)..","..tostring(pos.z).."),"..range..","..pitch..","..vol2..")")
				v:SendLua("local fsound = Sound('"..distpath.."/dist3_"..math.random(1,3)..".wav') sound.Play(fsound,Vector("..tostring(pos.x)..","..tostring(pos.y)..","..tostring(pos.z).."),"..range..","..pitch..","..vol3..")")
				v:SendLua("local fsound = Sound('"..distpath.."/dist4_"..math.random(1,3)..".wav') sound.Play(fsound,Vector("..tostring(pos.x)..","..tostring(pos.y)..","..tostring(pos.z).."),"..range..","..pitch..","..vol4..")")
			end
		end
	end
end

if CLIENT then
	local key = 1
	local keytime = 0
	local hands = nil

	hook.Add("PostDrawPlayerHands","UpdateSWEPHands",function(han,vm,ply,wpn)
		if ply:Alive() then
			if han ~= nil then
				hands = han
			end
		end
	end)



	for k ,v in pairs(SWEP.BoneInspect) do //add extra variables to all bones so that we dont have to modify the original bone positions
		for f, b in pairs(v) do
			b.modv = Vector(0,0,0)
			b.moda = Angle(0,0,0)
		end
	end

	function SWEP:Deploy()
		if self.InspectOnDeploy == true then
			self.deploytime = CurTime()+self.DeployInspectTime
		end
		self:CreateModels(self.VElements)
		return true
	end
	function SWEP:DoAnims() //call this function from the child sweps think hook to enable iron sights, inspecting, and 'breathing' viewmodel shifting
		//check to see if the models are valid or nil
		local check = true
		if self.VElements~=nil then
			for k, v in pairs(self.VElements) do
				if check == true then
					if v.modelEnt==nil then
						self:CreateModels(self.VElements)
						check = false
					end
				end
			end
		end
		check = true
		if self.WElements~=nil then
			for k, v in pairs(self.WElements) do
				if check == true then
					if v.modelEnt==nil then
						self:CreateModels(self.WElements)
						check = false
					end
				end
			end
		end

		if self.Owner:KeyDown(IN_ATTACK2) and self.IronEnable then //do ironsighting first to allow it to override inspecting
			self.IronPos.x = Lerp(RealFrameTime()*self.IronSpeed,self.IronPos.x,self.IronSightPos.x)
			self.IronPos.y = Lerp(RealFrameTime()*self.IronSpeed,self.IronPos.y,self.IronSightPos.y)
			self.IronPos.z = Lerp(RealFrameTime()*self.IronSpeed,self.IronPos.z,self.IronSightPos.z)
			self.IronAng = LerpAngle(RealFrameTime()*self.IronSpeed,self.IronAng,self.IronSightAng)
			self.Breath = math.sin(CurTime())/(self.Breathmult*80)
			self.SwayScale = 0.0 //decreases swep viewmodel sway while scoping
         	self.BobScale = 0.0 //decreases swep viewemodel bob while scoping
		elseif (input.IsKeyDown(KEY_G) or self.deploytime > CurTime()) and not input.IsMouseDown(MOUSE_LEFT) then //does inspecting while the G key is pressed down. this key is used because by default garrysmod does not bind G to any function.
			self.Breath = math.sin(CurTime())/(self.Breathmult*4) //simple sine function
			self:DoInspect() //calls inspecting
		else //reset to default position when doing nothing
			self.IronPos.x = Lerp(RealFrameTime()*self.IronSpeed,self.IronPos.x,0)
			self.IronPos.y = Lerp(RealFrameTime()*self.IronSpeed,self.IronPos.y,0)
			self.IronPos.z = Lerp(RealFrameTime()*self.IronSpeed,self.IronPos.z,0)
			self.IronAng = LerpAngle(RealFrameTime()*self.IronSpeed,self.IronAng,Angle(0,0,0))
			self.Breath = math.sin(CurTime())/(self.Breathmult*4)
			self.SwayScale = 1
         	self.BobScale = 1
			keytime = 0
			key = 1
		end
		local pos = self.Owner:GetViewModel(0):GetPos()
		local ang = self.Owner:GetViewModel(0):GetAngles()
		self:GetViewModelPosition(pos,ang)
	end

	function SWEP:GetViewModelPosition(Pos,Ang)
		local tmp = Ang
		Ang:RotateAroundAxis(EyeAngles():Forward(),self.IronAng.p) //rotate the shit
		Ang:RotateAroundAxis(EyeAngles():Up(),self.IronAng.y)
		Ang:RotateAroundAxis(EyeAngles():Right(),self.IronAng.r)

		return Pos+(tmp:Forward()*(self.offset+self.IronPos.x))+(tmp:Right()*self.IronPos.y)+(tmp:Up()*(self.IronPos.z+self.Breath)),Ang+Angle((self.offset+10)/3,0,0)
	end

	function SWEP:DoInspect()
		local info = self.Inspect[key]
		local Bones = self.BoneInspect[key]
		if keytime == 0 then
			keytime = CurTime()+self.Inspect[key].time
		end
		if CurTime() > keytime and info.time > 0 then
			key = key + 1
			keytime = CurTime()+self.Inspect[key].time
		end
		self.keyframe=key
		self.IronPos = self:LerpCurveVec(1,self.IronPos,info.pos)
		self.IronAng = self:LerpCurveAng(1,self.IronAng,info.ang)

	end

	function SWEP:LerpCurveVec(a,b,c)
		return LerpVector( self:inv_lerp( 1, -1, math.cos( ((CurTime()-(keytime-self.Inspect[key].time))/(self.Inspect[key].time)) / self.InspectSpeed)), b, c)
	end
	function SWEP:LerpCurveAng(a,b,c)
		return LerpAngle( self:inv_lerp( 1, -1, math.cos( ((CurTime()-(keytime-self.Inspect[key].time))/(self.Inspect[key].time)) / self.InspectSpeed)), b, c)
	end
	function SWEP:inv_lerp(a,b,c)
    	return (c-a)/(b-a)
	end
	hook.Remove("PostDrawPlayerHands","bonemanip")
	hook.Add("PostDrawPlayerHands","bonemanip",function(hands,vm,ply,wep)
		--print(hands:LookupBone("ValveBiped.Bip01_L_Hand"))
		--hands:ManipulateBoneAngles(3,Angle(90,0,0))
		--print(hands:HasBoneManipulations())
		if wep:IsScripted() then
			if wep.Base == "weapon_sbase" and IsValid(wep.BoneInspect) then
				for k, v in pairs(wep.BoneInspect) do
					for f, b in pairs(v) do
						local blookup = b.bone
						local binfo = wep.BoneInspect[k][f]
						if blookup ~= nil then
							if hands:LookupBone(blookup) ~= nil and #wep.BoneInspect > 1 and b.modv~=nil and b.moda~=nil then
								b.modv = wep:LerpCurveVec(1,b.modv,b.pos)
								b.moda = wep:LerpCurveAng(1,b.moda,b.ang)
								--hands:SetBonePosition(hands:LookupBone(b.bone),b.modv,b.moda)
								hands:SetBonePosition(hands:LookupBone(b.bone),b.modv,b.moda)
							end
						end
					end
				end
			end
		end
	end)
end
