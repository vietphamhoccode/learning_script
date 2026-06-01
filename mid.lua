-- ================== FULL SCRIPT v4.1 - TỐI ƯU RAM + TREO LÂU DÀI + SỬA SPAWN ==================
-- • Black Screen cực mạnh
-- • RAM thấp, chạy ổn định 8-24 tiếng
-- • Triệu hồi xe (Spawn) đã sửa lỗi
-- • Chỉ báo: Thời gian đua + Tiền

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

while not player do task.wait(0.5) player = Players.LocalPlayer end

-- ================== BIẾN TOÀN CỤC ==================
_G.AutoFarmV2_Running = _G.AutoFarmV2_Running or false
if _G.AutoFarmV2_Running then
    _G.AutoFarmV2_Running = false
    task.wait(1.5)
end
_G.AutoFarmV2_Running = true

local API_URL = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 4
_G.savedPlaceId = _G.savedPlaceId or game.PlaceId
_G.savedServerId = _G.savedServerId or game.JobId
_G.raceProgress = "N/A"

local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- Cache
local MyCar, MyRace, cashObj
local lastFinishTime, lastTeleportTime, lastUpdate, lastClaimTime, lastCloseTime, lastAFKTime = 0, 0, 0, 0, 0, 0
local raceStartTime = 0
local BlackScreenGui = nil
local MainUI, RacesContainer

-- ================== HÀM DỌN DẸP ==================
local function StopScript()
    _G.AutoFarmV2_Running = false
    if BlackScreenGui then BlackScreenGui:Destroy() end
    print("[System] 🛑 Script đã dừng sạch sẽ!")
end

-- ================== BLACK SCREEN + TỐI ƯU ĐỒ HỌA ==================
local function enableBlackScreenAndLowGraphics()
    if BlackScreenGui then return end
    pcall(function()
        BlackScreenGui = Instance.new("ScreenGui")
        BlackScreenGui.Name = "BlackScreenOptimizer_v4"
        BlackScreenGui.IgnoreGuiInset = true
        BlackScreenGui.Parent = player:WaitForChild("PlayerGui")
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BorderSizePixel = 0
        frame.Parent = BlackScreenGui
        
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        Lighting.OutdoorAmbient = Color3.new(0,0,0)
        Lighting.Ambient = Color3.new(0,0,0)
        
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    end)
end

-- ================== HÀM HỖ TRỢ ==================
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
        http_request({Url = API_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
    end)
end

local function getCashObject()
    for i = 1, 40 do
        local ls = player:FindFirstChild("leaderstats")
        local cash = ls and ls:FindFirstChild("Cash")
        if cash then return cash end
        task.wait(0.8)
    end
    return nil
end

local function cacheImportantGUI()
    local gui = player.PlayerGui
    MainUI = gui:FindFirstChild("Main_User_Interface")
    if MainUI then
        RacesContainer = MainUI:FindFirstChild("Teleport") and MainUI.Teleport.Container.Races
    end
end

-- ================== TRIỆU HỒI XE (ĐÃ SỬA LỖI) ==================
local function spawnCar()
    local gui = player.PlayerGui
    if not MainUI then MainUI = gui:FindFirstChild("Main_User_Interface") end
    if not MainUI then return false end

    -- Click nút Spawn
    local spawnBtn = MainUI:FindFirstChild("UI_Frame") 
                     and MainUI.UI_Frame:FindFirstChild("Buttons") 
                     and MainUI.UI_Frame.Buttons:FindFirstChild("Spawn")
    
    if spawnBtn then
        print("[Spawn] Đang click nút Spawn...")
        clickGui(spawnBtn)
        task.wait(2.3)
    else
        warn("[Spawn] Không tìm thấy nút Spawn!")
        return false
    end

    -- Chờ Garage
    local garage = MainUI:FindFirstChild("Garage")
    if not garage or not garage.Visible then
        task.wait(1.8)
        garage = MainUI:FindFirstChild("Garage")
    end
    if not garage then
        warn("[Spawn] Garage không mở!")
        return false
    end

    -- Tìm xe trong Garage
    local vehiclesFolder = garage:FindFirstChild("Container") 
                           and garage.Container:FindFirstChild("Vehicles")
    if not vehiclesFolder then
        warn("[Spawn] Không tìm thấy danh sách xe!")
        return false
    end

    local selected = false
    for _, v in ipairs(vehiclesFolder:GetChildren()) do
        if v:IsA("ImageButton") 
           and v.Name ~= "Teleport" 
           and v.Name ~= "Template" 
           and v.Visible then
            print("[Spawn] Chọn xe: " .. v.Name)
            clickGui(v)
            task.wait(1.7)
            selected = true
            break
        end
    end

    if not selected then
        warn("[Spawn] Không tìm thấy xe nào!")
        return false
    end

    -- Click Confirm (nếu có)
    local confirmBtn = garage:FindFirstChild("Confirm") 
                       or (garage:FindFirstChild("Buttons") and garage.Buttons:FindFirstChild("Confirm"))
    if confirmBtn then
        clickGui(confirmBtn)
        task.wait(1.9)
    end

    -- Kiểm tra xe đã ra chưa
    task.wait(2.8)
    if gui:FindFirstChild("A-Chassis Interface") then
        print("[Spawn] ✅ Triệu hồi xe thành công!")
        return true
    else
        warn("[Spawn] ❌ Xe chưa ra, sẽ thử lại sau...")
        return false
    end
end

-- ================== CLAIM + CLOSE MODAL ==================
local function claimRewards()
    if not MainUI then return end
    pcall(function()
        local rewards = MainUI:FindFirstChild("Rewards")
        if rewards then
            for _, v in ipairs(rewards.PlaytimeRewards.Rewards:GetChildren()) do
                if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then
                    clickGui(v.Button)
                    task.wait(0.15)
                end
            end
        end
        if gui:FindFirstChild("DailyRewards") then
            clickGui(gui.DailyRewards.Menu.Today.Claim)
        end
        if MainUI:FindFirstChild("Challenges") then
            for _, v in ipairs(MainUI.Challenges.Menu.Challenges:GetChildren()) do
                if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then
                    clickGui(v.Action)
                end
            end
        end
    end)
end

local function closeRewardModal()
    pcall(function()
        local gui = player.PlayerGui
        for _, modal in ipairs(gui:GetDescendants()) do
            if modal.Name:find("Reward") or modal.Name:find("Result") or modal.Name:find("Complete") then
                for _, btn in ipairs(modal:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and 
                       (btn.Text == "X" or btn.Text == "✕" or btn.Name:lower():find("close")) then
                        clickGui(btn)
                        return
                    end
                end
            end
        end
    end)
end

-- ================== MAIN AUTO FARM ==================
local function mainAutoFarm()
    if not _G.AutoFarmV2_Running then return end
    
    local gui = player.PlayerGui
    local now = tick()
    
    -- Loading Screen
    if gui:FindFirstChild("LoadingScreen") then
        clickGui(gui.LoadingScreen.Center.Frame.Play.Button)
        task.wait(0.8)
        return
    end
    
    -- Starter Pick
    if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled then
        clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
        task.wait(0.4)
        clickGui(gui.StarterPick.Menu.Buttons.Confirm)
        task.wait(0.6)
        return
    end
    
    -- Triệu hồi xe (ĐÃ SỬA)
    if not gui:FindFirstChild("A-Chassis Interface") then
        spawnCar()
        task.wait(1.3)
        return
    end
    
    -- Vào Race
    if not gui.Races.Container.Visible then
        if now - lastTeleportTime > 7 then
            lastTeleportTime = now
            if RacesContainer then
                clickGui(RacesContainer.Race8.Container.Teleport)
            end
            task.wait(2.2)
        end
        return
    end
    
    -- Tìm Race hiện tại
    MyRace = nil
    for _, race in ipairs(workspace.Races:GetDescendants()) do
        if race:FindFirstChild("Racers") and race.Racers:FindFirstChild(player.Name) then
            MyRace = race
            break
        end
    end
    if not MyRace then return end
    
    local racer = MyRace.Racers:FindFirstChild(player.Name)
    if not racer then return end
    
    MyCar = racer:FindFirstChild("Vehicle") and racer.Vehicle.Value
    if not MyCar or not MyCar.PrimaryPart then return end
    
    -- Noclip
    if MyCar ~= lastNoclipCar then
        lastNoclipCar = MyCar
        for _, v in ipairs(MyCar:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
    
    -- Tự ngồi xe
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum and not hum.Sit then
        local seat = MyCar:FindFirstChildWhichIsA("VehicleSeat", true)
        if seat then
            player.Character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
            seat:Sit(hum)
        end
    end
    
    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local totalCP = MyRace:FindFirstChild("Checkpoints") and MyRace.Checkpoints.Value or 12
    _G.raceProgress = currentCP .. "/" .. totalCP
    
    if currentCP == 0 and raceStartTime == 0 then raceStartTime = now end
    
    -- Hoàn thành đua
    if currentCP >= totalCP then
        if now - lastFinishTime > 3.5 then
            lastFinishTime = now
            local raceTime = math.floor(now - raceStartTime)
            raceStartTime = 0
            task.wait(0.9)
            closeRewardModal()
            task.wait(0.6)
            if RacesContainer then clickGui(RacesContainer.Race8.Container.Teleport) end
            print("[Race] ✅ Hoàn thành trong " .. raceTime .. " giây!")
        end
        return
    end
    
    -- Di chuyển xe
    if now - lastUpdate < 0.028 then return end
    lastUpdate = now
    
    local hrp = MyCar.PrimaryPart
    local nextCPNum = currentCP + 1
    local cpName = (nextCPNum >= totalCP) and "Finish" or tostring(nextCPNum)
    local checkpointPart = MyRace:FindFirstChild(cpName, true) or MyRace:FindFirstChild("Finish", true)
    
    if checkpointPart then
        local targetPos = checkpointPart.Position + Vector3.new(0, 5, 0)
        local direction = (targetPos - hrp.Position).Unit
        local dist = (targetPos - hrp.Position).Magnitude
        
        local speed = 1480
        if dist < 45 then speed = 1820 end
        if cpName == "Finish" then speed = 2280 end
        
        hrp.AssemblyLinearVelocity = direction * speed + Vector3.new(0, 28, 0)
        hrp:PivotTo(hrp.CFrame:Lerp(CFrame.lookAt(hrp.Position, targetPos), 0.92))
    end
end

-- ================== KHỞI CHẠY ==================
print("[System] 🚀 Đang khởi chạy v4.1 - Đã sửa lỗi Spawn xe")

enableBlackScreenAndLowGraphics()
task.wait(1.5)
cacheImportantGUI()

cashObj = getCashObject()
if not cashObj then
    warn("[System] ❌ Không tìm thấy Cash!")
    StopScript()
    return
end

cashObj:GetPropertyChangedSignal("Value"):Connect(function()
    if _G.AutoFarmV2_Running then
        pcall(sendData, cashObj.Value, _G.raceProgress)
    end
end)

-- Vòng lặp chính (Heartbeat - nhẹ RAM)
RunService.Heartbeat:Connect(function()
    if not _G.AutoFarmV2_Running then return end
    pcall(mainAutoFarm)
end)

-- Vòng lặp phụ
task.spawn(function()
    while task.wait(1) do
        if not _G.AutoFarmV2_Running then return end
        local now = tick()
        
        if now - lastClaimTime > 9 then
            lastClaimTime = now
            claimRewards()
        end
        if now - lastCloseTime > 2.8 then
            lastCloseTime = now
            closeRewardModal()
        end
        if now - lastAFKTime > 18 then
            lastAFKTime = now
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
        if math.floor(now) % 45 == 0 then
            collectgarbage("collect")
        end
    end
end)

-- Heartbeat gửi dữ liệu
task.spawn(function()
    while task.wait(HEARTBEAT_INTERVAL) do
        if not _G.AutoFarmV2_Running then return end
        pcall(sendData, cashObj.Value, _G.raceProgress)
    end
end)

print("[System] ✅ Script v4.1 đã chạy thành công!")
print("[System] Gõ: _G.AutoFarmV2_Running = false  để dừng sạch")
