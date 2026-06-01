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
local lastAFKTime = 0
local lastNoclipCar = nil
local raceStartTime = 0
local lastWatchdogPing = tick()

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

    if not gui:FindFirstChild("A-Chassis Interface") then
        clickGui(mainUI.UI_Frame.Buttons.Spawn)
        task.wait(1.3)
        for _, v in ipairs(mainUI.Garage.Container.Vehicles:GetChildren()) do
            if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                clickGui(v)
                task.wait(1.8)
                break
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
print("[System] 🚀 Đang chạy Full Script (Đã sửa GroupRewards)...")
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

task.spawn(function()
    while task.wait(30) do
        if not _G.AutoFarmV2_Running then return end
        pcall(function() collectgarbage("collect") end)
        if not player.PlayerGui:FindFirstChild("BlackScreenOptimizer") then enableBlackScreenAndLowGraphics() end
    end
end)

task.spawn(function()
    while task.wait(30) do
        if not _G.AutoFarmV2_Running then return end
        if tick() - lastWatchdogPing > 45 then
            warn("[Watchdog] Vòng lặp chính bị treo!")
            _G.AutoFarmV2_Running = false
            return
        end
    end
end)

-- ================== BOOST + GROUP REWARDS (ĐÃ SỬA) ==================
task.spawn(function()
    while task.wait(0.6) do
        if not _G.AutoFarmV2_Running then return end
        pcall(function()
            local gui = player.PlayerGui
            if not gui then return end

            local mainUI = gui:FindFirstChild("Main_User_Interface")
            if not mainUI then return end

            -- Bước 1: Click Rewards
            if mainUI:FindFirstChild("UI_Frame") and mainUI.UI_Frame:FindFirstChild("Bottom") then
                local rewardsBtn = mainUI.UI_Frame.Bottom:FindFirstChild("Rewards")
                if rewardsBtn then clickGui(rewardsBtn) end
            end

            task.wait(0.5)

            -- Bước 2: Click GroupRewards (ĐÚNG ĐƯỜNG DẪN TỪ LOG CỦA BẠN)
            if gui:FindFirstChild("Rewards") and gui.Rewards:FindFirstChild("Buttons") then
                local groupRewards = gui.Rewards.Buttons:FindFirstChild("GroupRewards")
                if groupRewards then
                    clickGui(groupRewards)
                    print("[Boost] Đã click GroupRewards")
                    task.wait(0.7)
                end
            end

            -- Bước 3: Click Use Boost (nếu có)
            if gui:FindFirstChild("RobuxShop") 
               and gui.RobuxShop:FindFirstChild("Menu") 
               and gui.RobuxShop.Menu:FindFirstChild("List") 
               and gui.RobuxShop.Menu.List:FindFirstChild("Boosts") 
               and gui.RobuxShop.Menu.List.Boosts:FindFirstChild("Boost") 
               and gui.RobuxShop.Menu.List.Boosts.Boost:FindFirstChild("Use") then
                
                local useBtn = gui.RobuxShop.Menu.List.Boosts.Boost.Use
                if useBtn.Visible == true then
                    clickGui(useBtn)
                    print("[Boost] ✅ Đã dùng Boost!")
                end
            end
        end)
    end
end)

print("[System] ✅ Script đã sửa xong! Bây giờ sẽ tự động qua GroupRewards.")
