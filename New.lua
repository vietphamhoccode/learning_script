local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
while not player do
    task.wait(0.5)
    player = Players.LocalPlayer
end

-- ── CẤU HÌNH ────────────────────────────────────────────────
local API_URL = "http://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 1
local loaded = false
local lastCash = nil
local codes = _G.codes or {"ThanksFor810k"}
local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

_G.waitTime = 2
_G.maxWaitTime = 90
_G.raceProgress = "N/A"

-- ══════════════════════════════════════════════════════════════
-- PHẦN 1-4: KHỞI TẠO GAME
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
        local res = http_request({
            Url = API_URL, 
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"}, 
            Body = payload,
            TlsVerify = false
        })
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
-- PHẦN 5: BAY THẤP 5 + GIẢ LẬP DI CHUYỂN + GỬI CHECKPOINT
-- ══════════════════════════════════════════════════════════════
local function findMyRace()
    for _, v in pairs(workspace.Races.Race8.Races:GetChildren()) do
        if v.Racers:FindFirstChild(player.Name) then return v end
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
        task.wait(2)
        return
    end

    local myRace = findMyRace()
    if not myRace then
        if _G.myCar and _G.myCar.PrimaryPart then
            pcall(function()
                _G.myCar.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
        end
        _G.myCar = nil
        _G.myRace = nil
        return
    end

    local racer = myRace.Racers:FindFirstChild(player.Name)
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
-- PHẦN 6: VÒNG LẶP PHỤ + ĐÃ TỐI ƯU CƠ CHẾ CHỐNG VĂNG XE (ANTI-UNSEAT)
-- ══════════════════════════════════════════════════════════════
local function runSubLoops()
    -- Vòng lặp 1: Tối ưu chống va chạm & Auto Claim quà
    task.spawn(function()
        while task.wait(0.2) do
            local gui = player.PlayerGui
            if gui:FindFirstChild("LoadingScreen") then continue end

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

    -- Vòng lặp 2: KHÓA CHẶT NHÂN VẬT VÀO GHẾ LÁI (Tần suất siêu nhanh 0.05 giây để không bị khựng xe)
    task.spawn(function()
        while task.wait(0.05) do
            pcall(function()
                local gui = player.PlayerGui
                if gui.Races.Container.Visible and _G.myRace and player.Character then
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    
                    -- Nếu đang trong trận đua mà trạng thái nhân vật KHÔNG ngồi (Sit = false)
                    if hum and not hum.Sit and _G.myCar and _G.myCar.Parent then
                        local seat = _G.myCar:FindFirstChildWhichIsA("VehicleSeat", true) or _G.myCar:FindFirstChildWhichIsA("Seat", true)
                        if seat and player.Character.PrimaryPart then
                            -- Đưa nhân vật thẳng vào vị trí ghế và khóa trạng thái ngồi lập tức
                            player.Character:PivotTo(seat.CFrame)
                            task.wait()
                            seat:Sit(hum)
                            hum.Sit = true
                        end
                    end
                end
            end)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- KHỞI CHẠY
-- ══════════════════════════════════════════════════════════════
fixLag()
waitForGameLoad()
print("[System] ✅ Đang tìm Cash...")
local cashObj = getCashObject()
if not cashObj then warn("[System] ❌ Không tìm thấy Cash!") return end
print("[System] ✅ Đã tìm thấy Cash: " .. tostring(cashObj.Value))

local firstSend = sendData(cashObj.Value)
print(firstSend and "[System] ✅ Gửi API lần đầu thành công!" or "[System] ⚠️ Gửi API lần đầu thất bại (Nhưng vẫn chạy script)")

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

print("[System] 🚀 Script đã kích hoạt! (Đã nâng cấp Anti-Thoát xe cực mạnh)")
