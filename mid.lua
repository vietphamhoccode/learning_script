local codes = _G.codes or {"ThanksFor810k"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

-- ================== CẤU HÌNH ==================
local API_URL = "https://vietpham.shop/api.php"
local RESET_INTERVAL = 180
local STUCK_THRESHOLD = 45

_G.savedPlaceId = _G.savedPlaceId or game.PlaceId
_G.savedServerId = _G.savedServerId or game.JobId
_G.raceProgress = "N/A"

local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- ================== BIẾN ==================
local lastResetTime = 0
local lastProgress = "0/12"
local stuckStartTime = 0
local lastFinishTime = 0

-- ================== HÀM ==================
function clickGui(guiObject)
    if firesignal then
        firesignal(guiObject.Activated)
        firesignal(guiObject.MouseButton1Click)
    else
        guiObject:Activate()
    end
end

function findMyRace()
    for i, v in pairs(workspace.Races.Race8.Races:GetChildren()) do
        if v.Racers:FindFirstChild(plr.Name) then return v end
    end
end

function sendData(cashValue, raceProgress)
    if not http_request then return end
    pcall(function()
        local payload = HttpService:JSONEncode({
            username = plr.Name,
            user_id = plr.UserId,
            cash = cashValue or 0,
            race_progress = raceProgress or "N/A",
            place_id = game.PlaceId,
            server_id = game.JobId,
            timestamp = os.time()
        })
        http_request({
            Url = API_URL, Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end)
end

function fullReset()
    local now = tick()
    if now - lastResetTime < 25 then return end
    lastResetTime = now

    print("[Reset] 🔄 Full Reset...")
    pcall(function() if plr.Character then plr.Character:BreakJoints() end end)
    task.wait(2.5)

    local gui = plr.PlayerGui
    pcall(function()
        clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
        task.wait(1.4)
        for i, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
            if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                clickGui(v) task.wait(2) break
            end
        end
    end)
    task.wait(2)
    pcall(function()
        clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
    end)
    print("[Reset] ✅ Reset xong")
end

function claimRewards()
    pcall(function()
        local gui = plr.PlayerGui

        -- Playtime Rewards
        for i, v in pairs(gui.Main_User_Interface.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
            if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then
                clickGui(v.Button) task.wait(0.3)
            end
        end

        -- Daily Rewards
        if gui:FindFirstChild("DailyRewards") and gui.DailyRewards.Menu.Today.Claim.Label.Text ~= "Claimed" then
            clickGui(gui.DailyRewards.Menu.Today.Claim)
        end

        -- Challenges
        for i, v in pairs(gui.Challenges.Menu.Challenges:GetChildren()) do
            if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then
                clickGui(v.Action)
            end
        end
        pcall(function() clickGui(gui.Challenges.Menu.Rewards.Claim) end)

        -- Codes
        for i, v in pairs(codes) do
            gui.RobuxShop.Menu.List.Rewards.Codes.Input.Text = v
            task.wait(0.3)
            clickGui(gui.RobuxShop.Menu.List.Rewards.Codes.Redeem)
        end
    end)
end

function closeRewardModal()
    pcall(function()
        local gui = plr.PlayerGui
        for _, modal in pairs(gui:GetDescendants()) do
            if modal.Name:find("Reward") or modal.Name:find("Result") or modal.Name:find("Complete") or modal.Name:find("Finish") then
                for _, btn in pairs(modal:GetDescendants()) do
                    if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                        local text = btn.Text or ""
                        local name = btn.Name:lower()
                        if text == "X" or text == "✕" or name:find("close") or name:find("exit") then
                            clickGui(btn) return
                        end
                    end
                end
            end
        end
    end)
end

function mainAutoFarm()
    local gui = plr.PlayerGui
    local now = tick()

    if gui:FindFirstChild("LoadingScreen") then
        clickGui(gui.LoadingScreen.Center.Frame.Play.Button)
        task.wait(1.5)
        return
    end

    if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled == true then
        clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
        task.wait(0.5)
        clickGui(gui.StarterPick.Menu.Buttons.Confirm)
        task.wait(0.5)
        return
    end

    if not gui:FindFirstChild("A-Chassis Interface") then
        clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
        for i, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
            if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                clickGui(v) task.wait(1.8) break
            end
        end
        return
    end

    if not gui.Races.Container.Visible then
        if _G.wasRace then
            _G.wasRace = nil
            clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
            for i, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
                if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                    clickGui(v) task.wait(1.5) break
                end
            end
        end
        clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
        task.wait(2.5)
        return
    end

    local myRace = findMyRace()
    if not myRace then return end

    local racer = myRace.Racers:FindFirstChild(plr.Name)
    if not racer then return end

    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local totalCP = myRace:FindFirstChild("Checkpoints") and myRace.Checkpoints.Value or 12
    _G.raceProgress = currentCP .. "/" .. totalCP

    -- Kiểm tra kẹt
    if _G.raceProgress == lastProgress then
        if stuckStartTime == 0 then stuckStartTime = now end
        if now - stuckStartTime > STUCK_THRESHOLD then
            print("[Stuck] ⏰ Kẹt quá lâu → Reset")
            fullReset()
            stuckStartTime = 0
        end
    else
        stuckStartTime = 0
        lastProgress = _G.raceProgress
    end

    -- Reset định kỳ
    if now - lastResetTime > RESET_INTERVAL then
        fullReset()
    end

    -- Hoàn thành race
    if currentCP >= totalCP then
        if now - lastFinishTime > 4 then
            lastFinishTime = now
            print("[Race] ✅ Hoàn thành! Đóng modal...")
            task.wait(1.2)
            closeRewardModal()
            task.wait(1)
            pcall(function() if plr.Character then plr.Character:BreakJoints() end end)
            task.wait(1.5)
            clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
        end
        return
    end

    -- Drive
    local nextCheckpoint = currentCP + 1
    local checkpointsFolder = nil
    for i, v in pairs(myRace:GetChildren()) do
        if v.Name == "Checkpoints" and v:IsA("IntValue") then
            checkpointsFolder = v break
        end
    end

    local checkpointPart = checkpointsFolder:FindFirstChild(nextCheckpoint >= checkpointsFolder.Value and "Finish" or tostring(nextCheckpoint))
    local myCar = myRace.Racers[plr.Name].Vehicle.Value
    _G.myCar = myCar
    _G.myRace = myRace
    _G.wasRace = true

    if myCar and myCar.PrimaryPart then
        local location = checkpointPart.Position
        local speed = 1480
        if nextCheckpoint >= totalCP - 2 then speed = 2280 end

        myCar.PrimaryPart.AssemblyLinearVelocity = myCar.PrimaryPart.CFrame.LookVector * speed + Vector3.new(0, 35, 0)
        myCar:PivotTo(CFrame.new(myCar.PrimaryPart.Position, location))
    end
end

-- ================== VÒNG LẶP ==================
spawn(function()
    while task.wait() do
        if plr.PlayerGui:FindFirstChild("LoadingScreen") then return end

        pcall(function()
            if plr.PlayerGui.Races.Container.Visible and _G.myCar then
                for i, v in pairs(_G.myCar:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
                for i, v in pairs(plr.Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)

        claimRewards()
    end
end)

spawn(function()
    while task.wait() do
        local success, err = pcall(mainAutoFarm)
        if not success then print("Error mainAutoFarm: " .. tostring(err)) end
    end
end)

-- Anti-AFK
spawn(function()
    while task.wait(35) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0,0))
        end)
    end
end)

print("[System] ✅ Code gốc + Nâng cấp hoàn tất!")
