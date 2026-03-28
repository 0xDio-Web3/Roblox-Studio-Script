--[[ 
    🔥 ULTIMATE PREDICTIVE PROJECTILE SYSTEM v2.0
    Dev: LloydDeveloperRoblox
    
    Yooo, check this out. Built this from scratch 'cause Roblox physics 
    is literally mid and clunky. Using raycasts for that clean hitreg.
--]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

-- // Basic configs so u dont have to hardcode everything
local Config = {
	Speed = 260, -- nyoom
	Grav = Vector3.new(0, -32, 0), -- custom gravity 'cause workspace.Gravity is whack
	MaxDist = 1200, 
	MaxBounces = 4, -- how many times this bad boy ricochets
	Color = Color3.fromRGB(0, 255, 255),
	Size = Vector3.new(0.2, 0.2, 3),
	Liferange = 8 
}

-- // Projectile Class (OOP style, keeping it professional)
local Bullet = {}
Bullet.__index = Bullet

function Bullet.new(start, dir, owner)
	local self = setmetatable({}, Bullet)

	-- Setup the stats
	self.Pos = start
	self.Vel = dir * Config.Speed
	self.Bounces = 0
	self.Dist = 0
	self.Active = true
	self.SpawnTime = tick()
	self.Owner = owner

	-- Making the bullet visual on the fly
	local part = Instance.new("Part")
	part.Name = "B_Node"
	part.Size = Config.Size
	part.Color = Config.Color
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.CanTouch = false
	part.Anchored = true
	part.Parent = workspace:FindFirstChild("FX_Folder") or workspace

	-- Trail 'cause why not, looks sick
	local a0 = Instance.new("Attachment", part)
	a0.Position = Vector3.new(0, 0, Config.Size.Z/2)
	local a1 = Instance.new("Attachment", part)
	a1.Position = Vector3.new(0, 0, -Config.Size.Z/2)

	local t = Instance.new("Trail", part)
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 0.15
	t.WidthScale = NumberSequence.new(1, 0)

	self.Model = part
	return self
end

-- // Vector math for that sweet bounce
function Bullet:Reflect(norm, hitPos)
	self.Bounces += 1

	-- Standard reflection formula: R = V - 2 * (V . N) * N
	-- Plus some friction so it doesnt bounce forever like a crazy ball
	local dot = self.Vel:Dot(norm)
	self.Vel = (self.Vel - 2 * dot * norm) * 0.82 
	self.Pos = hitPos + (norm * 0.1) -- anti-clipping hack

	-- Hit sound, keeping it punchy
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://131544690"
	s.Volume = 0.4
	s.Pitch = math.random(10, 14) / 10
	s.Parent = self.Model
	s:Play()
	Debris:AddItem(s, 1)

	self:Boom(hitPos, norm)

	if self.Bounces >= Config.MaxBounces then
		self:Kill()
	end
end

-- // Fancy particles for when things go bang
function Bullet:Boom(p, n)
	local f = Instance.new("Part")
	f.Size = Vector3.new(0.1, 0.1, 0.1)
	f.Transparency = 1
	f.Anchored = true
	f.CanCollide = false
	f.Position = p
	f.CFrame = CFrame.lookAt(p, p + n)
	f.Parent = workspace

	local emit = Instance.new("ParticleEmitter")
	emit.Rate = 0
	emit.Lifetime = NumberRange.new(0.1, 0.4)
	emit.Speed = NumberRange.new(8, 18)
	emit.Color = ColorSequence.new(Config.Color)
	emit.Parent = f

	emit:Emit(12)
	Debris:AddItem(f, 0.8)
end

-- // The heavy lifting (Simulation loop)
function Bullet:Update(dt)
	if not self.Active or not self.Model then return end

	local prev = self.Pos

	-- Update velocity with gravity (V = V0 + a*t)
	self.Vel += Config.Grav * dt

	-- Euler integration for movement, fast and reliable
	local move = (self.Vel * dt) + (0.5 * Config.Grav * dt^2)
	local nextPos = prev + move

	-- Predicitive Raycast (so bullets dont ghost thru walls at high speed)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {self.Model, self.Owner.Character, workspace:FindFirstChild("FX_Folder")}

	local ray = workspace:Raycast(prev, move * 1.05, params)

	if ray then
		local hit = ray.Instance
		local char = hit:FindFirstAncestorOfClass("Model")

		-- If we hit a player/npc, just rip
		if char and char:FindFirstChild("Humanoid") then
			-- char.Humanoid:TakeDamage(20) -- handle damage on server if possible
			self:Kill()
			return
		end

		-- Walls = bounce
		self:Reflect(ray.Normal, ray.Position)
	else
		-- Clear path, just vibe
		self.Pos = nextPos
	end

	-- Align visual part to travel direction
	if self.Vel.Magnitude > 0.01 then
		self.Model.CFrame = CFrame.lookAt(self.Pos, self.Pos + self.Vel)
	end

	-- Cleanup if it goes too far or too old
	self.Dist += (self.Pos - prev).Magnitude
	if self.Dist > Config.MaxDist or (tick() - self.SpawnTime) > Config.Liferange then
		self:Kill()
	end
end

-- // Clean up the mess
function Bullet:Kill()
	if not self.Active then return end
	self.Active = false

	if self.Model then
		-- Smooth fade-out looks way more polished than just :Destroy()
		task.spawn(function()
			for i = 0, 1, 0.25 do
				if self.Model then
					self.Model.Transparency = 0.2 + (i * 0.8)
					task.wait(0.04)
				end
			end
			if self.Model then self.Model:Destroy() end
		end)
	end
end

-- // MAIN ENGINE
local Cache = {}
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Tool = script.Parent

-- Heartbeat is goated for smooth physics
RunService.Heartbeat:Connect(function(dt)
	for i = #Cache, 1, -1 do
		local b = Cache[i]
		if b.Active then
			b:Update(dt)
		else
			table.remove(Cache, i)
		end
	end
end)

-- Click to shoot
Tool.Activated:Connect(function()
	if not Tool:FindFirstChild("Handle") then warn("Yo, where's the Handle?") return end

	local origin = Tool.Handle.Position
	local target = Mouse.Hit.Position
	local unit = (target - origin).Unit

	local bullet = Bullet.new(origin, unit, LP)
	table.insert(Cache, bullet)

	-- Pew pew sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://138122923"
	sound.Volume = 0.5
	sound.Parent = Tool.Handle
	sound:Play()
	Debris:AddItem(sound, 1.2)
end)

-- Simple folder to keep the workspace clean
local fx = workspace:FindFirstChild("FX_Folder")
if not fx then
	fx = Instance.new("Folder")
	fx.Name = "FX_Folder"
	fx.Parent = workspace
end

print(">>> Projectile system loaded. GGs.")
