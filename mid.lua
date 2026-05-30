local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

while not player do
	task.wait(0.5)
	player = Players.LocalPlayer
end

-- ── CẤU HÌNH ─────────────────────────────────────────────────
local API_URL            = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 1
local loaded             = false
local lastCash           = nil
local codes              = _G.codes or {"ThanksFor810k"}

_G.waitTime      = 2
_G.maxWaitTime   = 90
_G.raceProgress  = "N/A"

-- Lưu server VIP ngay khi script chạy để rejoin sau khi mất mạng
_G.savedPlaceId  = _G.savedPlaceId  or game.PlaceId
_G.savedServerId = _G.savedServerId or game.JobId

-- ── Request fallback ─────────────────────────────────────────
local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- ══════════════════════════════════════════════════════════════
-- PHẦN 1: CHỜ GAME LOAD HOÀN THIỆN
-- ══════════════════════════════════════════════════════════════

local function waitForGameLoad()
	local gui = player.PlayerGui
	local timeout = tick() + 30
	while not gui:FindFirstChild("LoadingScreen") and tick() < timeout do task.wait(0.5) end

	if gui:FindFirstChild("LoadingScreen") then
		pcall(function()
			local playBtn = gui.LoadingScreen.Center.Frame.Play.Button
			if playBtn then
				if firesignal then firesignal(playBtn.Activated) firesignal(playBtn.MouseButton1Click)
				else playBtn:Activate() end
			end
		end)

		local loadTimeout = tick() + 60
		while gui:FindFirstChild("LoadingScreen") and tick() < loadTimeout do
			pcall(function()
				local playBtn = gui.LoadingScreen.Center.Frame.Play.Button
				if playBtn then
					if firesignal then firesignal(playBtn.Activated) firesignal(playBtn.MouseButton1Click)
					else playBtn:Activate() end
				end
			end)
			task.wait(1)
		end
	end

	local uiTimeout = tick() + 30
	while not gui:FindFirstChild("Main_User_Interface") and tick() < uiTimeout do task.wait(0.5) end

	if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled == true then
		pcall(function()
			if firesignal then
				firesignal(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"].Activated)
				firesignal(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"].MouseButton1Click)
			end
		end)
		task.wait(0.5)
		pcall(function()
			if firesignal then
				firesignal(gui.StarterPick.Menu.Buttons.Confirm.Activated)
				firesignal(gui.StarterPick.Menu.Buttons.Confirm.MouseButton1Click)
			end
		end)
		task.wait(1)
	end

	print("[System] ✅ Game đã load hoàn thiện! Bắt đầu chạy script...")
end

-- ══════════════════════════════════════════════════════════════
-- PHẦN 2: FIX LAG
-- ══════════════════════════════════════════════════════════════

local function fixLag()
	pcall(function()
		local lighting = game:GetService("Lighting")
		lighting.GlobalShadows = false
		lighting.FogEnd = 9e9
		lighting.ShadowSoftness = 0
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

		for _, v in pairs(workspace:GetDescendants()) do
			if v:IsA("Decal") or v:IsA("Texture") then v:Destroy()
			elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
		end

		print("[System] ✅ Fix Lag thành công.")
	end)
end

-- ══════════════════════════════════════════════════════════════
-- PHẦN 3: HÀM TIỆN ÍCH
-- ══════════════════════════════════════════════════════════════

local function clickGui(obj)
	if not obj then return end
	pcall(function()
		if firesignal then
			firesignal(obj.Activated)
			firesignal(obj.MouseButton1Click)
		else
			obj:Activate()
		end
	end)
end

-- ══════════════════════════════════════════════════════════════
-- PHẦN 4: GỬI DỮ LIỆU CASH VỀ API
-- ══════════════════════════════════════════════════════════════

local function sendData(cashValue, raceProgress)
	if not http_request then return false end

	local payload = HttpService:JSONEncode({
		username      = player.Name,
		user_id       = player.UserId,
		cash          = cashValue,
		race_progress = raceProgress or _G.raceProgress or "N/A",
		place_id      = game.PlaceId,
		server_id     = game.JobId
	})

	local success, result = pcall(function()
		local res = http_request({
			Url     = API_URL,
			Method  = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body    = payload
		})
		if res and res.StatusCode == 200 then
			local body = HttpService:JSONDecode(res.Body)
			return body.status == "ok"
		end
		return false
	end)

	return success and result
end

local function getCashObject()
	for i = 1, 60 do
		local ls = player:FindFirstChild("leaderstats")
		local cash = ls and ls:FindFirstChild("Cash")
		if cash then return cash end
		task.wait(1)
	end
	return nil
end

-- ══════════════════════════════════════════════════════════════
-- PHẦN 5: REJOIN ĐÚNG SERVER VIP KHI MẤT KẾT NỐI
-- ══════════════════════════════════════════════════════════════

-- Kiểm tra mạng còn hoạt động không (ping API)
local function isNetworkAlive()
	if not http_request then return true end -- không có http_request thì bỏ qua
	local ok = pcall(function()
		local res = http_request({
			Url    = API_URL .. "?ping=1",
			Method = "GET",
		})
		if not res or res.StatusCode == 0 then
			error("no response")
		end
	end)
	return ok
end

-- Chờ mạng sống lại (thử mỗi 3 giây, tối đa 10 phút)
local function waitForNetwork()
	print("[Rejoin] ⏳ Đang chờ mạng khôi phục...")
	local timeout = tick() + 600
	while tick() < timeout do
		task.wait(3)
		if isNetworkAlive() then
			print("[Rejoin] ✅ Mạng đã trở lại!")
			return true
		end
	end
	warn("[Rejoin] ❌ Timeout chờ mạng (10 phút).")
	return false
end

-- Rejoin đúng server VIP đã lưu
local function rejoinServer()
	local placeId  = _G.savedPlaceId
	local serverId = _G.savedServerId

	if not placeId or not serverId or serverId == "" then
		warn("[Rejoin] ❌ Không có server ID đã lưu, rejoin server ngẫu nhiên.")
		pcall(function()
			TeleportService:Teleport(placeId or game.PlaceId, player)
		end)
		return
	end

	print("[Rejoin] 🔄 Rejoin server: " .. tostring(serverId))

	-- Thử TeleportToPlaceInstance (rejoin đúng server VIP)
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, serverId, player)
	end)

	if not ok then
		warn("[Rejoin] ⚠️ TeleportToPlaceInstance thất bại: " .. tostring(err))
		-- Fallback: rejoin server ngẫu nhiên cùng game
		pcall(function()
			TeleportService:Teleport(placeId, player)
		end)
	end
end

-- Monitor mất mạng liên tục qua heartbeat
local function startRejoinMonitor()
	task.spawn(function()
		local lastHeartbeat = tick()
		local disconnected  = false
		local CHECK_INTERVAL = 5  -- kiểm tra mỗi 5 giây
		local DEAD_THRESHOLD = 15 -- coi là mất mạng nếu API không phản hồi 15s liên tiếp

		-- Theo dõi heartbeat của RunService để phát hiện freeze/disconnect
		local hbConn = RunService.Heartbeat:Connect(function()
			lastHeartbeat = tick()
		end)

		while task.wait(CHECK_INTERVAL) do
			-- Nếu heartbeat bị treo quá lâu → có thể mất kết nối
			local timeSinceHB = tick() - lastHeartbeat
			local networkDead = not isNetworkAlive()

			if networkDead and not disconnected then
				disconnected = true
				warn("[Rejoin] 🔴 Phát hiện mất kết nối! Chờ mạng phục hồi...")

				-- Dừng theo dõi heartbeat tạm thời
				hbConn:Disconnect()

				local networkBack = waitForNetwork()
				if networkBack then
					task.wait(2) -- buffer nhỏ trước khi rejoin
					rejoinServer()
				end
				-- Sau khi rejoin script sẽ chạy lại từ đầu, không cần resume

			elseif not networkDead and disconnected then
				-- Mạng trở lại trong cùng session (hiếm, nhưng xử lý luôn)
				disconnected = false
				hbConn = RunService.Heartbeat:Connect(function()
					lastHeartbeat = tick()
				end)
				print("[Rejoin] ✅ Kết nối phục hồi trong session.")
			end
		end
	end)
end

-- ══════════════════════════════════════════════════════════════
-- PHẦN 6: AUTO FARM RACE
-- ══════════════════════════════════════════════════════════════

local function findMyRace()
	for _, v in pairs(workspace.Races.Race8.Races:GetChildren()) do
		if v.Racers:FindFirstChild(player.Name) then return v end
	end
end

local function mainAutoFarm()
	local gui = player.PlayerGui

	if gui:FindFirstChild("LoadingScreen") then
		clickGui(gui.LoadingScreen.Center.Frame.Play.Button)
		task.wait(1.5)
		return
	elseif gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled == true then
		clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
		task.wait(0.5)
		clickGui(gui.StarterPick.Menu.Buttons.Confirm)
		task.wait(0.5)
		return
	end

	if not gui:FindFirstChild("A-Chassis Interface") then
		clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
		for _, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
			if v:IsA("ImageButton") and v.Name ~= "Teleport" then
				clickGui(v)
				task.wait(1.5)
				break
			end
		end
		return
	end

	if not gui.Races.Container.Visible then
		if _G.wasRace then
			_G.wasRace = nil
			clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
			for _, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
				if v:IsA("ImageButton") and v.Name ~= "Teleport" then
					clickGui(v)
					task.wait(1.5)
					break
				end
			end
		end
		clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
		task.wait(2)
		return
	end

	local myRace = findMyRace()
	if not myRace then
		if _G.myCar and _G.myCar.PrimaryPart then
			pcall(function()
				_G.myCar.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end)
		end
		_G.myCar = nil
		_G.myRace = nil
		return
	end

	local racer = myRace.Racers:FindFirstChild(player.Name)
	if not racer then return end

	local currentCP = racer:GetAttribute("Checkpoint") or 0
	local nextCPNum = currentCP + 1
	local totalCP   = myRace:FindFirstChild("Checkpoints") and myRace.Checkpoints.Value or 12

	_G.raceProgress = currentCP .. "/" .. totalCP
	print("[Race] Checkpoint " .. _G.raceProgress)

	if currentCP == 0 and not _G.firstRaceDelayDone then
		_G.firstRaceDelayDone = true
		print("[System] ⏳ Delay 4 giây cho checkpoint đầu tiên...")
		task.wait(4)
	end

	local checkpointsFolder = nil
	for _, v in pairs(myRace:GetChildren()) do
		if v.Name == "Checkpoints" and v:IsA("IntValue") then
			checkpointsFolder = v
			break
		end
	end
	if not checkpointsFolder then return end

	local cpName         = (nextCPNum >= checkpointsFolder.Value) and "Finish" or tostring(nextCPNum)
	local checkpointPart = checkpointsFolder:FindFirstChild(cpName)
	if not checkpointPart then return end

	local myCar  = racer.Vehicle.Value
	_G.myCar     = myCar
	_G.myRace    = myRace
	_G.wasRace   = true

	-- [FIX 3] Thêm myCar.Parent để tránh thao tác xe đã despawn
	if myCar and myCar.PrimaryPart and myCar.Parent then
		_G.lastRaceUpdate = _G.lastRaceUpdate or 0
		if tick() - _G.lastRaceUpdate < 0.03 then return end
		_G.lastRaceUpdate = tick()

		local hrp        = myCar.PrimaryPart
		local baseTarget = checkpointPart.Position
		local ahead      = hrp.CFrame.LookVector * 12
		local targetPos  = baseTarget + Vector3.new(0, 5, 0) + ahead

		local currentPos = hrp.Position
		local dist       = (targetPos - currentPos).Magnitude
		local direction  = (targetPos - currentPos).Unit

		local speed = 1020
		if dist < 38 then speed = 1320 end
		if cpName == "Finish" or nextCPNum >= checkpointsFolder.Value - 2 then
			speed = 1620
		end

		hrp.AssemblyLinearVelocity = direction * speed + Vector3.new(0, 22, 0)

		for _, part in pairs(myCar:GetDescendants()) do
			if part:IsA("BasePart") and part ~= hrp then
				part.AssemblyLinearVelocity = direction * speed
			end
		end

		local targetCFrame = CFrame.new(currentPos, targetPos)
		hrp:PivotTo(targetCFrame:Lerp(hrp.CFrame, 0.87))

		-- [FIX 1] Reset state sau khi chạm Finish để tránh văng
		if dist < 20 and cpName == "Finish" then
			hrp.AssemblyLinearVelocity = direction * 1750
			task.delay(1.5, function()
				_G.myCar              = nil
				_G.myRace             = nil
				_G.wasRace            = true
				_G.firstRaceDelayDone = nil
				print("[Race] ✅ Đã về đích! Reset trạng thái xe.")
			end)
		end
	end
end

-- ══════════════════════════════════════════════════════════════
-- PHẦN 7: VÒNG LẶP PHỤ + ANTI-THOÁT XE
-- ══════════════════════════════════════════════════════════════

local function runSubLoops()
	-- Vòng lặp 1: Noclip + Auto Claim + Codes
	task.spawn(function()
		while task.wait(0.2) do
			local gui = player.PlayerGui
			if gui:FindFirstChild("LoadingScreen") then continue end

			pcall(function()
				if gui.Races.Container.Visible then
					if _G.myCar then
						for _, v in pairs(_G.myCar:GetDescendants()) do
							if v:IsA("BasePart") then v.CanCollide = false end
						end
					end
					if player.Character then
						for _, v in pairs(player.Character:GetDescendants()) do
							if v:IsA("BasePart") then v.CanCollide = false end
						end
					end
					for _, v in pairs(workspace:GetChildren()) do
						if (v.ClassName == "Model" and v:FindFirstChild("Container")) or v.Name == "PortCraneOversized" then
							v:Destroy()
						end
					end
				end
			end)

			pcall(function()
				for _, v in pairs(gui.Main_User_Interface.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
					if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then clickGui(v.Button) end
				end
			end)

			pcall(function()
				for _, v in pairs(gui.Challenges.Menu.Challenges:GetChildren()) do
					if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then clickGui(v.Action) end
				end
			end)

			pcall(function()
				if gui.DailyRewards.Menu.Today.Claim.Label.Text ~= "Claimed" then
					clickGui(gui.DailyRewards.Menu.Today.Claim)
				end
			end)

			pcall(function()
				if gui.RobuxShop.Menu.List.Boosts.Boost.Use.Visible == true then
					clickGui(gui.RobuxShop.Menu.List.Boosts.Boost.Use)
				end
			end)

			pcall(function() clickGui(gui.Challenges.Menu.Rewards.Claim) end)

			pcall(function()
				for _, v in pairs(codes) do
					gui.RobuxShop.Menu.List.Rewards.Codes.Input.Text = v
					task.wait()
					clickGui(gui.RobuxShop.Menu.List.Rewards.Codes.Redeem)
					task.wait()
				end
			end)
		end
	end)

	-- Vòng lặp 2: KHÓA CHẶT GHẾ LÁI (0.05s)
	task.spawn(function()
		while task.wait(0.05) do
			pcall(function()
				local gui = player.PlayerGui
				if gui.Races.Container.Visible and _G.myRace and player.Character then
					local hum = player.Character:FindFirstChildOfClass("Humanoid")

					-- [FIX 2] Không sit khi đã về đích
					local racer2     = _G.myRace and _G.myRace.Racers:FindFirstChild(player.Name)
					local currentCP2 = racer2 and (racer2:GetAttribute("Checkpoint") or 0) or 0
					local totalCP2   = _G.myRace and _G.myRace:FindFirstChild("Checkpoints") and _G.myRace.Checkpoints.Value or 12
					local isFinished = currentCP2 >= totalCP2

					if hum and not hum.Sit and _G.myCar and _G.myCar.Parent and not isFinished then
						local seat = _G.myCar:FindFirstChildWhichIsA("VehicleSeat", true)
							or _G.myCar:FindFirstChildWhichIsA("Seat", true)
						if seat and player.Character.PrimaryPart then
							player.Character:PivotTo(seat.CFrame)
							task.wait()
							seat:Sit(hum)
							hum.Sit = true
						end
					end
				end
			end)
		end
	end)

	-- Vòng lặp 3: ANTI-AFK KICK (bypass kick 20 phút không hoạt động)
	task.spawn(function()
		local VirtualUser = game:GetService("VirtualUser")
		while task.wait(60) do
			-- Cách 1: VirtualUser simulate click (mạnh nhất, bypass mọi AFK detector)
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0, 0))
				VirtualUser:Button2Up(Vector2.new(0, 0))
			end)
			-- Cách 2: Simulate humanoid state để Roblox coi là còn active
			pcall(function()
				if player.Character then
					local hum = player.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum:ChangeState(Enum.HumanoidStateType.Running)
					end
				end
			end)
			-- Cách 3: Reset idle timer thông qua CameraType
			pcall(function()
				local cam = workspace.CurrentCamera
				if cam then
					local prev = cam.CameraType
					cam.CameraType = Enum.CameraType.Watch
					task.wait()
					cam.CameraType = prev
				end
			end)
			print("[AFK] ð¢ Anti-AFK ping @ " .. os.date("%H:%M:%S"))
		end
	end)
end

-- âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
-- KHá»I CHáº Y
-- ══════════════════════════════════════════════════════════════

print("[Rejoin] 💾 Đã lưu server: PlaceId=" .. tostring(_G.savedPlaceId) .. " | JobId=" .. tostring(_G.savedServerId))

fixLag()
waitForGameLoad()

print("[System] ✅ Đang tìm Cash...")
local cashObj = getCashObject()
if not cashObj then warn("[System] ❌ Không tìm thấy leaderstats/Cash sau 60s!") return end
print("[System] ✅ Đã tìm thấy Cash: " .. tostring(cashObj.Value))

-- Gửi dữ liệu lần đầu
local firstSend = sendData(cashObj.Value, _G.raceProgress)
if firstSend then
	print("[System] ✅ Gửi API lần đầu thành công!")
else
	print("[System] ⚠️ Gửi API lần đầu thất bại, vẫn tiếp tục chạy script.")
end

loaded = true

-- Khởi động monitor rejoin
startRejoinMonitor()

-- Vòng lặp Auto Farm
task.spawn(function()
	while task.wait() do
		local success, err = pcall(mainAutoFarm)
		if not success then warn("AutoFarm Error: " .. tostring(err)) end
	end
end)

-- Vòng lặp phụ
runSubLoops()

-- ══════════════════════════════════════════════════════════════
-- PHẦN 8: GỬI DỮ LIỆU CASH LIÊN TỤC (HEARTBEAT + ON CHANGE)
-- ══════════════════════════════════════════════════════════════

-- Gửi ngay khi Cash thay đổi + reset nhân vật nếu nhận > 40.000
cashObj:GetPropertyChangedSignal("Value"):Connect(function()
	local val = cashObj.Value
	if val ~= lastCash then
		local diff = (lastCash ~= nil) and (val - lastCash) or 0
		lastCash = val
		pcall(sendData, val, _G.raceProgress)

		-- Reset nhân vật khi nhận thưởng lớn hơn 40.000
		if diff > 40000 then
			print("[Reset] 💰 Nhận thưởng " .. tostring(diff) .. " > 40.000 → Reset nhân vật!")
			task.delay(0.5, function()
				pcall(function()
					player.Character:BreakJoints()
				end)
			end)
		end
	end
end)

-- Heartbeat mỗi 1 giây
task.spawn(function()
	while task.wait(HEARTBEAT_INTERVAL) do
		pcall(sendData, cashObj.Value, _G.raceProgress)
	end
end)

print("[System] 🚀 Script đã khởi chạy hoàn tất! Rejoin server VIP & Chống văng xe đều hoạt động.")
