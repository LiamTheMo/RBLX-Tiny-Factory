--!nonstrict
-- Native, editable geometry: no remote model loading or art permission dependency.
local Config = require(game:GetService("ReplicatedStorage").Shared.IslandWorldConfig)
local Builder = {}
local C = {
	Grass = Color3.fromRGB(159, 209, 74), GrassLight = Color3.fromRGB(185, 225, 91),
	Sand = Color3.fromRGB(224, 189, 133), Cliff = Color3.fromRGB(197, 162, 111),
	Rock = Color3.fromRGB(117, 130, 137), Wood = Color3.fromRGB(149, 97, 54),
	DarkWood = Color3.fromRGB(89, 58, 38), Amber = Color3.fromRGB(255, 186, 69),
	Roof = Color3.fromRGB(204, 97, 47), Leaf = Color3.fromRGB(70, 166, 91),
	Pine = Color3.fromRGB(32, 139, 100), Water = Color3.fromRGB(42, 178, 205),
}

local function part(parent, name, size, cf, color, material, collide, class)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide = true, collide == true
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function beam(parent, name, a, b, width, color, material, collide)
	return part(parent, name, Vector3.new(width, width, (b-a).Magnitude), CFrame.lookAt((a+b)/2, b), color, material, collide)
end

local function ball(parent, name, pos, size, color)
	local p = part(parent, name, size, CFrame.new(pos), color)
	p.Shape = Enum.PartType.Ball
	return p
end

local function polygon(parent, center, rx, rz, height, color, seed)
	-- An overlapping fan of triangular wedges makes a solid, flat polygonal top.
	-- Broad, invisible strips provide reliable collision across wedge seams.
	for strip = -5, 5 do
		local z = strip * rz / 6
		local halfWidth = rx * math.sqrt(1 - (math.abs(z) / rz)^2) * 0.88
		local floor = part(parent, "LandCollision", Vector3.new(halfWidth * 2, height, rz / 6 + 0.08),
			CFrame.new(center + Vector3.new(0, 0, z)), color, Enum.Material.SmoothPlastic, true)
		floor.Transparency = 1
		floor:SetAttribute("LandSurface", true)
	end
	local rng = Random.new(seed)
	local vertices = {}
	for i = 1, 16 do
		local angle = (i-1)*math.pi/8
		local radius = rng:NextNumber(0.95, 1.05)
		vertices[i] = center + Vector3.new(math.cos(angle)*rx*radius, 0, math.sin(angle)*rz*radius)
	end
	for i = 1, 16 do
		local a,b = vertices[i], vertices[i%16+1]
		local edge = b-a
		local along = edge.Unit
		local mid = a + along * (center-a):Dot(along)
		local inward = (center-mid).Unit
		local depth = (center-mid).Magnitude
		for _, endpoint in {a,b} do
			local width = (endpoint-mid).Magnitude
			local direction = (endpoint-mid).Unit
			local wedge = part(parent, "Facet", Vector3.new(height, depth, width+0.05),
				CFrame.fromMatrix((center+endpoint)/2, inward:Cross(-direction), inward, -direction), color, Enum.Material.SmoothPlastic, false, "WedgePart")
			wedge.CanQuery = false
			-- Wedge local X is vertical; local Y/Z describe the fan triangle.
			wedge:SetAttribute("LandSurface", true)
		end
	end
	return vertices
end

local function island(parent, center, rx, rz, top, seed)
	local group = Instance.new("Model")
	group.Name = "Landform"
	group.Parent = parent
	polygon(group, center+Vector3.new(0, top-0.6, 0), rx, rz, 1.2, C.Grass, seed)
	polygon(group, center+Vector3.new(0, top-2.0, 0), rx*1.02, rz*1.02, 1.8, C.Sand, seed)
	polygon(group, center+Vector3.new(0, (top-4)/2-3, 0), rx*0.98, rz*0.98, top+4, C.Cliff, seed)
	-- Shore accents remain noncolliding and do not block land raycasts.
	for i = 1, 24 do
		local a = i*math.pi/12
		local p = part(group, "ShoreFoam", Vector3.new(5.5, 0.08, 1.2),
			CFrame.new(center+Vector3.new(math.cos(a)*rx*1.03, Config.WaterY+0.12, math.sin(a)*rz*1.03))*CFrame.Angles(0,-a+math.pi/2,0), Color3.fromRGB(213,248,245))
		p.Transparency = 0.25
	end
end

local function tree(parent, pos, scale, pine, tint)
	local group = Instance.new("Model")
	group.Name = if pine then "Pine" else "MeadowTree"
	group.Parent = parent
	part(group,"Trunk",Vector3.new(1.5,7,1.5)*scale,CFrame.new(pos+Vector3.new(0,3.5*scale,0)),C.Wood,Enum.Material.Wood,true)
	if pine then
		for layer = 1,3 do
			local radius = (7-layer*1.3)*scale
			local y = (5+layer*2.4)*scale
			for face = 0,3 do
				part(group,"PineCrown",Vector3.new(radius, radius*1.3, radius),
					CFrame.new(pos+Vector3.new(0,y,0))*CFrame.Angles(0,face*math.pi/2,0),tint or C.Pine,nil,false,"WedgePart")
			end
		end
	else
		for i=0,3 do
			local a=i*math.pi/2
			ball(group,"LeafCluster",pos+Vector3.new(math.cos(a)*2.2*scale, (8+i%2)*scale,math.sin(a)*2.2*scale),Vector3.new(7,6,7)*scale,tint or C.Leaf)
		end
	end
end

local function flowers(parent, pos, seed)
	local rng = Random.new(seed)
	local colors = {Color3.fromRGB(255,221,78),Color3.fromRGB(245,149,190),Color3.fromRGB(117,216,237),Color3.fromRGB(250,248,222)}
	for i=1,3 do
		local base=pos+Vector3.new(rng:NextNumber(-2,2),0,rng:NextNumber(-2,2))
		ball(parent,"MeadowShrub",base+Vector3.new(0,0.65,0),Vector3.new(2.3,1.5,2),Color3.fromRGB(65,179,125))
		local c=colors[(seed+i)%4+1]
		for petal=0,3 do
			local a=petal*math.pi/2
			ball(parent,"Petal",base+Vector3.new(math.cos(a)*0.45,1.4,math.sin(a)*0.45),Vector3.new(0.65,0.25,0.65),c)
		end
		ball(parent,"FlowerCenter",base+Vector3.new(0,1.5,0),Vector3.new(0.35,0.25,0.35),C.Amber)
	end
end

local function lantern(parent, pos)
	part(parent,"LampPost",Vector3.new(0.65,7,0.65),CFrame.new(pos+Vector3.new(0,3.5,0)),C.DarkWood,Enum.Material.Wood,true)
	part(parent,"LanternBase",Vector3.new(1.8,0.25,1.8),CFrame.new(pos+Vector3.new(0,7,0)),C.DarkWood)
	local glow=part(parent,"AmberLantern",Vector3.new(1.2,1.8,1.2),CFrame.new(pos+Vector3.new(0,8,0)),C.Amber,Enum.Material.Neon)
	part(parent,"LanternCap",Vector3.new(2,0.3,2),CFrame.new(pos+Vector3.new(0,9,0)),C.DarkWood)
	local light=Instance.new("PointLight")
	light.Color,light.Brightness,light.Range=C.Amber,0.5,13
	light.Parent=glow
end

local function cabin(parent, pos, scale, name)
	local model=Instance.new("Model")
	model.Name=name or "WorkshopCabin"
	model.Parent=parent
	local function p(n,s,o,c,m,collide)
		return part(model,n,s*scale,CFrame.new(pos+o*scale),c,m,collide)
	end
	p("Floor",Vector3.new(16,0.7,13),Vector3.new(0,0.35,0),C.Wood,Enum.Material.WoodPlanks,true)
	p("BackWall",Vector3.new(16,9,0.7),Vector3.new(0,5,-6),C.Wood,Enum.Material.WoodPlanks,true)
	for _,x in {-7.6,7.6} do p("SideWall",Vector3.new(0.7,9,12),Vector3.new(x,5,0),C.Wood,Enum.Material.WoodPlanks,true) end
	for _,x in {-5.3,5.3} do p("FrontWall",Vector3.new(5.3,9,0.7),Vector3.new(x,5,6),C.Wood,Enum.Material.WoodPlanks,true) end
	p("DoorLintel",Vector3.new(5.3,2.5,0.7),Vector3.new(0,8.25,6),C.Wood,Enum.Material.WoodPlanks,true)
	for _,x in {-7.7,7.7} do for _,z in {-6,6} do p("CornerBeam",Vector3.new(0.9,10,0.9),Vector3.new(x,5,z),C.DarkWood,Enum.Material.Wood,true) end end
	for _,side in {-1,1} do
		local roof=p("TerracottaRoof",Vector3.new(10.3,0.7,16),Vector3.new(side*4.4,11,0),C.Roof,Enum.Material.SmoothPlastic,true)
		roof.CFrame *= CFrame.Angles(0,0,-side*math.rad(25))
		for stripe=-3,3 do
			local rib=p("RoofTileSeam",Vector3.new(10.3,0.14,0.12),Vector3.new(side*4.4,11.4,stripe*2),Color3.fromRGB(228,129,61))
			rib.CFrame *= CFrame.Angles(0,0,-side*math.rad(25))
		end
	end
	p("RidgeCap",Vector3.new(0.8,0.6,16.5),Vector3.new(0,13,0),C.Roof)
	p("Chimney",Vector3.new(1.5,6,1.5),Vector3.new(4,13,-3),Color3.fromRGB(228,222,201),Enum.Material.Brick,true)
	for _,x in {-5.4,5.4} do
		p("WindowFrame",Vector3.new(2.6,3.3,0.4),Vector3.new(x,5.5,6.5),C.DarkWood)
		p("WarmWindow",Vector3.new(2.1,2.7,0.2),Vector3.new(x,5.5,6.75),C.Amber,Enum.Material.Neon)
		p("WindowMullion",Vector3.new(0.2,2.8,0.25),Vector3.new(x,5.5,6.9),C.DarkWood)
	end
	p("Porch",Vector3.new(18,0.6,5),Vector3.new(0,0.3,9),C.Wood,Enum.Material.WoodPlanks,true)
	return model
end

local function walkway(parent, a, b, width, rails)
	local length=(b-a).Magnitude
	local cf=CFrame.lookAt((a+b)/2,b)
	part(parent,"WalkwayCollision",Vector3.new(width,0.6,length+1),cf,C.Wood,Enum.Material.WoodPlanks,true)
	local count=math.ceil(length/2.5)
	for i=0,count do
		local t=i/count
		local point=a:Lerp(b,t)
		part(parent,"TimberPlank",Vector3.new(width+0.25,0.2,2.1),CFrame.new(point)*cf.Rotation,C.Wood,Enum.Material.WoodPlanks)
		if rails and i%4==0 then
			for _,side in {-1,1} do
				local post=point+cf.RightVector*(width/2-0.3)*side
				part(parent,"BridgePost",Vector3.new(0.65,4.5,0.65),CFrame.new(post+Vector3.new(0,2,0)),C.DarkWood,Enum.Material.Wood,true)
			end
		end
	end
	if rails then
		for _,side in {-1,1} do
			local offset=cf.RightVector*(width/2-0.3)*side+Vector3.new(0,3.6,0)
			beam(parent,"BridgeHandrail",a+offset,b+offset,0.45,C.DarkWood,Enum.Material.Wood,true)
		end
	end
end

local function playerIsland(parent,index)
	local data=Config.getPlotOrigin(index)
	local center=Vector3.new(data.X+15,0,data.Z)
	local model=Instance.new("Model")
	model.Name=string.format("StarterIsland_%02d",index)
	model:SetAttribute("PlotIndex",index)
	island(model,center,51,39,Config.GroundY,100+index)
	local y=Config.GroundY
	-- Raised garden behind the factory; clear center is reserved for all five slots.
	polygon(model,center+Vector3.new(-26,y+3,-22),16,12,6,C.Sand,300+index)
	polygon(model,center+Vector3.new(-26,y+6.1,-22),16,12,0.5,C.GrassLight,300+index)
	cabin(model,center+Vector3.new(28,y,-23),0.85)
	for i=1,11 do
		local a=(i+0.35)*math.pi*2/12
		local pos=center+Vector3.new(math.cos(a)*42,y,math.sin(a)*31)
		if not (pos.X>center.X+15 and pos.Z<center.Z-16) and math.abs(pos.X-center.X)>9 then
			tree(model,pos,0.65+(i%3)*0.12,i%3~=0,if i%4==0 then Color3.fromRGB(194,213,66) elseif i%5==0 then Color3.fromRGB(230,150,193) else nil)
			flowers(model,pos+Vector3.new(-3,0,1),index*20+i)
			local rock=part(model,"SandstoneBoulder",Vector3.new(3.8,2.7,3.5),CFrame.new(pos+Vector3.new(3,1.2,1))*CFrame.Angles(0,i,0.15),C.Sand)
			rock.Shape=Enum.PartType.Ball
		end
	end
	for i=0,10 do
		local a=-0.2+i*math.pi/24
		part(model,"GardenPath",Vector3.new(5.5,0.08,4),CFrame.new(center+Vector3.new(math.sin(a)*27,y+0.05,13+math.cos(a)*9))*CFrame.Angles(0,a,0),C.Sand)
	end
	walkway(model,center+Vector3.new(0,y,30),center+Vector3.new(0,y,48),9,false)
	for _,x in {-4,4} do for _,z in {35,46} do part(model,"DockPile",Vector3.new(1.2,16,1.2),CFrame.new(center+Vector3.new(x,1,z)),C.Wood,Enum.Material.Wood,true) end end
	lantern(model,center+Vector3.new(-6,y,29))
	local marker=part(model,"FactoryOrigin",Vector3.new(1,1,1),CFrame.new(data.X,data.Y,data.Z),C.Amber)
	marker.Transparency=1
	marker.CanQuery=false
	local spawn=part(model,"IslandSpawn",Vector3.new(5,0.4,5),CFrame.new(center+Vector3.new(0,y+0.25,15)),C.Sand,nil,false,"SpawnLocation")
	spawn.Transparency=1
	spawn.Neutral,spawn.Enabled,spawn.Duration=true,false,0
	model.Parent=parent
	task.wait()
end

local function hub(parent)
	local model=Instance.new("Model")
	model.Name="TreehouseMesa"
	island(model,Vector3.zero,69,66,8,55)
	polygon(model,Vector3.new(0,17,0),45,43,18,C.Rock,56)
	polygon(model,Vector3.new(0,26.2,0),45,43,0.7,C.Grass,56)
	polygon(model,Vector3.new(0,38,0),28,25,24,C.Rock,57)
	polygon(model,Vector3.new(0,50.3,0),28,25,0.8,C.GrassLight,57)
	-- Broad switchback boardwalks climb each terrace without jump-only navigation.
	walkway(model,Vector3.new(62,8,25),Vector3.new(38,26.6,25),10,true)
	walkway(model,Vector3.new(38,26.6,25),Vector3.new(-34,26.6,25),10,true)
	walkway(model,Vector3.new(-34,26.6,25),Vector3.new(-34,50.8,-18),10,true)
	walkway(model,Vector3.new(-34,50.8,-18),Vector3.new(27,50.8,-18),10,true)
	part(model,"OldTreeTrunk",Vector3.new(9,47,9),CFrame.new(0,71,0),C.DarkWood,Enum.Material.Wood,true)
	for i=0,4 do
		local a=i*math.pi*2/5
		beam(model,"TreeBranch",Vector3.new(0,82,0),Vector3.new(math.cos(a)*17,96,math.sin(a)*17),4,C.DarkWood,Enum.Material.Wood,true)
		ball(model,"GreatTreeCanopy",Vector3.new(math.cos(a)*15,103+i%2*4,math.sin(a)*15),Vector3.new(31,24,31),if i%2==0 then C.Leaf else C.Grass)
	end
	part(model,"TreehouseDeck",Vector3.new(42,1.2,36),CFrame.new(0,65,0),C.Wood,Enum.Material.WoodPlanks,true)
	cabin(model,Vector3.new(0,65.6,-4),1.7,"CentralTreehouse")
	walkway(model,Vector3.new(27,50.8,-18),Vector3.new(27,65.8,17),9,true)
	walkway(model,Vector3.new(27,65.8,17),Vector3.new(17,65.8,17),9,true)
	for _,x in {-19,19} do
		beam(model,"DeckSupport",Vector3.new(x/2,53,0),Vector3.new(x,64,13),1.5,C.DarkWood,Enum.Material.Wood,true)
		lantern(model,Vector3.new(x,65.6,15))
	end
	-- Two open caves with physical roof/side geometry; crystals are decoration.
	for _,side in {-1,1} do
		local c=Vector3.new(side*46,8,-28)
		for _,x in {-6,6} do part(model,"CavePillar",Vector3.new(4,11,11),CFrame.new(c+Vector3.new(x,5,0)),C.Rock,nil,true) end
		part(model,"CaveRoof",Vector3.new(16,4,12),CFrame.new(c+Vector3.new(0,11,0)),C.Rock,nil,true)
		for i=1,3 do
			local crystal=part(model,"CaveCrystal",Vector3.new(1.4,2+i,1.4),CFrame.new(c+Vector3.new(i-2,1+i/2,-3))*CFrame.Angles(0,0,(i-2)*0.18),Color3.fromRGB(97,211,218),Enum.Material.Neon)
			crystal.Transparency=0.1
		end
	end
	for i=1,9 do
		local a=i*math.pi*2/9
		tree(model,Vector3.new(math.cos(a)*57,8,math.sin(a)*52),0.9,i%2==0)
		flowers(model,Vector3.new(math.cos(a)*60,8,math.sin(a)*55),500+i)
	end
	local water=part(model,"Waterfall",Vector3.new(7,37,0.45),CFrame.new(36,7,-24)*CFrame.Angles(0,-0.4,0),C.Water,Enum.Material.Glass)
	water.Transparency=0.3
	model.Parent=parent
	task.wait()
end

function Builder.build()
	local existing=workspace:FindFirstChild(Config.MapKey)
	if existing then return existing end
	local world=Instance.new("Model")
	world.Name=Config.MapKey
	world:SetAttribute("MapRevision",Config.Revision)
	world.Parent=workspace
	local sea=part(world,"Lagoon",Vector3.new(2048,1,2048),CFrame.new(0,Config.WaterY-0.5,0),C.Water,Enum.Material.Glass)
	sea.Transparency=0.18
	sea.CastShadow=false
	hub(world)
	for index=1,Config.PlotCount do playerIsland(world,index) end
	local bridges=Instance.new("Model")
	bridges.Name="IslandBoardwalks"
	for i=1,Config.PlotCount do
		local a=(i-1)*math.pi/3
		local direction=Vector3.new(math.cos(a),0,math.sin(a))
		local inner=direction*63+Vector3.new(0,8,0)
		local outer=direction*180-direction*(if math.abs(direction.X)>0.6 then 47 else 37)+Vector3.new(0,8,0)
		walkway(bridges,inner,outer,8,true)
	end
	bridges.Parent=world
	task.wait()
	local spawn=part(world,"HarborSpawn",Vector3.new(6,0.5,6),CFrame.new(51,8.25,20),C.Sand,nil,true,"SpawnLocation")
	spawn.Neutral,spawn.Duration=true,0
	spawn.Transparency=1
	local lighting=game:GetService("Lighting")
	lighting.ClockTime=14
	lighting.Brightness=2.5
	lighting.Ambient=Color3.fromRGB(132,145,151)
	lighting.OutdoorAmbient=Color3.fromRGB(159,173,185)
	lighting.GlobalShadows=true
	lighting.EnvironmentDiffuseScale=0.65
	lighting.EnvironmentSpecularScale=0.4
	return world
end

return Builder
