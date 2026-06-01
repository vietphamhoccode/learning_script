local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
while not player do task.wait(0.5); player = Players.LocalPlayer end

-- ================== STOP INSTANCE CŨ ==================
if _G.AutoFarmV2_Running then
    _G.AutoFarmV2_Running = false
    task.wait(2)
end
if _G.AutoFarmV2_Connections then
    for _, c in ipairs(_G.AutoFarmV2_Connections) do
        pcall(function() c:Disconnect() end)
    end
end
_G.AutoFarmV2_Connections = {}
_G.AutoFarmV2_Running = true

local API_URL = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 10  -- [FIX] Tăng từ 3s lên 10s, giảm HTTP spam
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
local lastWatchdogPing = tick()

-- ================== [v4.2] CACHE SCAN - Không scan workspace lặp lại ==================
local _cachedDescendants = nil
local _cacheTime = 0
local CACHE_TTL = 60  -- Cache 60s, không scan lại mỗi 10s

local function getWorkspaceDescendants()
    local now = tick()
    if not _cachedDescendants or (now - _cacheTime) > CACHE_TTL then
        _cachedDescendants = workspace:GetDescendants()
        _cacheTime = now
    end
    return _cachedDescendants
end

-- ================== BLACK SCREEN + TỐI ƯU ĐỒ HỌA ==================
local function enableBlackScreenAndLowGraphics()
    pcall(function()
        local existingBs = player.PlayerGui:FindFirstChild("BlackScreenOptimizer")
        if existingBs then existingBs:Destroy() end
        local sg = Instance.new("ScreenGui")
        sg.Name = "BlackScreenOptimizer"
        sg.IgnoreGuiInset = true
        sg.ResetOnSpawn = false
        sg.Parent = player:WaitForChild("PlayerGui")
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BorderSizePixel = 0
        frame.Parent = sg
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
        Lighting.Ambient = Color3.new(0, 0, 0)
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    end)
end

-- ================== [v4.2] RAM CLEAN - Bỏ GC block, dùng 1 lần GC nhẹ ==================
local function aggressiveRamClean()
    pcall(function()
        -- [FIX] Chỉ 1 lần GC, không x3 — tránh block main thread 200-600ms
        collectgarbage("collect")

        -- [FIX] Dùng cache thay vì GetDescendants() mới mỗi lần
        for _, v in ipairs(getWorkspaceDescendants()) do
            if v:IsA("Sound") then
                pcall(function()
                    v.Volume = 0
                    v:Stop()
                end)
            end
        end

        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        end)

        if not player.PlayerGui:FindFirstChild("BlackScreenOptimizer") then
            enableBlackScreenAndLowGraphics()
        end
    end)
end

-- ================== [v4.2] CLEAN VISUALS - Chỉ chạy 1 lần lúc khởi động ==================
-- [FIX] Không gọi lại mỗi 30s nữa. Particle/beam không tự bật lại được.
local _visualsCleaned = false
local function cleanVisuals()
    if _visualsCleaned then return end  -- Chỉ chạy 1 lần duy nhất
    _visualsCleaned = true
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke")
               or v:IsA("Fire") or v:IsA("Sparkles") then
                pcall(function() v.Enabled = false end)
            end
            if v:IsA("Beam") then
                pcall(function() v.Enabled = false end)
            end
            if v:IsA("BillboardGui") and v.Parent ~= player.Character then
                pcall(function() v.Enabled = false end)
            end
        end
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect")
               or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
                pcall(function() v.Enabled = false end)
            end
        end
    end)
    -- Sau khi clean xong, cache lại descendants để các hàm khác dùng
    _cachedDescendants = workspace:GetDescendants()
    _cacheTime = tick()
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

-- [FIX] Throttle sendData: không gửi nếu cash không thay đổi
local _lastSentCash = -1
local function sendData(cashValue, raceProgress)
    if not http_request then return end
    if cashValue == _lastSentCash and raceProgress == _G.raceProgress then return end
    _lastSentCash = cashValue
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
        if not _G.AutoFarmV2_Running then return nil end
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
        if not gui then return end
        local main = gui:FindFirstChild("Main_User_Interface")
        if not main then return end

        -- 1. Playtime Rewards
        pcall(function()
            for _, v in ipairs(main.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
                if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then
                    clickGui(v.Button)
                    task.wait(0.2)
                end
            end
        end)

        -- 2. Daily Rewards
        pcall(function()
            local dr = gui:FindFirstChild("DailyRewards")
            if dr and dr.Menu.Today.Claim.Label.Text ~= "Claimed" then
                clickGui(dr.Menu.Today.Claim)
            end
        end)

        -- 3. Challenges
        pcall(function()
            local ch = gui:FindFirstChild("Challenges")
            if not ch then return end
            for _, v in ipairs(ch.Menu.Challenges:GetChildren()) do
                if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then
                    clickGui(v.Action)
                end
            end
            pcall(function() clickGui(ch.Menu.Rewards.Claim) end)
        end)

        -- 4. Redeem Code
        pcall(function()
            local shop = gui:FindFirstChild("RobuxShop")
            if not shop then return end
            for _, code in ipairs({"ThanksFor810k"}) do
                shop.Menu.List.Rewards.Codes.Input.Text = code
                task.wait(0.2)
                clickGui(shop.Menu.List.Rewards.Codes.Redeem)
            end
        end)

        -- 5. USE BOOST (TÍCH HỢP TỪ SCRIPT CŨ)
        pcall(function()
            local robuxShop = gui:FindFirstChild("RobuxShop")
            if robuxShop and robuxShop:FindFirstChild("Menu") then
                local boosts = robuxShop.Menu:FindFirstChild("List") and robuxShop.Menu.List:FindFirstChild("Boosts")
                if boosts and boosts:FindFirstChild("Boost") then
                    local useBtn = boosts.Boost:FindFirstChild("Use")
                    if useBtn and useBtn.Visible == true then
                        clickGui(useBtn)
                        print("[Boost] ✅ Đã sử dụng Boost!")
                    end
                end
            end
        end)
    end)
end

local function closeRewardModal()
    pcall(function()
        local gui = player.PlayerGui
        if not gui then return end
        for _, modal in ipairs(gui:GetDescendants()) do
            if modal.Name:find("Reward") or modal.Name:find("Result")
               or modal.Name:find("Complete") or modal.Name:find("Finish") then
                for _, btn in ipairs(modal:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and
                       (btn.Text == "X" or btn.Text == "✕"
                        or btn.Name:lower():find("close") or btn.Name:lower():find("exit")) then
                        clickGui(btn); return
                    end
                end
            end
        end
    end)
end

local function mainAutoFarm()
    if not _G.AutoFarmV2_Running then return end
    lastWatchdogPing = tick()

    local gui = player.PlayerGui
    if not gui then return end
    local now = tick()

    local loadScreen = gui:FindFirstChild("LoadingScreen")
    if loadScreen then
        clickGui(loadScreen.Center and loadScreen.Center.Frame and loadScreen.Center.Frame.Play and loadScreen.Center.Frame.Play.Button)
        task.wait(1); return
    end

    local starterPick = gui:FindFirstChild("StarterPick")
    if starterPick and starterPick.Enabled then
        pcall(function()
            clickGui(starterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
            task.wait(0.5)
            clickGui(starterPick.Menu.Buttons.Confirm)
        end)
        task.wait(0.8); return
    end

    local mainUI = gui:FindFirstChild("Main_User_Interface")
    if not mainUI then return end

    if not gui:FindFirstChild("A-Chassis Interface") then
        pcall(function()
            clickGui(mainUI.UI_Frame.Buttons.Spawn)
            task.wait(1.3)
            for _, v in ipairs(mainUI.Garage.Container.Vehicles:GetChildren()) do
                if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                    clickGui(v); task.wait(1.8); break
                end
            end
        end)
        return
    end

    local racesUI = gui:FindFirstChild("Races")
    if not racesUI or not racesUI.Container.Visible then
        if now - lastTeleportTime > 6 then
            lastTeleportTime = now
            pcall(function()
                clickGui(mainUI.Teleport.Container.Races.Race8.Container.Teleport)
            end)
            task.wait(2.5)
        end
        return
    end

    MyRace = nil
    local racesFolder = workspace:FindFirstChild("Races")
    if not racesFolder then return end
    for _, race in ipairs(racesFolder:GetDescendants()) do
        if race:FindFirstChild("Racers") and race.Racers:FindFirstChild(player.Name) then
            MyRace = race; break
        end
    end
    if not MyRace then return end

    local racer = MyRace.Racers:FindFirstChild(player.Name)
    if not racer then return end

    MyCar = racer:FindFirstChild("Vehicle") and racer.Vehicle.Value
    if not MyCar or not MyCar.PrimaryPart then return end

    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local totalCP = (MyRace:FindFirstChild("Checkpoints") and MyRace.Checkpoints.Value) or 12
    _G.raceProgress = currentCP .. "/" .. totalCP

    if MyCar ~= lastNoclipCar then
        lastNoclipCar = MyCar
        for _, v in ipairs(MyCar:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end

    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum and not hum.Sit then
        pcall(function()
            local seat = MyCar:FindFirstChildWhichIsA("VehicleSeat", true) or MyCar:FindFirstChildWhichIsA("Seat", true)
            if seat then
                player.Character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
                seat:Sit(hum)
            end
        end)
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
            pcall(function()
                clickGui(mainUI.Teleport.Container.Races.Race8.Container.Teleport)
            end)
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

-- ================== KHỞI CHẠY ==================
print("[System] 🚀 v4.2 - FPS Optimized đang khởi chạy...")
enableBlackScreenAndLowGraphics()
cleanVisuals()  -- Chỉ chạy 1 lần duy nhất
task.wait(2)

-- [FIX] Delay khởi động ngẫu nhiên 0-5s cho acc join sau (tránh HTTP spam đồng thời)
do
    local jitter = math.random() * 5
    print("[System] ⏳ Anti-throttle jitter: " .. string.format("%.1f", jitter) .. "s")
    task.wait(jitter)
end

local cashObj = getCashObject()
if not cashObj then
    warn("[System] ❌ Không tìm thấy Cash!")
    _G.AutoFarmV2_Running = false
    return
end

-- [FIX] Debounce cash signal: chỉ gửi HTTP khi cash thực sự thay đổi (không spam)
local cashConn = cashObj:GetPropertyChangedSignal("Value"):Connect(function()
    if _G.AutoFarmV2_Running then
        pcall(sendData, cashObj.Value, _G.raceProgress)
        print("[Cash] 💰 " .. cashObj.Value .. " Cash")
    end
end)
table.insert(_G.AutoFarmV2_Connections, cashConn)

-- ================== VÒNG LẶP CHÍNH ==================
task.spawn(function()
    while task.wait(0.03) do
        if not _G.AutoFarmV2_Running then return end
        pcall(mainAutoFarm)
    end
end)

-- ================== VÒNG LẶP PHỤ: Claim + AFK + Đóng modal ==================
task.spawn(function()
    while task.wait(1) do
        if not _G.AutoFarmV2_Running then return end
        local now = tick()
        if now - lastClaimTime > 8 then lastClaimTime = now; claimRewards() end
        if now - lastCloseTime > 2.5 then lastCloseTime = now; closeRewardModal() end
        if now - lastAFKTime > 20 then
            lastAFKTime = now
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end
end)

-- ================== HEARTBEAT GỬI DATA ==================
task.spawn(function()
    while task.wait(HEARTBEAT_INTERVAL) do  -- 10s thay vì 3s
        if not _G.AutoFarmV2_Running then return end
        if not cashObj or not cashObj.Parent then
            cashObj = getCashObject()
        end
        pcall(sendData, cashObj and cashObj.Value or 0, _G.raceProgress)
    end
end)

-- ================== [v4.2] DỌN RAM NHẸ - Không block thread ==================
task.spawn(function()
    local cleanCount = 0
    while task.wait(30) do  -- [FIX] Tăng từ 10s lên 30s
        if not _G.AutoFarmV2_Running then return end
        cleanCount = cleanCount + 1

        -- [FIX] 1 lần GC nhẹ, không x3
        pcall(function() collectgarbage("collect") end)

        -- Mute âm thanh từ cache, không scan lại
        pcall(function()
            for _, v in ipairs(getWorkspaceDescendants()) do
                if v:IsA("Sound") and v.Volume > 0 then
                    pcall(function() v.Volume = 0; v:Stop() end)
                end
            end
        end)

        -- Lighting reset mỗi 90s (3 × 30s)
        if cleanCount % 3 == 0 then
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
                Lighting.Brightness = 0
                Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
                Lighting.Ambient = Color3.new(0, 0, 0)
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            print("[RAM] 🧹 Dọn RAM lần " .. cleanCount)
        end

        if not player.PlayerGui:FindFirstChild("BlackScreenOptimizer") then
            enableBlackScreenAndLowGraphics()
        end
    end
end)

-- ================== WATCHDOG ==================
task.spawn(function()
    while task.wait(30) do
        if not _G.AutoFarmV2_Running then return end
        if tick() - lastWatchdogPing > 45 then
            warn("[Watchdog] ⚠️ Vòng lặp chính bị treo! Hãy paste lại script!")
            _G.AutoFarmV2_Running = false
            return
        end
    end
end)

print("[System] ✅ v4.2 chạy thành công! FPS optimized.")
