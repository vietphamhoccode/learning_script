local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

while not player do task.wait(0.5); player = Players.LocalPlayer end

if _G.AutoFarmV2_Running then _G.AutoFarmV2_Running = false task.wait(2) end
if _G.AutoFarmV2_Connections then 
    for _, c in ipairs(_G.AutoFarmV2_Connections) do 
        pcall(function() c:Disconnect() end) 
    end 
end
_G.AutoFarmV2_Connections = {}
_G.AutoFarmV2_Running = true

local API_URL = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 10
_G.raceProgress = "N/A"

local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
local MyCar = nil
local MyRace = nil
local lastFinishTime = 0
local lastTeleportTime = 0
local lastUpdate = 0
local lastClaimTime = 0
local lastCloseTime = 0
local lastNoclipCar = nil
local lastWatchdogPing = tick()
local lastShopTime = 0       -- ✅ Thêm: kiểm soát shop
local lastCleanTime = 0      -- ✅ Thêm: dọn visuals định kỳ
local lastGCTime = 0         -- ✅ Thêm: garbage collect định kỳ

-- ================== GIỚI HẠN FPS (QUAN TRỌNG NHẤT) ==================
-- ✅ Giảm FPS xuống 45 để giảm CPU load khi multi-tab
pcall(function()
    if setfpscap then
        setfpscap(45)  -- Exploits hỗ trợ: Synapse, Fluxus...
    end
end)

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

        -- ✅ Tối ưu hơn bản gốc
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
        Lighting.Ambient = Color3.new(0, 0, 0)
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

        -- ✅ Thêm: tắt thêm hiệu ứng Lighting
        pcall(function()
            for _, fx in ipairs(Lighting:GetChildren()) do
                if fx:IsA("BlurEffect") or fx:IsA("ColorCorrectionEffect") 
                or fx:IsA("SunRaysEffect") or fx:IsA("BloomEffect")
                or fx:IsA("DepthOfFieldEffect") then
                    fx.Enabled = false
                end
            end
        end)
    end)
end

-- ✅ Fix: cleanVisuals chạy lặp lại để dọn objects mới spawn
local function cleanVisuals()
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") 
            or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Beam") then
                pcall(function() v.Enabled = false end)
            end
        end
        -- ✅ Thêm: tắt shadow và detail trên tất cả parts
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                pcall(function()
                    v.CastShadow = false
                    v.ReceiveAge = 0
                end)
            end
        end
    end)
end

-- ✅ Thêm: unload textures để tiết kiệm VRAM
local function optimizeTextures()
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Decal") or v:IsA("Texture") or v:IsA("SpecialMesh") then
                pcall(function() v.Transparency = 1 end)
            end
        end
    end)
end

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
        pcall(function()
            for _, v in ipairs(main.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
                if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then
                    clickGui(v.Button); task.wait(0.2)
                end
            end
        end)
        pcall(function()
            local dr = gui:FindFirstChild("DailyRewards")
            if dr and dr.Menu.Today.Claim.Label.Text ~= "Claimed" then clickGui(dr.Menu.Today.Claim) end
        end)
        pcall(function()
            local ch = gui:FindFirstChild("Challenges")
            if ch then
                for _, v in ipairs(ch.Menu.Challenges:GetChildren()) do
                    if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then clickGui(v.Action) end
                end
                pcall(function() clickGui(ch.Menu.Rewards.Claim) end)
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
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) 
                    and (btn.Text == "X" or btn.Text == "✕" or btn.Name:lower():find("close")) then
                        clickGui(btn); return
                    end
                end
            end
        end
    end)
end

-- ✅ Fix: Shop chỉ chạy mỗi 60 giây thay vì 0.8 giây
local function tryShopAndBoost()
    pcall(function()
        local gui = player.PlayerGui
        if not gui then return end
        local mainUI = gui:FindFirstChild("Main_User_Interface")
        if not mainUI then return end

        local storeBtn = mainUI:FindFirstChild("UI_Frame") 
            and mainUI.UI_Frame:FindFirstChild("Buttons") 
            and mainUI.UI_Frame.Buttons:FindFirstChild("Store")
        if storeBtn then clickGui(storeBtn); task.wait(0.5) end

        if gui:FindFirstChild("RobuxShop") and gui.RobuxShop:FindFirstChild("Menu") 
        and gui.RobuxShop.Menu:FindFirstChild("Categories") then
            local rewardsCat = gui.RobuxShop.Menu.Categories:FindFirstChild("Rewards")
            if rewardsCat then clickGui(rewardsCat); task.wait(0.4) end
        end

        if gui:FindFirstChild("RobuxShop") and gui.RobuxShop.Menu.List.Boosts.Boost.Use then
            local useBtn = gui.RobuxShop.Menu.List.Boosts.Boost.Use
            if useBtn.Visible then
                clickGui(useBtn)
                print("[Boost] ✅ Đã dùng Boost!")
            end
        end

        if gui:FindFirstChild("RobuxShop") and gui.RobuxShop.Menu.List.Rewards.Codes then
            local redeem = gui.RobuxShop.Menu.List.Rewards.Codes:FindFirstChild("Redeem")
            if redeem then
                gui.RobuxShop.Menu.List.Rewards.Codes.Input.Text = "ThanksFor810k"
                task.wait(0.2)
                clickGui(redeem)
            end
        end
    end)
end

-- ================== MAIN AUTO FARM ==================
-- ✅ Fix: tăng interval từ 0.028s lên 0.05s (20 FPS logic thay vì 35 FPS)
local FARM_INTERVAL = 0.05

local function mainAutoFarm()
    if not _G.AutoFarmV2_Running then return end
    lastWatchdogPing = tick()
    local gui = player.PlayerGui
    if not gui then return end
    local now = tick()

    if gui:FindFirstChild("LoadingScreen") then
        clickGui(gui.LoadingScreen.Center.Frame.Play.Button)
        task.wait(1); return
    end

    if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled then
        clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
        task.wait(0.5)
        clickGui(gui.StarterPick.Menu.Buttons.Confirm)
        task.wait(0.8); return
    end

    local mainUI = gui:FindFirstChild("Main_User_Interface")
    if not mainUI then return end

    if not gui:FindFirstChild("A-Chassis Interface") then
        clickGui(mainUI.UI_Frame.Buttons.Spawn)
        task.wait(1.3)
        for _, v in ipairs(mainUI.Garage.Container.Vehicles:GetChildren()) do
            if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                clickGui(v); task.wait(1.8); break
            end
        end
        return
    end

    if not gui:FindFirstChild("Races") or not gui.Races.Container.Visible then
        if now - lastTeleportTime > 6 then
            lastTeleportTime = now
            clickGui(mainUI.Teleport.Container.Races.Race8.Container.Teleport)
            task.wait(2.5)
        end
        return
    end

    MyRace = nil
    for _, race in ipairs(workspace.Races:GetDescendants()) do
        if race:FindFirstChild("Racers") and race.Racers:FindFirstChild(player.Name) then
            MyRace = race; break
        end
    end
    if not MyRace then return end

    local racer = MyRace.Racers:FindFirstChild(player.Name)
    if not racer then return end
    MyCar = racer.Vehicle.Value
    if not MyCar or not MyCar.PrimaryPart then return end

    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local totalCP = MyRace:FindFirstChild("Checkpoints") and MyRace.Checkpoints.Value or 12
    _G.raceProgress = currentCP .. "/" .. totalCP

    if MyCar ~= lastNoclipCar then
        lastNoclipCar = MyCar
        for _, v in ipairs(MyCar:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
                v.CastShadow = false  -- ✅ Thêm: tắt shadow của xe
            end
        end
    end

    if currentCP >= totalCP then
        if now - lastFinishTime > 4 then
            lastFinishTime = now
            closeRewardModal()
            task.wait(0.8)
            clickGui(mainUI.Teleport.Container.Races.Race8.Container.Teleport)
        end
        return
    end

    if now - lastUpdate < FARM_INTERVAL then return end
    lastUpdate = now

    local hrp = MyCar.PrimaryPart
    local nextCPNum = currentCP + 1
    local cpName = (nextCPNum >= totalCP) and "Finish" or tostring(nextCPNum)
    local checkpointPart = MyRace:FindFirstChild(cpName, true) or MyRace:FindFirstChild("Finish", true)

    if checkpointPart then
        local targetPos = checkpointPart.Position + Vector3.new(0, 5, 0) + (hrp.CFrame.LookVector * 22)
        local dist = (targetPos - hrp.Position).Magnitude
        local speed = 1480
        if dist < 45 then speed = 1820 end
        if cpName == "Finish" or nextCPNum >= totalCP - 2 then speed = 2280 end
        hrp.AssemblyLinearVelocity = (targetPos - hrp.Position).Unit * speed + Vector3.new(0, 35, 0)
        hrp:PivotTo(hrp.CFrame:Lerp(CFrame.lookAt(hrp.Position, targetPos), 0.95))
    end
end

-- ================== KHỞI CHẠY ==================
print("[System] 🚀 Script Tối Ưu FPS đang khởi động...")
enableBlackScreenAndLowGraphics()
cleanVisuals()
optimizeTextures()  -- ✅ Thêm lần đầu
task.wait(2)

local cashObj = getCashObject()
if not cashObj then
    warn("[System] ❌ Không tìm thấy Cash!")
    _G.AutoFarmV2_Running = false
    return
end

local cashConn = cashObj:GetPropertyChangedSignal("Value"):Connect(function()
    if _G.AutoFarmV2_Running then pcall(sendData, cashObj.Value, _G.raceProgress) end
end)
table.insert(_G.AutoFarmV2_Connections, cashConn)

-- ✅ Loop chính: tốc độ đủ dùng, không waste CPU
task.spawn(function()
    while task.wait(FARM_INTERVAL) do
        if _G.AutoFarmV2_Running then pcall(mainAutoFarm) end
    end
end)

-- ✅ Gộp tất cả tác vụ phụ vào 1 loop duy nhất (thay vì 5 spawn riêng)
task.spawn(function()
    while task.wait(1) do
        if not _G.AutoFarmV2_Running then return end
        local now = tick()

        -- Claim & Close
        if now - lastClaimTime > 8 then lastClaimTime = now; claimRewards() end
        if now - lastCloseTime > 2.5 then lastCloseTime = now; closeRewardModal() end

        -- ✅ Shop/Boost: mỗi 60s thay vì 0.8s
        if now - lastShopTime > 60 then lastShopTime = now; tryShopAndBoost() end

        -- ✅ Heartbeat API
        if now - lastUpdate > HEARTBEAT_INTERVAL then
            if not cashObj or not cashObj.Parent then cashObj = getCashObject() end
            pcall(sendData, cashObj and cashObj.Value or 0, _G.raceProgress)
        end

        -- ✅ Clean visuals định kỳ mỗi 45s (bắt objects mới spawn)
        if now - lastCleanTime > 45 then
            lastCleanTime = now
            cleanVisuals()
            optimizeTextures()
        end

        -- ✅ GC mỗi 30s
        if now - lastGCTime > 30 then
            lastGCTime = now
            pcall(function() collectgarbage("collect") end)
        end

        -- Watchdog
        if tick() - lastWatchdogPing > 45 then
            warn("[Watchdog] Vòng lặp chính bị treo!")
            _G.AutoFarmV2_Running = false
            return
        end

        -- Black screen check mỗi 30s
        if now % 30 < 1 then
            if not player.PlayerGui:FindFirstChild("BlackScreenOptimizer") then
                enableBlackScreenAndLowGraphics()
            end
        end
    end
end)

-- ✅ Anti-AFK: giữ nguyên nhưng tăng interval lên 20s
task.spawn(function()
    print("[Anti-AFK] 🚀 Đã kích hoạt")
    while task.wait(20) do
        if not _G.AutoFarmV2_Running then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(math.random(0, 100), math.random(0, 100)))
            local camera = workspace.CurrentCamera
            if camera then
                camera.CFrame = camera.CFrame * CFrame.Angles(0, math.rad(math.random(-8, 8)), 0)
            end
            local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space}
            VirtualUser:SendKeyEvent(true, keys[math.random(1, #keys)], false, game)
            task.wait(0.1)
            VirtualUser:SendKeyEvent(false, keys[math.random(1, #keys)], false, game)
        end)
    end
end)

print("[System] ✅ Script tối ưu FPS đã sẵn sàng!")
