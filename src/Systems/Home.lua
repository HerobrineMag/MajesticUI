-- Window:HomeTab({ Welcome, Buttons = {{Name, Desc, Link, Callback}}, Changelog = {{Title, Text}} })
-- Профиль игрока + живая статистика сервера (игроки, пинг, FPS, сессия, Place ID, Job ID)
local Env = import("Core/Env")
local Util = import("Core/Util")
local Window = import("Core/Window")
local Notify = import("Systems/Notify")

local new, corner, stroke = Util.new, Util.corner, Util.stroke

local function formatTime(sec)
	return string.format("%d:%02d:%02d", math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
end

function Window:HomeTab(cfg)
	cfg = cfg or {}
	local lp = Env.LocalPlayer
	local tab = self:Tab({ Name = cfg.Name or "Home", Icon = cfg.Icon or "home", IconUrl = cfg.IconUrl })
	tab.TabButton.LayoutOrder = 0 -- всегда первая в списке

	-- карточка профиля
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 88), ClipsDescendants = true, LayoutOrder = tab:_nextOrder(),
		Theme = { BackgroundColor3 = "Element" }, Parent = tab.Holder,
	})
	corner(card, 8)
	stroke(card)
	local avatar = new("ImageLabel", {
		Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(14, 14), BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = "Background" }, Parent = card,
	})
	corner(avatar, 30)
	task.spawn(function()
		pcall(function()
			avatar.Image = Env.Players:GetUserThumbnailAsync(
				lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100
			)
		end)
	end)
	new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 22), Position = UDim2.fromOffset(86, 14),
		Text = (cfg.Welcome or "Welcome back") .. ", " .. lp.DisplayName, Font = Enum.Font.GothamBold, TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "Text" }, Parent = card,
	})
	new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 16), Position = UDim2.fromOffset(86, 38), Text = "@" .. lp.Name, TextSize = 12,
		Theme = { TextColor3 = "SubText" }, Parent = card,
	})
	local gameLabel = new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 16), Position = UDim2.fromOffset(86, 56), Text = "", TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "Accent" }, Parent = card,
	})
	task.spawn(function()
		local ok, info = pcall(function()
			return Env.MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		gameLabel.Text = ok and info and info.Name or game.Name
	end)

	-- статистика сервера
	if cfg.ShowStats ~= false then
		-- верхний ряд: 4 компактные карточки
		local grid = new("Frame", {
			Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, LayoutOrder = tab:_nextOrder(), Parent = tab.Holder,
		})
		new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -6, 0, 56), CellPadding = UDim2.fromOffset(8, 8), Parent = grid,
		})

		local function statCard(caption)
			local b = new("Frame", { Theme = { BackgroundColor3 = "Element" }, Parent = grid })
			corner(b, 8)
			stroke(b)
			local value = new("TextLabel", {
				Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(10, 8), Text = "-", Font = Enum.Font.GothamBold,
				TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "Text" }, Parent = b,
			})
			new("TextLabel", {
				Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(10, 32), Text = caption, TextSize = 11,
				Theme = { TextColor3 = "SubText" }, Parent = b,
			})
			return value
		end

		-- широкие карточки: ID целиком, без обрезки (клик копирует)
		local function wideCard(caption, text)
			local b = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 46), LayoutOrder = tab:_nextOrder(), BackgroundTransparency = 0,
				Theme = { BackgroundColor3 = "Element" }, Parent = tab.Holder,
			})
			corner(b, 8)
			stroke(b)
			new("TextLabel", {
				Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 6), Text = caption .. "  (click to copy)",
				TextSize = 11, Theme = { TextColor3 = "SubText" }, Parent = b,
			})
			new("TextLabel", {
				Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 22), Text = text, Font = Enum.Font.GothamBold,
				TextSize = Env.IsMobile and 11 or 12, Theme = { TextColor3 = "Text" }, Parent = b,
			})
			b.MouseButton1Click:Connect(function()
				local copied = Env.clipboard(text)
				Notify.show({
					Title = copied and "Copied" or "Clipboard unavailable", Content = caption,
					Type = copied and "Success" or "Warning", Duration = 2,
				})
			end)
		end

		local vPlayers = statCard("Players")
		local vPing = statCard("Ping")
		local vFps = statCard("FPS")
		local vTime = statCard("Session")
		wideCard("Place ID", tostring(game.PlaceId))
		wideCard("Job ID", game.JobId ~= "" and game.JobId or "Studio")

		local frames, last, started = 0, os.clock(), os.clock()
		self:_connect(Env.RunService.RenderStepped, function()
			frames += 1
		end)
		task.spawn(function()
			while self._alive do
				local now = os.clock()
				local fps = math.floor(frames / math.max(now - last, 0.001) + 0.5)
				frames, last = 0, now
				pcall(function()
					vPlayers.Text = #Env.Players:GetPlayers() .. " / " .. Env.Players.MaxPlayers
					vFps.Text = tostring(fps)
					vTime.Text = formatTime(math.floor(now - started))
					local ok, ping = pcall(function()
						return Env.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
					end)
					vPing.Text = ok and (math.floor(ping + 0.5) .. " ms") or "-"
				end)
				task.wait(1)
			end
		end)
	end

	-- кнопки-ссылки
	if cfg.Buttons and #cfg.Buttons > 0 then
		tab:Section("Links")
		for _, b in ipairs(cfg.Buttons) do
			tab:Button({
				Name = b.Name, Desc = b.Desc, Icon = b.Icon, IconUrl = b.IconUrl, ButtonIcon = b.ButtonIcon or (b.Link and "copy" or "click"),
				Callback = function()
					if b.Link then
						local copied = Env.clipboard(b.Link)
						Notify.show({ Title = copied and "Link copied" or b.Link, Content = b.Name, Type = "Info", Duration = 3 })
					end
					Util.fire(b.Callback)
				end,
			})
		end
	end

	-- список изменений
	if cfg.Changelog and #cfg.Changelog > 0 then
		tab:Section("Changelog")
		for _, entry in ipairs(cfg.Changelog) do
			tab:Paragraph(entry.Title or entry[1] or "", entry.Text or entry[2] or "")
		end
	end
	return tab
end

return true
