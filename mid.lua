local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

while not player do
    task.wait(0.5)
    player = Players.LocalPlayer
end

-- ====================== CẤU HÌNH ======================
local API_URL = "http://vietpham.shop/api.php"
local HEARTBEAT_INTERVAL = 1
local codes = _G.codes or {"ThanksFor810k"}

local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

_G.raceProgress = "N/A"
_G.wasRace = false

-- ====================== HÀM HỖ TRỢ ======================
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

local function fixLag()
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("Decal") or v:IsA("Texture") then v:Destroy()
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
        end
    end)
end

-- ====================== CHỜ GAME LOAD ======================
local function waitForGameLoad()
    local gui = player.PlayerGui
    local timeout = tick() + 30
    while not gui:FindFirstChild("LoadingScreen") and tick() < timeout do task.wait(0.5) end

    if gui:FindFirstChild("LoadingScreen") then
        pcall(function()
            local playBtn = gui.LoadingScreen.Center.Frame.Play.Button
            if playBtn then
                if firesignal then
                    firesignal(playBtn.Activated)
                    firesignal(playBtn.MouseButton1Click)
                else
                    playBtn:Activate()
                end
            end
        end)

        local loadTimeout = tick() + 60
        while gui:FindFirstChild("LoadingScreen") and tick() < loadTimeout do
            pcall(function()
                local playBtn = gui.LoadingScreen.Center.Frame.Play.Button
                if playBtn then
                    if firesignal then
                        firesignal(playBtn.Activated)
                        firesignal(playBtn.MouseButton1Click)
                    end
                end
            end)
            task.wait(1)
        end
    end

    local uiTimeout = tick() + 30
    while not gui:FindFirstChild("Main_User_Interface") and tick() < uiTimeout do task.wait(0.5) end

    if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled then
        pcall(function()
            local veh = gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"]
            if firesignal then
                firesignal(veh.Activated)
                firesignal(veh.MouseButton1Click)
            end
        end)
        task.wait(0.5)
        pcall(function()
            local confirm = gui.StarterPick.Menu.Buttons.Confirm
            if firesignal then
                firesignal(confirm.Activated)
                firesignal(confirm.MouseButton1Click)
            end
        end)
        task.wait(1)
    end

    print("[System] ✅ Game đã load hoàn thiện!")
end

-- ====================== AUTO FARM (GIỮ NGUYÊN CHẾ ĐỘ BAY) ======================
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
    end

    if gui:FindFirstChild("StarterPick") and gui.StarterPick.Enabled then
        clickGui(gui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
        task.wait(0.5)
        clickGui(gui.StarterPick.Menu.Buttons.Confirm)
        task.wait(1)
        return
    end

    if not gui:FindFirstChild("A-Chassis Interface") then
        clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
        task.wait(1.5)
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
            task.wait(1.5)
        end
        clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
        task.wait(2)
        return
    end

    local myRace = findMyRace()
    if not myRace then
        _G.myCar = nil
        _G.myRace = nil
        return
    end

    local racer = myRace.Racers:FindFirstChild(player.Name)
    if not racer then return end

    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local totalCP = myRace:FindFirstChild("Checkpoints") and myRace.Checkpoints.Value or 12
    _G.raceProgress = currentCP .. "/" .. totalCP

    local nextCPNum = currentCP + 1
    local cpName = (nextCPNum >= totalCP) and "Finish" or tostring(nextCPNum)

    local checkpoints = myRace:FindFirstChild("Checkpoints")
    if not checkpoints then return end

    local checkpointPart = checkpoints:FindFirstChild(cpName)
    if not checkpointPart then return end

    local myCar = racer.Vehicle.Value
    _G.myCar = myCar
    _G.myRace = myRace
    _G.wasRace = true

    -- ==================== CHẾ ĐỘ BAY FARM ====================
    if myCar and myCar.PrimaryPart then
        local hrp = myCar.PrimaryPart
        local baseTarget = checkpointPart.Position
        local targetPos = baseTarget + Vector3.new(0, 5, 0) + (hrp.CFrame.LookVector * 12)

        local dist = (targetPos - hrp.Position).Magnitude
        local direction = (targetPos - hrp.Position).Unit

        local speed = dist < 38 and 1320 or 1020
        if cpName == "Finish" or nextCPNum >= totalCP - 2 then 
            speed = 1620 
        end

        hrp.AssemblyLinearVelocity = direction * speed + Vector3.new(0, 22, 0)

        local targetCFrame = CFrame.new(hrp.Position, targetPos)
        hrp:PivotTo(targetCFrame:Lerp(hrp.CFrame, 0.85))
    end
end

-- ====================== SUB LOOPS ======================
local function runSubLoops()
    -- Noclip + Auto Claim
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
                end
            end)

            -- Auto Claim
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
        end
    end)

    -- ANTI UNSEAT SIÊU MẠNH
    task.spawn(function()
        while task.wait(0.03) do
            pcall(function()
                local gui = player.PlayerGui
                if not gui.Races.Container.Visible then return end
                if not _G.myCar or not _G.myCar.Parent then return end

                local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Sit then return end

                local seat = _G.myCar:FindFirstChildWhichIsA("VehicleSeat", true) or _G.myCar:FindFirstChildWhichIsA("Seat", true)
                if seat and player.Character and player.Character.PrimaryPart then
                    player.Character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
                    task.wait(0.02)
                    seat:Sit(hum)
                    hum.Sit = true
                end
            end)
        end
    end)
end

-- ====================== KHỞI CHẠY ======================
fixLag()
waitForGameLoad()

local cashObj = getCashObject()
if not cashObj then
    warn("[System] ❌ Không tìm thấy Cash!")
    return
end

print("[System] ✅ Đã tìm thấy Cash: " .. cashObj.Value)
sendData(cashObj.Value)

task.spawn(function()
    while task.wait() do
        pcall(mainAutoFarm)
    end
end)

runSubLoops()

cashObj:GetPropertyChangedSignal("Value"):Connect(function()
    sendData(cashObj.Value)
end)

task.spawn(function()
    while task.wait(HEARTBEAT_INTERVAL) do
        pcall(function() sendData(cashObj.Value) end)
    end
end)

print("[System] 🚀 Script đã chạy | Bay Farm + Anti-Unseat cực mạnh")
