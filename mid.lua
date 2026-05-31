local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
while not player do task.wait(0.5) player = Players.LocalPlayer end

-- ================== CẤU HÌNH ==================
local API_URL            = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 3
local codes              = _G.codes or {"ThanksFor810k"}

_G.savedPlaceId  = _G.savedPlaceId  or game.PlaceId
_G.savedServerId = _G.savedServerId or game.JobId
_G.raceProgress  = "N/A"

local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- ================== BIẾN ==================
local MyCar = nil
local MyRace = nil
local lastFinishTime = 0
local lastTeleportTime = 0
local lastUpdate = 0
local lastSpawnAttempt = 0
local stuckCounter = 0
local justSpawned = false

-- ================== HÀM ==================
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

local function sendData(cashValue, raceProgress)
	if not http_request then return end
	pcall(function()
		local payload = HttpService:JSONEncode({
			username = player.Name,
			user_id = player.UserId,
			cash = cashValue or 0,
			race_progress = raceProgress or "N/A",
			place_id = game.PlaceId,
			server_id = game.JobId,
			timestamp = os.time()
		})
		http_request({
			Url = API_URL, Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = payload
		})
	end)
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

local function fixLag()
	pcall(function()
		local lighting = game:GetService("Lighting")
		lighting.GlobalShadows = false
		lighting.FogEnd = 9e9
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
end

-- ================== KIỂM TRA CÓ ĐANG CÓ XE THẬT KHÔNG ==================
local function hasValidCar()
	if not MyCar then return false end
	if not MyCar.Parent then return false end
	if not MyCar.PrimaryPart then return false end
	
	local seat = MyCar:FindFirstChildWhichIsA("VehicleSeat", true) or MyCar:FindFirstChildWhichIsA("Seat", true)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	
	if seat and hum and hum.Sit then
		return true
	end
	return false
end

-- ================== FORCE SPAWN XE (ĐÃ FIX) ==================
local function forceSpawnCar()
	local now = tick()
	if now - lastSpawnAttempt < 12 then return end
	lastSpawnAttempt = now
	justSpawned = true

	print("[Recovery] 🔄 Force Spawn xe...")

	local gui = player.PlayerGui
	pcall(function()
		clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
		task.wait(1.4)

		for _, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
			if v:IsA("ImageButton") and v.Name ~= "Teleport" then
				clickGui(v)
				task.wait(2.2)
				print("[Recovery] ✅ Đã spawn xe")
				stuckCounter = 0
				task.delay(8, function() justSpawned = false end)
				return
			end
		end
	end)
end

-- ================== ĐÓNG MODAL ==================
local function closeRewardModal()
	pcall(function()
		local gui = player.PlayerGui
		for _, modal in pairs(gui:GetDescendants()) do
			if modal.Name:find("Reward") or modal.Name:find("Result") or modal.Name:find("Complete") or modal.Name:find("Finish") then
				for _, btn in pairs(modal:GetDescendants()) do
					if btn:IsA("TextButton") or btn:IsA("ImageButton") then
						local text = btn.Text or ""
						local name = btn.Name:lower()
						if text == "X" or text == "✕" or name:find("close") or name:find("exit") then
							clickGui(btn)
							return
						end
					end
				end
			end
		end
	end)
end

-- ================== MAIN AUTO FARM ==================
local function mainAutoFarm()
	local gui = player.PlayerGui
	local now = tick()

	-- Loading & Starter
	if gui:FindFirstChild("LoadingScreen") then
		clickGui(gui.LoadingScreen.Center.Frame.Play.Button) task.wait(1) return
	end
	if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled then
		clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
		task.wait(0.5)
		clickGui(gui.StarterPick.Menu.Buttons.Confirm)
		task.wait(0.8) return
	end

	-- Kiểm tra kẹt xe (CHÍNH XÁC HƠN)
	local isRacing = gui.Races.Container.Visible
	local hasCar = hasValidCar()

	if (not isRacing and not hasCar) or (not gui:FindFirstChild("A-Chassis Interface")) then
		stuckCounter = stuckCounter + 1
		if stuckCounter >= 10 and not justSpawned then  -- Tăng ngưỡng lên 10 (~20-25 giây)
			forceSpawnCar()
			stuckCounter = 0
		end
	else
		stuckCounter = 0
	end

	-- Spawn xe nếu chưa có A-Chassis
	if not gui:FindFirstChild("A-Chassis Interface") then
		clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
		task.wait(1.3)
		for _, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
			if v:IsA("ImageButton") and v.Name ~= "Teleport" then
				clickGui(v) task.wait(1.8) break
			end
		end
		return
	end

	-- Teleport vào Race8
	if not gui.Races.Container.Visible and not hasValidCar() then
		if now - lastTeleportTime > 6 then
			lastTeleportTime = now
			clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
			task.wait(2.5)
		end
		return
	end

	-- Tìm race
	MyRace = nil
	for _, race in pairs(workspace.Races:GetDescendants()) do
		if race:FindFirstChild("Racers") and race.Racers:FindFirstChild(player.Name) then
			MyRace = race 
			break
		end
	end

	if not MyRace then 
		MyCar = nil 
		return 
	end

	local racer = MyRace.Racers:FindFirstChild(player.Name)
	if not racer then return end

	MyCar = racer:FindFirstChild("Vehicle") and racer.Vehicle.Value
	if not MyCar or not MyCar.PrimaryPart then return end

	local currentCP = racer:GetAttribute("Checkpoint") or 0
	local totalCP = MyRace:FindFirstChild("Checkpoints") and MyRace.Checkpoints.Value or 12
	_G.raceProgress = currentCP .. "/" .. totalCP

	-- Hoàn thành race
	if currentCP >= totalCP then
		if now - lastFinishTime > 4 then
			lastFinishTime = now
			print("[Race] ✅ Hoàn thành! Đóng modal...")
			task.wait(1.2)
			closeRewardModal()
			task.wait(1)
			pcall(function() if player.Character then player.Character:BreakJoints() end end)
			task.wait(1.5)
			clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
		end
		return
	end

	-- Drive
	if now - lastUpdate < 0.028 then return end
	lastUpdate = now

	local hrp = MyCar.PrimaryPart
	local nextCPNum = currentCP + 1
	local cpName = (nextCPNum >= totalCP) and "Finish" or tostring(nextCPNum)
	local checkpointPart = MyRace:FindFirstChild(cpName, true) or MyRace:FindFirstChild("Finish", true)

	if checkpointPart then
		local lookahead = hrp.CFrame.LookVector * 22
		local targetPos = checkpointPart.Position + Vector3.new(0, 5, 0) + lookahead
		
		local dist = (targetPos - hrp.Position).Magnitude
		local direction = (targetPos - hrp.Position).Unit

		local speed = 1480
		if dist < 45 then speed = 1820 end
		if cpName == "Finish" or nextCPNum >= totalCP - 2 then speed = 2280 end

		hrp.AssemblyLinearVelocity = direction * speed + Vector3.new(0, 35, 0)
		hrp:PivotTo(hrp.CFrame:Lerp(CFrame.lookAt(hrp.Position, targetPos), 0.95))
	end
end

-- ================== SUB LOOPS ==================
local function runSubLoops()
	-- Khóa ghế
	task.spawn(function()
		while task.wait(0.03) do
			pcall(function()
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not hum or not MyCar then return end
				local seat = MyCar:FindFirstChildWhichIsA("VehicleSeat", true) or MyCar:FindFirstChildWhichIsA("Seat", true)
				if seat and not hum.Sit then
					player.Character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
					task.wait(0.05)
					seat:Sit(hum)
				end
			end)
		end
	end)

	-- Noclip
	task.spawn(function()
		while task.wait(0.2) do
			if MyCar and MyCar.Parent then
				for _, v in pairs(MyCar:GetDescendants()) do
					if v:IsA("BasePart") then v.CanCollide = false end
				end
			end
		end
	end)

	-- Đóng modal
	task.spawn(function()
		while task.wait(1.5) do
			closeRewardModal()
		end
	end)

	-- Anti-AFK
	task.spawn(function()
		while task.wait(35) do
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0,0))
			end)
		end
	end)
end

-- ================== KHỞI CHẠY ==================
print("[System] 🚀 Đã fix lỗi Force Spawn liên tục khi đang có xe")

fixLag()
task.wait(2)

local cashObj = getCashObject()
if not cashObj then warn("[System] ❌ Không tìm thấy Cash!") return end

runSubLoops()

task.spawn(function()
	while task.wait() do
		pcall(mainAutoFarm)
	end
end)

cashObj:GetPropertyChangedSignal("Value"):Connect(function()
	pcall(sendData, cashObj.Value, _G.raceProgress)
end)

task.spawn(function()
	while task.wait(HEARTBEAT_INTERVAL) do
		pcall(sendData, cashObj.Value, _G.raceProgress)
	end
end)

print("[System] ✅ Đã tối ưu phát hiện xe - Không còn force spawn khi đang đua")
