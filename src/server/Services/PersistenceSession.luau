--!strict

local PersistenceSession = {}

function PersistenceSession.acquire(store: any, key: string, sessionId: string, now: number, lockSeconds: number, sanitize: (any) -> any): (boolean, any, string?)
	local locked = false
	local ok, record = pcall(function()
		return store:UpdateAsync(key, function(old: any)
			local data = if type(old) == "table" and type(old.Data) == "table" then old.Data else old
			local owner = if type(old) == "table" then old._SessionId else nil
			local seen = if type(old) == "table" then old._LastSeen else nil
			if owner and owner ~= sessionId and type(seen) == "number" and now - seen < lockSeconds then
				locked = true
				return nil
			end
			return { Data = sanitize(data), _SessionId = sessionId, _LastSeen = now }
		end)
	end)
	if not ok then return false, nil, "store" end
	if locked or record == nil then return false, nil, "locked" end
	return true, record.Data
end

function PersistenceSession.save(store: any, key: string, sessionId: string, data: any, release: boolean, now: number): (boolean, string?)
	local conflict = false
	local ok, record = pcall(function()
		return store:UpdateAsync(key, function(old: any)
			local owner = if type(old) == "table" then old._SessionId else nil
			if owner ~= sessionId then
				conflict = true
				return nil
			end
			return { Data = data, _SessionId = if release then nil else sessionId, _LastSeen = now }
		end)
	end)
	if not ok then return false, "store" end
	if conflict or record == nil then return false, "conflict" end
	return true
end

return PersistenceSession
