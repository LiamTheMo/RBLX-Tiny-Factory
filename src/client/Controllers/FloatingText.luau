--!strict

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Feedback = require(Shared.MachineVisualConfig).Feedback

local FloatingText = {}
local active: { Part } = {}
local sequence = 0

function FloatingText.show(position: Vector3, text: string, color: Color3)
	for index = #active, 1, -1 do
		if not active[index].Parent then table.remove(active, index) end
	end
	if #active >= Feedback.MaxSalePopups then table.remove(active, 1):Destroy() end
	sequence += 1
	local marker = Instance.new("Part")
	marker.Name = "SalePopup"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(0.1, 0.1, 0.1)
	marker.Position = position
	marker.Parent = workspace
	table.insert(active, marker)
	local popup = Instance.new("BillboardGui")
	popup.Name = "FloatingCoins"
	popup.Adornee = marker
	popup.Size = UDim2.fromOffset(210, 50)
	popup.StudsOffsetWorldSpace = Vector3.new(0, 0.5, 0)
	popup.AlwaysOnTop = true
	popup.MaxDistance = Feedback.HoverDistance
	popup.Parent = marker
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Rotation = -4
	frame.Parent = popup
	local scale = Instance.new("UIScale")
	scale.Scale = 0.65
	scale.Parent = frame
	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(60, 46, 25)
	label.TextStrokeTransparency = 0.15
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.Parent = frame
	local duration = Feedback.SaleDuration
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(frame, TweenInfo.new(0.3), { Rotation = 0 }):Play()
	TweenService:Create(popup, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(if sequence % 2 == 0 then 0.35 else -0.35, 2.8, 0) }):Play()
	task.delay(duration * 0.45, function()
		if marker.Parent then
			TweenService:Create(label, TweenInfo.new(duration * 0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
	Debris:AddItem(marker, duration + 0.1)
end

return FloatingText
