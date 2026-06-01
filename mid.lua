-- ================== FULL SCRIPT v4.2 - TỐI ƯU RAM + TREO LÂU DÀI ==================
-- • Giữ nguyên 100% autofarm + triệu hồi xe như bản v3 bạn gửi
-- • Tối ưu RAM mạnh + chạy ổn định 8-24 tiếng
-- • Black Screen + Anti-AFK + Báo tiền & thời gian

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

while not player do task.wait(0.5) player = Players.LocalPlayer end

if _G.AutoFarmV2_Running then
    _G.AutoFarmV2_Running = false
    task.wait(1.8)
end
_G.AutoFarmV2_Running = true

local API_URL = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 3
_G.savedPlaceId = _G.savedPlaceId or game.PlaceId
_G.savedServerId = _G.savedServerId or game.JobId
_G.raceProgress = "N/A"

local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
local MyCar = nil
local MyRace = nil
local lastFinishTime = 0
local lastTeleportTime = 0
local lastUpdate = 0
local lastClaimTime = 0
local lastCloseTime = 0
local lastAFKTime = 0
local lastNoclipCar = nil
local raceStartTime = 0
local BlackScreenGui = nil

-- ================== HÀM DỌN DẸP (MỚI) ==================
local function StopScript()
    _G.AutoFarmV2_Running = false
    if BlackScreenGui then BlackScreenGui:Destroy() end
    print("[System] 🛑 Script đã dừng sạch sẽ!")
end

-- ================== BLACK SCREEN (TỐI ƯU - CHỈ TẠO 1 LẦN) ==================
local function enableBlackScreenAndLowGraphics()
    if BlackScreenGui then return end
    pcall(function()
        BlackScreenGui = Instance.new("ScreenGui")
        BlackScreenGui.Name = "BlackScreenOptimizer"
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
    for i = 1, 60 do
        local ls = player:FindFirstChild("leaderstats")
        local cash = ls and ls:FindFirstChild("Cash")
        if cash then return cash end
        task.wait(1)
    end
    return nil
end

local function claimRewards()
    pcall(function()
        local gui = player.PlayerGui
        for _, v in ipairs(gui.Main_User_Interface.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
            if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then clickGui(v.Button) task.wait(0.2) end
        end
        if gui:FindFirstChild("DailyRewards") and gui.DailyRewards.Menu.Today.Claim.Label.Text ~= "Claimed" then
            clickGui(gui.DailyRewards.Menu.Today.Claim)
        end
        for _, v in ipairs(gui.Challenges.Menu.Challenges:GetChildren()) do
            if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then clickGui(v.Action) end
        end
        pcall(function() clickGui(gui.Challenges.Menu.Rewards.Claim) end)
        for _, code in ipairs({"ThanksFor810k"}) do
            gui.RobuxShop.Menu.List.Rewards.Codes.Input.Text = code
            task.wait(0.2)
            clickGui(gui.RobuxShop.Menu.List.Rewards.Codes.Redeem)
        end
    end)
end

local function closeRewardModal()
    pcall(function()
        local gui = player.PlayerGui
        for _, modal in ipairs(gui:GetDescendants()) do
            if modal.Name:find("Reward") or modal.Name:find("Result") or modal.Name:find("Complete") or modal.Name:find("Finish") then
                for _, btn in ipairs(modal:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and (btn.Text == "X" or btn.Text == "✕" or btn.Name:lower():find("close") or btn.Name:lower():find("exit")) then
                        clickGui(btn) return
                    end
                end
            end
        end
    end)
end

-- ================== MAIN AUTOFARM (GIỮ NGUYÊN 100% NHƯ BẢN V3) ==================
local function mainAutoFarm()
    if not _G.AutoFarmV2_Running then return end
    local gui = player.PlayerGui
    local now = tick()
    if gui:FindFirstChild("LoadingScreen") then
        clickGui(gui.LoadingScreen.Center.Frame.Play.Button) task.wait(1) return
    end
    if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled then
        clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
        task.wait(0.5) clickGui(gui.StarterPick.Menu.Buttons.Confirm) task.wait(0.8) return
    end
    if not gui:FindFirstChild("A-Chassis Interface") then
        clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
        task.wait(1.3)
        for _, v in ipairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
            if v:IsA("ImageButton") and v.Name ~= "Teleport" then clickGui(v) task.wait(1.8) break end
        end
        return
    end
    if not gui.Races.Container.Visible then
        if now - lastTeleportTime > 6 then
            lastTeleportTime = now
            clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
            task.wait(2.5)
        end
        return
    end
    MyRace = nil
    for _, race in ipairs(workspace.Races:GetDescendants()) do
        if race:FindFirstChild("Racers") and race.Racers:FindFirstChild(player.Name) then MyRace = race break end
    end
    if not MyRace then return end
    local racer = MyRace.Racers:FindFirstChild(player.Name)
    if not racer then return end
    MyCar = racer:FindFirstChild("Vehicle") and racer.Vehicle.Value
    if not MyCar or not MyCar.PrimaryPart then return end
    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local totalCP = MyRace:FindFirstChild("Checkpoints") and MyRace.Checkpoints.Value or 12
    _G.raceProgress = currentCP .. "/" .. totalCP
    if MyCar ~= lastNoclipCar then
        lastNoclipCar = MyCar
        for _, v in ipairs(MyCar:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end
    end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum and not hum.Sit then
        local seat = MyCar:FindFirstChildWhichIsA("VehicleSeat", true) or MyCar:FindFirstChildWhichIsA("Seat", true)
        if seat then player.Character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0)) seat:Sit(hum) end
    end
    if currentCP == 0 and raceStartTime == 0 then
        raceStartTime = now
    end
    if currentCP >= totalCP then
        if now - lastFinishTime > 4 then
            lastFinishTime = now
            local raceTime = math.floor(now - raceStartTime)
            raceStartTime = 0
           
            task.wait(1.2)
            closeRewardModal()
            task.wait(0.8)
            clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
           
            print("[Race] ✅ Hoàn thành trong " .. raceTime .. " giây!")
        end
        return
    end
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

-- ================== KHỞI CHẠY (TỐI ƯU) ==================
print("[System] 🚀 Đang khởi chạy v4.2 - Tối ưu RAM + Treo lâu dài")

enableBlackScreenAndLowGraphics()
task.wait(2)

local cashObj = getCashObject()
if not cashObj then
    warn("[System] ❌ Không tìm thấy Cash!")
    _G.AutoFarmV2_Running = false
    return
end

cashObj:GetPropertyChangedSignal("Value"):Connect(function()
    if _G.AutoFarmV2_Running then
        pcall(sendData, cashObj.Value, _G.raceProgress)
        print("[Cash] + " .. cashObj.Value .. " Cash")
    end
end)

-- Vòng lặp chính (Dùng Heartbeat thay vì task.wait(0.03) → tiết kiệm RAM rất nhiều)
RunService.Heartbeat:Connect(function()
    if not _G.AutoFarmV2_Running then return end
    pcall(mainAutoFarm)
end)

-- Vòng lặp phụ (Claim + Close + Anti-AFK + Thu gom rác)
task.spawn(function()
    while task.wait(1) do
        if not _G.AutoFarmV2_Running then return end
        local now = tick()
        
        if now - lastClaimTime > 8 then lastClaimTime = now claimRewards() end
        if now - lastCloseTime > 2.5 then lastCloseTime = now closeRewardModal() end
        
        if now - lastAFKTime > 20 then
            lastAFKTime = now
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
        
        -- Thu gom rác mỗi 40 giây (giảm RAM khi chạy lâu)
        if math.floor(now) % 40 == 0 then
            collectgarbage("collect")
        end
    end
end)

-- Gửi dữ liệu định kỳ
task.spawn(function()
    while task.wait(HEARTBEAT_INTERVAL) do
        if not _G.AutoFarmV2_Running then return end
        pcall(sendData, cashObj.Value, _G.raceProgress)
    end
end)

print("[System] ✅ Đã chạy thành công! RAM thấp + ổn định lâu dài.")
print("[System] Gõ: _G.AutoFarmV2_Running = false  để dừng sạch sẽ")
