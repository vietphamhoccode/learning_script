local codes = _G.codes or {"ThanksFor750k"}

local Players    = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local plr        = Players.LocalPlayer

-- ================== UTILS ==================
local function clickGui(obj)
    if not obj then return end
    pcall(function() firesignal(obj.Activated) end)
    pcall(function() firesignal(obj.MouseButton1Click) end)
end

-- ================== TÌM RACE ==================
local function findMyRace()
    pcall(function()
        for _, v in pairs(workspace.Races.Race8.Races:GetChildren()) do
            if v.Racers:FindFirstChild(plr.Name) then
                return v
            end
        end
    end)
    -- fallback: tìm toàn bộ workspace.Races
    local ok, races = pcall(function() return workspace.Races end)
    if not ok or not races then return nil end
    for _, v in pairs(races:GetDescendants()) do
        if v:FindFirstChild("Racers") and v.Racers:FindFirstChild(plr.Name) then
            return v
        end
    end
    return nil
end

-- ================== BOOST (3 phút cooldown) ==================
local lastBoostTime = 0
local function tryUseBoost()
    local now = tick()
    if now - lastBoostTime < 180 then return end
    pcall(function()
        local boostBtn = plr.PlayerGui.RobuxShop.Menu.List.Boosts.Boost.Use
        if boostBtn and boostBtn.Visible then
            clickGui(boostBtn)
            lastBoostTime = now
            print("[Boost] Đã dùng boost, chờ 3 phút.")
        end
    end)
end

-- ================== ANTI-AFK ==================
task.spawn(function()
    print("[Anti-AFK] Bắt đầu")
    while task.wait(15) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(math.random(0,100), math.random(0,100)))
            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(math.random(-5,5)), 0)
            end
            local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
            local k = keys[math.random(1,#keys)]
            VirtualUser:SendKeyEvent(true,  k, false, game)
            task.wait(0.1)
            VirtualUser:SendKeyEvent(false, k, false, game)
        end)
    end
end)

-- ================== MAIN LOOP ==================
local SPEED         = 550   -- tốc độ cơ bản
local LERP_FACTOR   = 0.98  -- khoá hướng cứng (càng gần 1 càng không lệch)

local function mainAutoFarm()
    local gui = plr.PlayerGui
    if not gui then return end

    -- 1. Chờ game load xong rồi ấn Play
    local loadScreen = gui:FindFirstChild("LoadingScreen")
    if loadScreen and loadScreen.Enabled then
        -- đợi nút Play xuất hiện rồi click
        local btn = loadScreen:FindFirstChild("Center", true)
        if btn then btn = btn:FindFirstChild("Play", true) end
        if btn then clickGui(btn) end
        task.wait(1.5)
        return
    end

    -- 2. Chọn xe starter
    local starterPick = gui:FindFirstChild("StarterPick")
    if starterPick and starterPick.Enabled then
        -- thử tên cụ thể, nếu không có thì lấy cái đầu tiên
        local picked = false
        pcall(function()
            clickGui(starterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
            picked = true
        end)
        if not picked then
            pcall(function()
                for _, v in pairs(starterPick.Menu.Vehicles:GetChildren()) do
                    if v:IsA("ImageButton") or v:IsA("TextButton") then
                        clickGui(v); break
                    end
                end
            end)
        end
        task.wait(0.5)
        pcall(function() clickGui(starterPick.Menu.Buttons.Confirm) end)
        task.wait(0.5)
        return
    end

    -- 3. Spawn xe nếu chưa vào xe
    if not gui:FindFirstChild("A-Chassis Interface") then
        pcall(function()
            clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
            task.wait(0.5)
            for _, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
                if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                    clickGui(v)
                    task.wait(1.5)
                    break
                end
            end
        end)
        return
    end

    -- 4. Nếu chưa ở màn race → teleport
    local racesUI = gui:FindFirstChild("Races")
    if not racesUI or not racesUI.Container.Visible then
        if _G.wasRace then
            _G.wasRace = nil
            -- respawn xe trước khi teleport
            pcall(function()
                clickGui(gui.Main_User_Interface.UI_Frame.Buttons.Spawn)
                task.wait(0.5)
                for _, v in pairs(gui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
                    if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                        clickGui(v); task.wait(1.5); break
                    end
                end
            end)
        end
        pcall(function()
            clickGui(gui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
        end)
        task.wait(2)
        return
    end

    -- 5. Điều hướng xe đến checkpoint
    local myRace = findMyRace()
    if not myRace then return end

    local racer = myRace.Racers:FindFirstChild(plr.Name)
    if not racer then return end

    local myCar = racer.Vehicle and racer.Vehicle.Value
    if not myCar or not myCar.PrimaryPart then return end

    _G.myCar   = myCar
    _G.myRace  = myRace
    _G.wasRace = true

    -- tìm checkpoint tiếp theo
    local currentCP = racer:GetAttribute("Checkpoint") or 0
    local checkpointsVal = myRace:FindFirstChild("Checkpoints")  -- IntValue chứa tổng số CP
    local totalCP = checkpointsVal and checkpointsVal.Value or 12

    local nextCPNum = currentCP + 1
    local cpName    = (nextCPNum >= totalCP) and "Finish" or tostring(nextCPNum)

    local checkpointPart = checkpointsVal and checkpointsVal:FindFirstChild(cpName)
    if not checkpointPart then
        -- fallback: tìm rộng hơn trong race
        checkpointPart = myRace:FindFirstChild(cpName, true)
    end
    if not checkpointPart then
        checkpointPart = myRace:FindFirstChild("Finish", true)
    end
    if not checkpointPart then return end

    local hrp      = myCar.PrimaryPart
    local target   = checkpointPart.Position

    -- === KHOÁ HƯỚNG CỨNG ===
    -- 1. Xoay mũi xe ngay về phía checkpoint (lerp gần 1 = khoá cứng)
    local newCF = CFrame.lookAt(hrp.Position, Vector3.new(target.X, hrp.Position.Y, target.Z))
    hrp:PivotTo(hrp.CFrame:Lerp(newCF, LERP_FACTOR))

    -- 2. Áp vận tốc theo đúng LookVector sau khi đã xoay
    --    Thêm thành phần Y nhỏ để bù độ cao nếu bị lệch
    local look   = hrp.CFrame.LookVector
    local dy     = (target.Y - hrp.Position.Y)
    local yForce = math.clamp(dy * 12, -120, 120)

    hrp.AssemblyLinearVelocity = Vector3.new(
        look.X * SPEED,
        yForce,
        look.Z * SPEED
    )
end

-- ================== LOOP PHỤ: rewards + boost + noclip ==================
task.spawn(function()
    while task.wait() do
        local gui = plr.PlayerGui
        if not gui then task.wait(1); continue end

        pcall(function()
            local racesUI = gui:FindFirstChild("Races")
            if racesUI and racesUI.Container.Visible then
                -- Noclip xe + nhân vật
                if _G.myCar then
                    for _, v in pairs(_G.myCar:GetDescendants()) do
                        if v:IsA("BasePart") then v.CanCollide = false end
                    end
                end
                if plr.Character then
                    for _, v in pairs(plr.Character:GetDescendants()) do
                        if v:IsA("BasePart") then v.CanCollide = false end
                    end
                end
                -- Xoá vật cản
                for _, v in pairs(workspace:GetChildren()) do
                    if (v.ClassName == "Model" and v:FindFirstChild("Container"))
                       or v.Name == "PortCraneOversized" then
                        v:Destroy()
                    end
                end
            end
        end)

        -- Nhận phần thưởng playtime
        pcall(function()
            for _, v in pairs(gui.Main_User_Interface.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
                if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then
                    clickGui(v.Button)
                end
            end
        end)

        -- Nhận challenge rewards
        pcall(function()
            for _, v in pairs(gui.Challenges.Menu.Challenges:GetChildren()) do
                if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then
                    clickGui(v.Action)
                end
            end
        end)
        pcall(function() clickGui(gui.Challenges.Menu.Rewards.Claim) end)

        -- Daily rewards
        pcall(function()
            if gui.DailyRewards.Menu.Today.Claim.Label.Text ~= "Claimed" then
                clickGui(gui.DailyRewards.Menu.Today.Claim)
            end
        end)

        -- Boost (có cooldown 3 phút)
        tryUseBoost()

        -- Redeem codes
        pcall(function()
            for _, code in pairs(codes) do
                gui.RobuxShop.Menu.List.Rewards.Codes.Input.Text = code
                task.wait(0.1)
                clickGui(gui.RobuxShop.Menu.List.Rewards.Codes.Redeem)
                task.wait(0.3)
            end
        end)
    end
end)

-- ================== LOOP CHÍNH ==================
task.spawn(function()
    while task.wait(0.03) do
        pcall(mainAutoFarm)
    end
end)

print("[AutoFarm v3] Đã khởi động – Anti-AFK + Boost cooldown + Khoá hướng cứng")
