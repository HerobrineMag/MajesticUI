-- Сервисы, функции экзекутора и платформа
local Players = game:GetService("Players")

local Env = {
	Players = Players,
	TweenService = game:GetService("TweenService"),
	UserInputService = game:GetService("UserInputService"),
	RunService = game:GetService("RunService"),
	HttpService = game:GetService("HttpService"),
	CoreGui = game:GetService("CoreGui"),
	GuiService = game:GetService("GuiService"),
	Stats = game:GetService("Stats"),
	Lighting = game:GetService("Lighting"),
	MarketplaceService = game:GetService("MarketplaceService"),
	LocalPlayer = Players.LocalPlayer,
}

local UIS = Env.UserInputService
Env.IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- функции файловой системы экзекутора (любая может быть nil)
Env.fs = {
	write = writefile,
	read = readfile,
	isfile = isfile,
	isfolder = isfolder,
	makefolder = makefolder,
	list = listfiles,
	delete = delfile,
}

function Env.fsReady()
	local fs = Env.fs
	return fs.write ~= nil and fs.read ~= nil and fs.isfile ~= nil and fs.makefolder ~= nil
end

-- создаёт вложенные папки: "A/B/C"
function Env.ensureFolder(path)
	if not Env.fs.makefolder then
		return
	end
	local cur = ""
	for part in string.gmatch(path, "[^/\\]+") do
		cur = cur == "" and part or (cur .. "/" .. part)
		local exists = Env.fs.isfolder and Env.fs.isfolder(cur)
		if not exists then
			pcall(Env.fs.makefolder, cur)
		end
	end
end

function Env.clipboard(text)
	local f = setclipboard or toclipboard
	if f then
		local ok = pcall(f, text)
		return ok
	end
	return false
end

function Env.httpGet(url)
	local ok, res = pcall(function()
		return (game :: any):HttpGet(url, true)
	end)
	if ok and type(res) == "string" then
		return res
	end
	return nil
end

return Env
