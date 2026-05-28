local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

while not player do
    task.wait(0.5)
    player = Players.LocalPlayer
end

-- ── CẤU HÌNH ────────────────────────────────────────────────
local API_URL = "https://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 1
local loaded = false
local lastCash = nil
local codes = _G.codes or {"ThanksFor810k"}

local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- Biến chờ thông minh + race progress
_G.waitTime = 2
_G.maxWaitTime = 90
_G.raceProgress = "N/A"

-- THÊM BIẾN CHO AUTO RACE
local RACE_WAIT_TIME = 60 -- 1 phút đếm ngược đm
local waitingForPlayers = false
local raceStartTime = nil

-- THÊM BIẾN CHO RACE SOLO
local raceSoloAttempted = false
local lastTeleportTime = 0

-- ══════════════════════════════════════════════════════════════
-- PHẦN 1-4: GIỮ NGUYÊN
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
    print("[System] ✅ Game đã load hoàn thiện!")
end

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

local function sendData(cashValue)
    if not http_request then return false end
    local payload = HttpService:JSONEncode({
        username = player.Name,
        user_id = player.UserId,
        cash = cashValue,
        race_progress = _G.raceProgress or "N/A",
        place_id = game.PlaceId,
        server_id = game.JobId
    })
    local success, result = pcall(function()
        local res = http_request({Url = API_URL, Method = "POST",
            Headers = {["Content-Type"] = "application/json"}, Body = payload})
        if res and res.StatusCode == 200 then
            return HttpService:JSONDecode(res.Body).status == "ok"
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
-- PHẦN 5: BAY THẤP 5 + GIẢ LẬP DI CHUYỂN + GỬI CHECKPOINT + AUTO RACE SOLO
-- ══════════════════════════════════════════════════════════════
local function findMyRace()
    for _, v in pairs(workspace.Races.Race8.Races:GetChildren()) do
        if v.Racers:FindFirstChild(player.Name) then return v end
    end
end

-- HÀM TÌM VÀ ẤN NÚT RACE SOLO (CHỈ TÌM NÚT CÓ TEXT "SOLO")
local function findAndClickRaceSolo()
    local gui = player.PlayerGui
    if not gui:FindFirstChild("Main_User_Interface") then return false end
    
    -- Tìm nút RACE SOLO trong teleport menu (khu vực race8)
    local teleportContainer = gui.Main_User_Interface.Teleport.Container
    if teleportContainer and teleportContainer:FindFirstChild("Races") then
        local race8Container = teleportContainer.Races:FindFirstChild("Race8")
        if race8Container and race8Container:FindFirstChild("Container") then
            for _, btn in pairs(race8Container.Container:GetChildren()) do
                if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                    local btnText = btn:FindFirstChild("TextLabel") and btn.TextLabel.Text or btn.Text or ""
                    if btnText:upper():find("SOLO") or btn.Name:upper():find("SOLO") then
                        clickGui(btn)
                        print("[System] Đm, đã ấn nút RACE SOLO tại teleport race8")
                        return true
                    end
                end
            end
        end
    end
    
    -- Tìm nút RACE SOLO trong khu vực đang đứng
    local currentGui = gui:FindFirstChild("Races")
    if currentGui and currentGui:FindFirstChild("Container") then
        local raceContainer = currentGui.Container
        for _, btn in pairs(raceContainer:GetChildren()) do
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                local btnText = btn:FindFirstChild("TextLabel") and btn.TextLabel.Text or btn.Text or ""
                if btnText:upper():find("SOLO") or btn.Name:upper():find("SOLO") then
                    clickGui(btn)
                    print("[System] Đm, đã ấn nút RACE SOLO tại vị trí đứng")
                    return true
                end
            end
        end
    end
    
    return false
end

-- HÀM TỰ ĐỘNG ẤN NÚT RACE SOLO (ĐÃ XÓA NÚT RACE THƯỜNG)
local function autoJoinRace()
    local gui = player.PlayerGui
    if gui.Races.Container.Visible then
        for _, btn in pairs(gui.Races.Container:GetChildren()) do
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                local btnText = btn:FindFirstChild("TextLabel") and btn.TextLabel.Text or btn.Text or ""
                if btnText:upper():find("SOLO") or btn.Name:upper():find("SOLO") then
                    clickGui(btn)
                    print("[System] Đm, đã ấn nút RACE SOLO")
                    return true
                end
            end
        end
    end
    return false
end

-- HÀM ĐẾM SỐ NGƯỜI CHƠI
local function getPlayerCount()
    return #Players:GetPlayers()
end

-- HÀM XỬ LÝ CHỜ RACE 1 PHÚT
local function handleRaceWaiting()
    local gui = player.PlayerGui
    if not gui:FindFirstChild("Races") then return end
    
    local raceContainer = gui.Races.Container
    if not raceContainer or not raceContainer.Visible then return end
    
    if waitingForPlayers then
        if raceStartTime and (tick() - raceStartTime) >= RACE_WAIT_TIME then
            print("[System] Đm, 1 phút trôi qua đéo ai vào, tự động bắt đầu race solo!")
            autoJoinRace()
            waitingForPlayers = false
            raceStartTime = nil
        else
            local remaining = RACE_WAIT_TIME - (tick() - raceStartTime)
            if remaining > 0 then
                print(string.format("[System] Chờ %d giây nữa đéo thấy thằng nào thì auto race solo", remaining))
            end
        end
        return
    end
    
    local raceLobby = raceContainer:FindFirstChild("RaceLobby")
    if raceLobby and raceLobby.Visible then
        local playerCount = getPlayerCount()
        if playerCount <= 1 then
            if not waitingForPlayers then
                waitingForPlayers = true
                raceStartTime = tick()
                print("[System] Đm, chỉ có một mình, bắt đầu đếm 1 phút chờ thằng khác")
            end
        else
            if waitingForPlayers then
                waitingForPlayers = false
                raceStartTime = nil
                print("[System] Đm, có thằng khác vào rồi, hủy đếm chờ")
            end
        end
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
        lastTeleportTime = tick()
        task.wait(1.5)
        
        local raceSoloClicked = findAndClickRaceSolo()
        if raceSoloClicked then
            print("[System] Đm, đã ấn RACE SOLO sau khi teleport")
            raceSoloAttempted = true
            task.wait(1)
        end
        return
    end

    if gui.Races.Container.Visible and not raceSoloAttempted then
        local clicked = findAndClickRaceSolo()
        if clicked then
            raceSoloAttempted = true
            print("[System] Đm, đã ấn RACE SOLO trong menu race")
            task.wait(1)
        end
    end

    handleRaceWaiting()

    local myRace = findMyRace()
    if not myRace then
        if _G.myCar and _G.myCar.PrimaryPart then
            _G.myCar.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        return
    end

    local racer = myRace.Racers:FindFirstChild(player.Name)
    if racer then
        local currentCP = racer:GetAttribute("Checkpoint") or 0
        local totalCP = myRace:FindFirstChild("Checkpoints") and myRace.Checkpoints.Value or 12
        if currentCP >= totalCP then
            raceSoloAttempted = false
        end
    end
    
    if not racer then return end

    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local nextCPNum = currentCP + 1

    local totalCP = myRace:FindFirstChild("Checkpoints") and myRace.Checkpoints.Value or 12
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

    local cpName = (nextCPNum >= checkpointsFolder.Value) and "Finish" or tostring(nextCPNum)
    local checkpointPart = checkpointsFolder:FindFirstChild(cpName)
    if not checkpointPart then return end

    local myCar = racer.Vehicle.Value
    _G.myCar = myCar
    _G.myRace = myRace
    _G.wasRace = true

    if myCar and myCar.PrimaryPart then
        _G.lastRaceUpdate = _G.lastRaceUpdate or 0
        if tick() - _G.lastRaceUpdate < 0.03 then return end
        _G.lastRaceUpdate = tick()

        local hrp = myCar.PrimaryPart
        local baseTarget = checkpointPart.Position

        local targetHeight = 5
        local ahead = hrp.CFrame.LookVector * 12
        local targetPos = baseTarget + Vector3.new(0, targetHeight, 0) + ahead

        local currentPos = hrp.Position
        local dist = (targetPos - currentPos).Magnitude
        local direction = (targetPos - currentPos).Unit

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

        if dist < 20 and cpName == "Finish" then
            hrp.AssemblyLinearVelocity = direction * 1750
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- PHẦN 6: VÒNG LẶP PHỤ
-- ══════════════════════════════════════════════════════════════
local function runSubLoops()
    task.spawn(function()
        while task.wait() do
            local gui = player.PlayerGui
            if gui:FindFirstChild("LoadingScreen") then return end

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
                if player.Character then
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    if hum and not hum.Sit and _G.myCar then
                        local seat = _G.myCar:FindFirstChildWhichIsA("VehicleSeat", true) or _G.myCar:FindFirstChildWhichIsA("Seat", true)
                        if seat and player.Character.PrimaryPart then
                            player.Character:PivotTo(seat.CFrame * CFrame.new(0, 1.8, 0))
                            task.wait(0.1)
                            if hum then hum.Sit = true end
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
                if gui.DailyRewards.Menu.Today.Claim.Label.Text ~= "Claimed" then clickGui(gui.DailyRewards.Menu.Today.Claim) end
            end)
            pcall(function()
                if gui.RobuxShop.Menu.List.Boosts.Boost.Use.Visible == true then clickGui(gui.RobuxShop.Menu.List.Boosts.Boost.Use) end
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
end

-- ══════════════════════════════════════════════════════════════
-- PHẦN 7: GUI CỨT VÃI - TỐI ƯU RAM + FPS
-- ══════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TiendatGptGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

local blackScreen = Instance.new("Frame")
blackScreen.Name = "BlackScreen"
blackScreen.Size = UDim2.new(1, 0, 1, 0)
blackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
blackScreen.BackgroundTransparency = 0.85
blackScreen.Visible = true
blackScreen.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 250)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
mainFrame.BackgroundTransparency = 0.4
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Color3.new(1, 0, 0)
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "TIENDATGPT - AUTO FARM SOLO"
title.TextColor3 = Color3.new(1, 0, 0)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.new(1, 0, 0, 30)
cashLabel.Position = UDim2.new(0, 0, 0, 35)
cashLabel.BackgroundTransparency = 1
cashLabel.Text = "TIỀN: 0"
cashLabel.TextColor3 = Color3.new(0, 1, 0)
cashLabel.TextSize = 14
cashLabel.Font = Enum.Font.Gotham
cashLabel.Parent = mainFrame

local cpLabel = Instance.new("TextLabel")
cpLabel.Size = UDim2.new(1, 0, 0, 30)
cpLabel.Position = UDim2.new(0, 0, 0, 70)
cpLabel.BackgroundTransparency = 1
cpLabel.Text = "ĐUA: N/A"
cpLabel.TextColor3 = Color3.new(1, 1, 0)
cpLabel.TextSize = 14
cpLabel.Font = Enum.Font.Gotham
cpLabel.Parent = mainFrame

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Size = UDim2.new(1, 0, 0, 30)
countdownLabel.Position = UDim2.new(0, 0, 0, 105)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Text = "CHỜ: 0s"
countdownLabel.TextColor3 = Color3.new(1, 0.5, 0)
countdownLabel.TextSize = 14
countdownLabel.Font = Enum.Font.Gotham
countdownLabel.Parent = mainFrame

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, 0, 0, 30)
fpsLabel.Position = UDim2.new(0, 0, 0, 140)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS: 0"
fpsLabel.TextColor3 = Color3.new(0, 1, 1)
fpsLabel.TextSize = 14
fpsLabel.Font = Enum.Font.Gotham
fpsLabel.Parent = mainFrame

local raceStatusLabel = Instance.new("TextLabel")
raceStatusLabel.Size = UDim2.new(1, 0, 0, 30)
raceStatusLabel.Position = UDim2.new(0, 0, 0, 175)
raceStatusLabel.BackgroundTransparency = 1
raceStatusLabel.Text = "TRẠNG THÁI: CHỜ"
raceStatusLabel.TextColor3 = Color3.new(1, 0, 1)
raceStatusLabel.TextSize = 12
raceStatusLabel.Font = Enum.Font.Gotham
raceStatusLabel.Parent = mainFrame

local toggleBlackBtn = Instance.new("TextButton")
toggleBlackBtn.Size = UDim2.new(0, 80, 0, 25)
toggleBlackBtn.Position = UDim2.new(0, 210, 0, 215)
toggleBlackBtn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
toggleBlackBtn.Text = "Tắt màn đen"
toggleBlackBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBlackBtn.TextSize = 11
toggleBlackBtn.Font = Enum.Font.Gotham
toggleBlackBtn.Parent = mainFrame

local blackScreenVisible = true
toggleBlackBtn.MouseButton1Click:Connect(function()
    blackScreenVisible = not blackScreenVisible
    blackScreen.Visible = blackScreenVisible
    toggleBlackBtn.Text = blackScreenVisible and "Tắt màn đen" or "Bật màn đen"
end)

local function optimizeRam()
    pcall(function()
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v:Destroy()
            elseif v:IsA("MeshPart") and v.Material == Enum.Material.Neon then
                v.Material = Enum.Material.SmoothPlastic
            end
        end
        
        for _, v in pairs(game:GetService("SoundService"):GetDescendants()) do
            if v:IsA("Sound") then
                v.Volume = 0
                v:Stop()
            end
        end
        
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        game:GetService("Workspace").StreamingEnabled = true
        game:GetService("Workspace").StreamingPauseMode = Enum.StreamingPauseMode.Voluntary
        
        print("[System] Đm, đã tối ưu RAM vãi cứt")
    end)
end

local lastTime = tick()
local frameCount = 0
local fps = 0

game:GetService("RunService").RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local currentTime = tick()
    if currentTime - lastTime >= 1 then
        fps = frameCount
        frameCount = 0
        lastTime = currentTime
        fpsLabel.Text = "FPS: " .. fps
    end
end)

local function updateGui()
    pcall(function()
        if cashObj then
            cashLabel.Text = "TIỀN: " .. string.format("%.0f", cashObj.Value)
        end
        
        cpLabel.Text = "ĐUA: " .. (_G.raceProgress or "N/A")
        
        if waitingForPlayers and raceStartTime then
            local remaining = math.max(0, RACE_WAIT_TIME - (tick() - raceStartTime))
            countdownLabel.Text = "CHỜ: " .. math.floor(remaining) .. "s"
            raceStatusLabel.Text = "TRẠNG THÁI: CHỜ " .. math.floor(remaining) .. "s"
            raceStatusLabel.TextColor3 = Color3.new(1, 0.5, 0)
        else
            local myRace = findMyRace()
            if myRace then
                raceStatusLabel.Text = "TRẠNG THÁI: ĐANG ĐUA SOLO"
                raceStatusLabel.TextColor3 = Color3.new(0, 1, 0)
                countdownLabel.Text = "CHỜ: 0s"
            else
                raceStatusLabel.Text = "TRẠNG THÁI: CHỜ RACE SOLO"
                raceStatusLabel.TextColor3 = Color3.new(1, 0, 0)
            end
        end
    end)
end

task.spawn(function()
    while task.wait(0.5) do
        updateGui()
    end
end)

task.spawn(function()
    while task.wait(30) do
        optimizeRam()
    end
end)

-- ══════════════════════════════════════════════════════════════
-- KHỞI CHẠY
-- ══════════════════════════════════════════════════════════════
optimizeRam()
fixLag()
waitForGameLoad()
print("[System] ✅ Đang tìm Cash...")

local cashObj = getCashObject()
if not cashObj then warn("[System] ❌ Không tìm thấy Cash!") return end
print("[System] ✅ Đã tìm thấy Cash: " .. tostring(cashObj.Value))

local firstSend = sendData(cashObj.Value)
print(firstSend and "[System] ✅ Gửi API lần đầu thành công!" or "[System] ⚠️ Gửi API lần đầu thất bại")

loaded = true

task.spawn(function()
    while task.wait() do
        local success, err = pcall(mainAutoFarm)
        if not success then warn("AutoFarm Error: " .. tostring(err)) end
    end
end)

runSubLoops()

cashObj:GetPropertyChangedSignal("Value"):Connect(function()
    local val = cashObj.Value
    if val ~= lastCash then
        lastCash = val
        sendData(val)
    end
end)

task.spawn(function()
    while task.wait(HEARTBEAT_INTERVAL) do
        pcall(function() sendData(cashObj.Value) end)
    end
end)

print("[System] 🚀 Script đã chạy! (Chỉ ấn RACE SOLO + auto race 1 phút + GUI)")
