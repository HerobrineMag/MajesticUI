-- Liquid Glass: настоящее размытие игрового мира за окном.
-- Принцип (как в акриле Fluent): почти прозрачная стеклянная Part вплотную к камере повторяет прямоугольник окна,
-- а эффект DepthOfField размывает «ближние» пиксели, то есть всё, что закрыто этой деталью.
-- Сила размытия: Blur 0-100 -> от 0 до 3 наложенных эффектов DepthOfField.
-- Ограничения: размывается только 3D-сцена (не другие GUI); на низкой графике DepthOfField может не отображаться.
local Env = import("Core/Env")
local ThemeM = import("Core/Theme")

local EFFECT_NAME = "MajesticGlassBlur"
local PART_TRANSPARENCY = 0.98

local Glass = {
	_targets = {},
	_effects = {},
	_saved = {}, -- чужие DepthOfField, которые мы отключили на время работы
	_camConns = {},
	_bound = false,
}

local function map(v, a, b, c, d)
	return (v - a) * (d - c) / (b - a) + c
end

local function worldPoint(pos, dist)
	local ray = workspace.CurrentCamera:ScreenPointToRay(pos.X, pos.Y)
	return ray.Origin + ray.Direction * dist
end

local function createPart()
	local part = Instance.new("Part")
	part.Name = "MajesticGlass"
	part.Color = Color3.new(0, 0, 0)
	part.Material = Enum.Material.Glass
	part.Size = Vector3.new(1, 1, 0)
	part.Anchored = true
	part.CanCollide = false
	part.Locked = true
	part.CastShadow = false
	part.Transparency = 1
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Brick
	mesh.Offset = Vector3.new(0, 0, -1e-6)
	mesh.Parent = part
	part.Parent = workspace
	return part, mesh
end

local function active()
	return ThemeM.Glass.Enabled and ThemeM.Glass.Blur > 0 and #Glass._targets > 0
end

-- подгоняет деталь под экранный прямоугольник рамки
local function updateTarget(t)
	local cam = workspace.CurrentCamera
	local frame = t.frame
	if not cam or not frame.Parent then
		return
	end
	local show = active() and frame.Visible and frame.AbsoluteSize.X > 2
	t.part.Transparency = show and PART_TRANSPARENCY or 1
	if not show then
		return
	end
	-- размытие чуть меньше окна, чтобы края не «вытекали» за рамку
	local off = map(cam.ViewportSize.Y, 0, 2560, 8, 56)
	local size = frame.AbsoluteSize - Vector2.new(off, off)
	local pos = frame.AbsolutePosition + Vector2.new(off / 2, off / 2)
	local dist = 0.001
	local tl = worldPoint(pos, dist)
	local tr = worldPoint(pos + Vector2.new(size.X, 0), dist)
	local br = worldPoint(pos + size, dist)
	local width, height = (tr - tl).Magnitude, (tr - br).Magnitude
	local cf = cam.CFrame
	t.part.CFrame = CFrame.fromMatrix((tl + br) / 2, cf.XVector, cf.YVector, cf.ZVector)
	t.mesh.Scale = Vector3.new(width, height, 0)
end

local function updateAll()
	for _, t in ipairs(Glass._targets) do
		updateTarget(t)
	end
end

----------------------------------------------------------------------
-- Эффекты DepthOfField
----------------------------------------------------------------------
local function setOtherDofEnabled(enabled)
	if enabled then
		for inst, was in pairs(Glass._saved) do
			pcall(function()
				inst.Enabled = was
			end)
		end
		table.clear(Glass._saved)
		return
	end
	local function scan(parent)
		if not parent then
			return
		end
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("DepthOfFieldEffect") and c.Name ~= EFFECT_NAME and Glass._saved[c] == nil then
				Glass._saved[c] = c.Enabled
				c.Enabled = false
			end
		end
	end
	scan(Env.Lighting)
	scan(workspace.CurrentCamera)
end

local function applyEffects()
	if not active() then
		for _, e in ipairs(Glass._effects) do
			e:Destroy()
		end
		table.clear(Glass._effects)
		setOtherDofEnabled(true)
		return
	end
	-- Blur 0-100 -> суммарная интенсивность 0-3, раскладывается на эффекты по 1.0
	local total = ThemeM.Glass.Blur / 100 * 3
	local count = math.ceil(total)
	if #Glass._effects == 0 then
		setOtherDofEnabled(false)
	end
	while #Glass._effects < count do
		local e = Instance.new("DepthOfFieldEffect")
		e.Name = EFFECT_NAME
		e.FarIntensity = 0
		e.InFocusRadius = 0.1
		e.Parent = Env.Lighting
		table.insert(Glass._effects, e)
	end
	while #Glass._effects > count do
		local last = table.remove(Glass._effects)
		if last then
			last:Destroy()
		end
	end
	for i, e in ipairs(Glass._effects) do
		e.NearIntensity = math.clamp(total - (i - 1), 0, 1)
	end
end

local function bindCamera()
	if Glass._bound then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	Glass._bound = true
	for _, prop in ipairs({ "CFrame", "ViewportSize", "FieldOfView" }) do
		table.insert(Glass._camConns, cam:GetPropertyChangedSignal(prop):Connect(updateAll))
	end
end

local function unbindCamera()
	for _, c in ipairs(Glass._camConns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(Glass._camConns)
	Glass._bound = false
end

-- вызывается при смене темы и настроек стекла
function Glass.refresh()
	applyEffects()
	updateAll()
end

-- frame — рамка, область которой нужно размывать; возвращает { Destroy = function }
function Glass.attach(frame)
	local part, mesh = createPart()
	local t = { frame = frame, part = part, mesh = mesh, conns = {} }
	table.insert(Glass._targets, t)
	local function upd()
		updateTarget(t)
	end
	table.insert(t.conns, frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(upd))
	table.insert(t.conns, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(upd))
	table.insert(t.conns, frame:GetPropertyChangedSignal("Visible"):Connect(upd))
	bindCamera()
	Glass.refresh()
	local handle = {}
	function handle.Destroy()
		for _, c in ipairs(t.conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		part:Destroy()
		local idx = table.find(Glass._targets, t)
		if idx then
			table.remove(Glass._targets, idx)
		end
		if #Glass._targets == 0 then
			unbindCamera()
		end
		applyEffects()
	end
	return handle
end

function Glass.destroyAll()
	for i = #Glass._targets, 1, -1 do
		local t = Glass._targets[i]
		pcall(function()
			t.part:Destroy()
		end)
		for _, c in ipairs(t.conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
	end
	table.clear(Glass._targets)
	unbindCamera()
	applyEffects()
end

table.insert(ThemeM._hooks, Glass.refresh)

return Glass
