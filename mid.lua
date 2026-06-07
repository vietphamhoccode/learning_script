local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

while not player do task.wait(0.5); player = Players.LocalPlayer end

if _G.AutoFarmV2_Running then _G.AutoFarmV2_Running = false task.wait(2) end
if _G.AutoFarmV2_Connections then for _, c in ipairs(_G.AutoFarmV2_Connections) do pcall(function() c:Disconnect() end) end end
_G.AutoFarmV2_Connections = {}
_G.AutoFarmV2_Running = true

local API_URL = "https://keywave.site/api.php"
local HEARTBEAT_INTERVAL = 1
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
local lastBoostTime = 0  -- <<<<< THÊM CHO BOOST 15 PHÚT

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
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
        Lighting.Ambient = Color3.new(0, 0, 0)
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
end

local _visualsCleaned = false
local function cleanVisuals()
    if _visualsCleaned then return end
    _visualsCleaned = true
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Beam") then
                pcall(function() v.Enabled = false end)
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
            if modal.Name:find("Reward") or modal.Name:find("Result") or modal.Name:find("Complete") or modal.Name:find("Finish") then
                for _, btn in ipairs(modal:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and (btn.Text == "X" or btn.Text == "✕" or btn.Name:lower():find("close")) then
                        clickGui(btn); return
                    end
                end
            end
        end
    end)
end

-- ================== MAIN AUTO FARM ==================
local function mainAutoFarm()
    if not _G.AutoFarmV2_Running then return end
    lastWatchdogPing = tick()
    local gui = player.PlayerGui
    if not gui then return end
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

    local mainUI = gui:FindFirstChild("Main_User_Interface")
    if not mainUI then return end

    -- ================== FIX MỞ XE LIÊN TỤC ==================
    local hasChassis = gui:FindFirstChild("A-Chassis Interface")
    local hasCarInWorkspace = workspace:FindFirstChild(player.Name) and workspace[player.Name]:FindFirstChildOfClass("Model") 

    if not hasChassis and (not hasCarInWorkspace or tick() - lastTeleportTime > 12) then
        if now - lastTeleportTime > 8 then  -- cooldown mạnh hơn
            lastTeleportTime = now
            clickGui(mainUI.UI_Frame.Buttons.Spawn)
            task.wait(2.5)  -- chờ lâu hơn
            
            -- Chọn xe trong garage
            local garage = mainUI:FindFirstChild("Garage")
            if garage and garage.Container then
                for _, v in ipairs(garage.Container.Vehicles:GetChildren()) do
                    if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                        clickGui(v)
                        task.wait(2)
                        break
                    end
                end
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
            MyRace = race
            break
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
            if v:IsA("BasePart") then v.CanCollide = false end 
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

    if now - lastUpdate < 0.028 then return end
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
print("[System] 🚀 Full Script (Đầy đủ + Mở Shop + Boost 15p + Anti-AFK) đang chạy...")
enableBlackScreenAndLowGraphics()
cleanVisuals()
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

task.spawn(function()
    while task.wait(0.03) do if _G.AutoFarmV2_Running then pcall(mainAutoFarm) end end
end)

task.spawn(function()
    while task.wait(1) do
        if not _G.AutoFarmV2_Running then return end
        local now = tick()
        if now - lastClaimTime > 8 then lastClaimTime = now; claimRewards() end
        if now - lastCloseTime > 2.5 then lastCloseTime = now; closeRewardModal() end
    end
end)

task.spawn(function()
    while task.wait(HEARTBEAT_INTERVAL) do
        if not _G.AutoFarmV2_Running then return end
        if not cashObj or not cashObj.Parent then cashObj = getCashObject() end
        pcall(sendData, cashObj and cashObj.Value or 0, _G.raceProgress)
    end
end)

-- ================== MỞ SHOP + DÙNG BOOST (15 PHÚT/LẦN) ==================
task.spawn(function()
    while task.wait(45) do  -- kiểm tra shop thường xuyên hơn
        if not _G.AutoFarmV2_Running then return end
        pcall(function()
            local gui = player.PlayerGui
            if not gui then return end
            local mainUI = gui:FindFirstChild("Main_User_Interface")
            if not mainUI then return end

            local robuxShop = gui:FindFirstChild("RobuxShop")
            local now = tick()

            -- Mở shop
            if not robuxShop or not robuxShop.Enabled then
                local storeBtn = mainUI.UI_Frame and mainUI.UI_Frame.Buttons and mainUI.UI_Frame.Buttons.Store
                if storeBtn then
                    clickGui(storeBtn)
                    task.wait(1)
                end
            end

            robuxShop = gui:FindFirstChild("RobuxShop")
            if robuxShop and robuxShop.Enabled then
                -- Chọn Rewards
                if robuxShop.Menu and robuxShop.Menu.Categories then
                    local rewardsCat = robuxShop.Menu.Categories:FindFirstChild("Rewards")
                    if rewardsCat then clickGui(rewardsCat); task.wait(0.5) end
                end

                -- DÙNG BOOST (chỉ mỗi 15 phút)
                if now - lastBoostTime > 900 then  -- 15 phút
                    local boostUse = robuxShop.Menu.List.Boosts.Boost.Use
                    if boostUse and boostUse.Visible then
                        clickGui(boostUse)
                        lastBoostTime = now
                        print("[Boost] ✅ Đã dùng Boost! (15 phút lần sau)")
                        task.wait(1)
                    end
                end

                -- Redeem Code
                if robuxShop.Menu.List.Rewards.Codes then
                    local redeem = robuxShop.Menu.List.Rewards.Codes.Redeem
                    if redeem then
                        robuxShop.Menu.List.Rewards.Codes.Input.Text = "ThanksFor810k"
                        task.wait(0.2)
                        clickGui(redeem)
                        task.wait(0.6)
                    end
                end

                -- Đóng shop
                for _, btn in ipairs(robuxShop:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and (btn.Text == "X" or btn.Text == "✕" or btn.Name:lower():find("close")) then
                        clickGui(btn)
                        break
                    end
                end
            end
        end)
    end
end)

-- ================== ANTI-AFK + AUTO YES ==================
task.spawn(function()
    print("[Anti-AFK] 🚀 Phiên bản chống kick mạnh đã kích hoạt")
    while task.wait(15) do
        if not _G.AutoFarmV2_Running then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(math.random(0, 100), math.random(0, 100)))
            
            local camera = workspace.CurrentCamera
            if camera then camera.CFrame = camera.CFrame * CFrame.Angles(0, math.rad(math.random(-8,8)), 0) end

            local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space}
            local key = keys[math.random(1,#keys)]
            VirtualUser:SendKeyEvent(true, key, false, game)
            task.wait(0.1)
            VirtualUser:SendKeyEvent(false, key, false, game)
        end)
    end
end)

task.spawn(function()
    while task.wait(2) do
        if not _G.AutoFarmV2_Running then return end
        pcall(function()
            local function checkAndClick(root)
                if not root then return end
                for _, label in ipairs(root:GetDescendants()) do
                    if label:IsA("TextLabel") then
                        local txt = label.Text:lower()
                        if txt:find("yêu thích") or txt:find("favorite") then
                            for _, btn in ipairs(label.Parent:GetDescendants()) do
                                if btn:IsA("TextButton") then
                                    local btxt = btn.Text:lower()
                                    if btxt:find("có") or btxt:find("yes") then
                                        clickGui(btn)
                                        print("[System] ✅ Đã tự động nhấn Có/Yes")
                                        return true
                                    end
                                end
                            end
                        end
                    end
                end
                return false
            end
            checkAndClick(player.PlayerGui)
            checkAndClick(game:GetService("CoreGui"))
        end)
    end
end)

print("[System] ✅ Script đã được fix! Không spam mở xe + Boost 15 phút/lần.")
