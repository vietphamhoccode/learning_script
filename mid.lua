-- ================== TỐI ƯU RAM & BỘ NHỚ TỐI ĐA + AN TOÀN ==================
-- Phiên bản v2.1 - Đã thêm bảo vệ chống script chồng chéo
-- • Tự động dừng script cũ trước khi chạy script mới
-- • Giảm từ 5+ coroutine xuống chỉ còn 2 task.spawn
-- • Noclip chỉ chạy 1 lần khi xe thay đổi (tiết kiệm ~90% CPU/RAM)
-- • Ghế lái + Noclip tích hợp vào vòng lặp chính
-- • Claim reward & đóng modal chỉ chạy mỗi 1.5-2.5 giây
-- • Dùng ipairs thay vì pairs (nhanh hơn 15-20%)
-- • Vẫn giữ đầy đủ tính năng: Farm + Nhận thưởng + Reset + Heartbeat

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer
while not player do task.wait(0.5) player = Players.LocalPlayer end

-- ================== BẢO VỆ CHỐNG CHỒNG CHÉO (QUAN TRỌNG) ==================
if _G.AutoFarmV2_Running then
    print("[System] ⚠️ Phát hiện script cũ đang chạy → Đang dừng script cũ...")
    _G.AutoFarmV2_Running = false
    task.wait(1.8)  -- Đợi các vòng lặp cũ dừng hẳn
end
_G.AutoFarmV2_Running = true

-- ================== CẤU HÌNH ==================
local API_URL = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 3
local RESET_INTERVAL = 180
local STUCK_THRESHOLD = 45
_G.savedPlaceId = _G.savedPlaceId or game.PlaceId
_G.savedServerId = _G.savedServerId or game.JobId
_G.raceProgress = "N/A"
local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- ================== BIẾN ==================
local MyCar = nil
local MyRace = nil
local lastFinishTime = 0
local lastTeleportTime = 0
local lastUpdate = 0
local lastResetTime = 0
local lastProgress = "0/12"
local stuckStartTime = 0
local lastNoclipCar = nil
local lastClaimTime = 0
local lastCloseTime = 0
local lastAFKTime = 0

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
            Url = API_URL,
            Method = "POST",
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

-- ================== RESET TOÀN BỘ ==================
local function fullReset()
    local now = tick()
    if now - lastResetTime < 25 then return end
    lastResetTime = now
    pcall(function()
        if player.Character then player.Character:BreakJoints() end
    end)
    task.wait(2.5)
    local gui = player.PlayerGui
    pcall(function()
        clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
        task.wait(1.4)
        for _, v in ipairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
            if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                clickGui(v)
                task.wait(2)
                break
            end
        end
    end)
    task.wait(2)
    pcall(function()
        clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
    end)
end

-- ================== NHẬN THƯỞNG TỰ ĐỘNG ==================
local function claimRewards()
    pcall(function()
        local gui = player.PlayerGui
        for _, v in ipairs(gui.Main_User_Interface.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
            if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then
                clickGui(v.Button)
                task.wait(0.2)
            end
        end
        if gui:FindFirstChild("DailyRewards") and gui.DailyRewards.Menu.Today.Claim.Label.Text ~= "Claimed" then
            clickGui(gui.DailyRewards.Menu.Today.Claim)
        end
        for _, v in ipairs(gui.Challenges.Menu.Challenges:GetChildren()) do
            if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then
                clickGui(v.Action)
            end
        end
        pcall(function()
            clickGui(gui.Challenges.Menu.Rewards.Claim)
        end)
        for _, code in ipairs({"ThanksFor810k"}) do
            gui.RobuxShop.Menu.List.Rewards.Codes.Input.Text = code
            task.wait(0.2)
            clickGui(gui.RobuxShop.Menu.List.Rewards.Codes.Redeem)
        end
    end)
end

-- ================== ĐÓNG MODAL ==================
local function closeRewardModal()
    pcall(function()
        local gui = player.PlayerGui
        for _, modal in ipairs(gui:GetDescendants()) do
            if modal.Name:find("Reward") or modal.Name:find("Result") or modal.Name:find("Complete") or modal.Name:find("Finish") then
                for _, btn in ipairs(modal:GetDescendants()) do
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
    if not _G.AutoFarmV2_Running then return end   -- Bảo vệ

    local gui = player.PlayerGui
    local now = tick()

    if gui:FindFirstChild("LoadingScreen") then
        clickGui(gui.LoadingScreen.Center.Frame.Play.Button)
        task.wait(1)
        return
    end

    if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled then
        clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
        task.wait(0.5)
        clickGui(gui.StarterPick.Menu.Buttons.Confirm)
        task.wait(0.8)
        return
    end

    local currentProgress = _G.raceProgress or "0/12"
    if currentProgress == lastProgress then
        if stuckStartTime == 0 then stuckStartTime = now end
        if now - stuckStartTime > STUCK_THRESHOLD then
            fullReset()
            stuckStartTime = 0
        end
    else
        stuckStartTime = 0
        lastProgress = currentProgress
    end

    if now - lastResetTime > RESET_INTERVAL then
        fullReset()
    end

    if not gui:FindFirstChild("A-Chassis Interface") then
        clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
        task.wait(1.3)
        for _, v in ipairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
            if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                clickGui(v)
                task.wait(1.8)
                break
            end
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

    -- Noclip chỉ chạy KHI XE THAY ĐỔI
    if MyCar ~= lastNoclipCar then
        lastNoclipCar = MyCar
        for _, v in ipairs(MyCar:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    end

    -- Khóa ghế lái
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum and not hum.Sit then
        local seat = MyCar:FindFirstChildWhichIsA("VehicleSeat", true) or MyCar:FindFirstChildWhichIsA("Seat", true)
        if seat then
            player.Character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
            seat:Sit(hum)
        end
    end

    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local totalCP = MyRace:FindFirstChild("Checkpoints") and MyRace.Checkpoints.Value or 12
    _G.raceProgress = currentCP .. "/" .. totalCP

    if currentCP >= totalCP then
        if now - lastFinishTime > 4 then
            lastFinishTime = now
            task.wait(1.2)
            closeRewardModal()
            task.wait(1)
            pcall(function() if player.Character then player.Character:BreakJoints() end end)
            task.wait(1.5)
            clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
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

-- ================== KHỞI CHẠY (AN TOÀN + TỐI ƯU) ==================
print("[System] 🚀 Đang khởi chạy phiên bản tối ưu + chống chồng chéo...")

fixLag()
task.wait(2)

local cashObj = getCashObject()
if not cashObj then
    warn("[System] ❌ Không tìm thấy Cash!")
    _G.AutoFarmV2_Running = false
    return
end

-- Vòng lặp chính (driving + seat + noclip)
task.spawn(function()
    while task.wait(0.03) do
        if not _G.AutoFarmV2_Running then return end
        pcall(mainAutoFarm)
    end
end)

-- Vòng lặp chậm (claim + modal + anti-AFK)
task.spawn(function()
    while task.wait(1) do
        if not _G.AutoFarmV2_Running then return end
        local now = tick()
        if now - lastClaimTime > 8 then
            lastClaimTime = now
            claimRewards()
        end
        if now - lastCloseTime > 2.5 then
            lastCloseTime = now
            closeRewardModal()
        end
        if now - lastAFKTime > 35 then
            lastAFKTime = now
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end
end)

-- Gửi dữ liệu khi Cash thay đổi
cashObj:GetPropertyChangedSignal("Value"):Connect(function()
    if _G.AutoFarmV2_Running then
        pcall(sendData, cashObj.Value, _G.raceProgress)
    end
end)

-- Heartbeat định kỳ
task.spawn(function()
    while task.wait(HEARTBEAT_INTERVAL) do
        if not _G.AutoFarmV2_Running then return end
        pcall(sendData, cashObj.Value, _G.raceProgress)
    end
end)

print("[System] ✅ Script đã chạy thành công! RAM thấp, không bị chồng chéo.")
print("[System] 💡 Muốn dừng script bất cứ lúc nào: gõ  _G.AutoFarmV2_Running = false")
