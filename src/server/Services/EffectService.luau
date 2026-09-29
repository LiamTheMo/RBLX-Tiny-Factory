--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The server names trusted gameplay moments; clients choose how to present them.
local EffectService = {}
local event: RemoteEvent? = nil

function EffectService.start()
	if event then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local factory = remotes:FindFirstChild("Factory")
	if not factory then
		factory = Instance.new("Folder")
		factory.Name = "Factory"
		factory.Parent = remotes
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "PresentationEvent"
	remote.Parent = factory
	event = remote
end

function EffectService.fire(player: Player, eventName: string, payload: { [string]: any }?)
	if event and player.Parent then
		event:FireClient(player, eventName, payload or {})
	end
end

return EffectService
