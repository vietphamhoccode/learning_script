local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
while not player do task.wait(0.5) player = Players.LocalPlayer end

-- ================== CẤU HÌNH ==================
local API_URL            = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 1
local codes              = _G.codes or {"ThanksFor810k"}

_G.savedPlaceId  = _G.savedPlaceId  or game.PlaceId
_G.savedServerId = _G.savedServerId or game.JobId
_G.raceProgress  = "N/A"

local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- ================== BIẾN ==================
local MyCar = nil
local MyRace = nil
local lastFinishTime = 0

-- ================== HÀM TIỆN ÍCH ==================
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
	if not http_request then return false end
	local payload = HttpService:JSONEncode({
		username      = player.Name,
		user_id       = player.UserId,
		cash          = cashValue,
		race_progress = raceProgress or "N/A",
		place_id      = game.PlaceId,
		server_id     = game.JobId
	})

	pcall(function()
		http_request({
			Url     = API_URL,
			Method  = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body    = payload
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

-- ================== FIX LAG ==================
local function fixLag()
	pcall(function()
		local lighting = game:GetService("Lighting")
		lighting.GlobalShadows = false
		lighting.FogEnd = 9e9
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		print("[System] ✅ Fix Lag OK")
	end)
end

-- ================== MAIN AUTO RACE (FIX HOÀN THÀNH RACE) ==================
local function mainAutoFarm()
	local gui = player.PlayerGui

	-- Loading & Starter
	if gui:FindFirstChild("LoadingScreen") then
		clickGui(gui.LoadingScreen.Center.Frame.Play.Button)
		task.wait(1.5) return
	end
	if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled then
		clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
		task.wait(0.5)
		clickGui(gui.StarterPick.Menu.Buttons.Confirm)
		task.wait(1) return
	end

	-- Spawn xe
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

	-- Teleport vào Race 8
	if not gui.Races.Container.Visible then
		clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
		task.wait(2.8)
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

	-- ================== HOÀN THÀNH RACE ==================
	if currentCP >= totalCP - 1 then  -- Gần finish
		local finishPart = MyRace:FindFirstChild("Finish", true)
		if finishPart then
			local hrp = MyCar.PrimaryPart
			hrp.AssemblyLinearVelocity = (finishPart.Position - hrp.Position).Unit * 1850 + Vector3.new(0,30,0)
			hrp:PivotTo(CFrame.lookAt(hrp.Position, finishPart.Position))
			
			-- Reset sau khi finish
			if tick() - lastFinishTime > 8 then
				lastFinishTime = tick()
				task.delay(2.5, function()
					print("[Race] ✅ Hoàn thành race! Đang reset...")
				end)
			end
			return
		end
	end

	-- Drive bình thường
	local nextCPNum = currentCP + 1
	local cpName = (nextCPNum >= totalCP) and "Finish" or tostring(nextCPNum)
	local checkpointPart = MyRace:FindFirstChild(cpName, true) or MyRace:FindFirstChild("Finish", true)

	if checkpointPart then
		local hrp = MyCar.PrimaryPart
		local targetPos = checkpointPart.Position + Vector3.new(0, 7, 0) + hrp.CFrame.LookVector * 16
		local dist = (targetPos - hrp.Position).Magnitude
		local direction = (targetPos - hrp.Position).Unit

		local speed = 1100
		if dist < 40 then speed = 1420 end
		if cpName == "Finish" then speed = 1780 end

		hrp.AssemblyLinearVelocity = direction * speed + Vector3.new(0, 30, 0)
		local targetCF = CFrame.lookAt(hrp.Position, targetPos)
		hrp:PivotTo(hrp.CFrame:Lerp(targetCF, 0.9))
	end
end

-- ================== SUB LOOPS ==================
local function runSubLoops()
	-- Noclip + Claim
	task.spawn(function()
		while task.wait(0.2) do
			if MyCar then
				for _, v in pairs(MyCar:GetDescendants()) do
					if v:IsA("BasePart") then v.CanCollide = false end
				end
			end

			-- Claim rewards
			pcall(function()
				local gui = player.PlayerGui
				for _, v in pairs(gui.Main_User_Interface.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
					if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then clickGui(v.Button) end
				end
			end)
		end
	end)

	-- Khóa ghế lái (fix thoát xe)
	task.spawn(function()
		while task.wait(0.06) do
			pcall(function()
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not hum or not MyRace or not MyCar then return end

				local racer = MyRace.Racers:FindFirstChild(player.Name)
				local cp = racer and racer:GetAttribute("Checkpoint") or 0
				local total = MyRace.Checkpoints and MyRace.Checkpoints.Value or 12

				if cp >= total then return end

				local seat = MyCar:FindFirstChildWhichIsA("VehicleSeat", true) or MyCar:FindFirstChildWhichIsA("Seat", true)
				if seat and not hum.Sit then
					player.Character:PivotTo(seat.CFrame)
					task.wait(0.08)
					seat:Sit(hum)
				end
			end)
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
print("[System] 🚀 Script Auto Race - Hoàn thành race nhanh")

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

-- Send data
cashObj:GetPropertyChangedSignal("Value"):Connect(function()
	pcall(sendData, cashObj.Value, _G.raceProgress)
end)

task.spawn(function()
	while task.wait(HEARTBEAT_INTERVAL) do
		pcall(sendData, cashObj.Value, _G.raceProgress)
	end
end)

print("[System] ✅ Auto đua + Hoàn thành race đã hoạt động!")
