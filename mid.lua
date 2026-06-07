local codes = _G.codes or {"ThanksFor750k"}

local Players = game:GetService("Players")
local plr = Players.LocalPlayer

function clickGui(guiObject)
    firesignal(guiObject.Activated)
    firesignal(guiObject.MouseButton1Click)
end

function findMyRace()
    for i, v in pairs(workspace.Races.Race8.Races:GetChildren()) do
        if v.Racers:FindFirstChild(plr.Name) then
            return v
        end
    end
end

function mainAutoFarm()
    if plr.PlayerGui:FindFirstChild("LoadingScreen") then
        clickGui(plr.PlayerGui.LoadingScreen.Center.Frame.Play.Button)
        wait(1.5)
    elseif plr.PlayerGui:FindFirstChild("StarterPick") and plr.PlayerGui.StarterPick.Enabled == true then
        clickGui(plr.PlayerGui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])
        wait(0.5)
        clickGui(plr.PlayerGui.StarterPick.Menu.Buttons.Confirm)
        wait(0.5)
    else
        if not plr.PlayerGui:FindFirstChild("A-Chassis Interface") then
            clickGui(plr.PlayerGui.Main_User_Interface.UI_Frame.Buttons.Spawn)
            for i, v in pairs(plr.PlayerGui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
                if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                    clickGui(v)
                    wait(1.5)
                    break
                end
            end
        else
            if not plr.PlayerGui.Races.Container.Visible then
                if _G.wasRace then
                    _G.wasRace = nil
                    clickGui(plr.PlayerGui.Main_User_Interface.UI_Frame.Buttons.Spawn)
                    for i, v in pairs(plr.PlayerGui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do
                        if v:IsA("ImageButton") and v.Name ~= "Teleport" then
                            clickGui(v)
                            wait(1.5)
                            break
                        end
                    end
                end
                clickGui(plr.PlayerGui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)
                wait(2)
            else
                local myRace = findMyRace()
                local nextCheckpoint = myRace.Racers[plr.Name]:GetAttribute("Checkpoint") + 1
                local checkpointsFolder = nil
                for i, v in pairs(myRace:GetChildren()) do
                    if v.Name == "Checkpoints" and v:IsA("IntValue") then
                        checkpointsFolder = v
                        break
                    end
                end
                local checkpointPart = checkpointsFolder:FindFirstChild(nextCheckpoint >= checkpointsFolder.Value and "Finish" or tostring(nextCheckpoint))
                local myCar = myRace.Racers[plr.Name].Vehicle.Value
                _G.myCar = myCar
                _G.myRace = myRace
                _G.wasRace = true

                if myCar and myCar.PrimaryPart then
                    local location = checkpointPart.Position
                    local mathlock = 550
                    myCar.PrimaryPart.Velocity = myCar.PrimaryPart.CFrame.LookVector * mathlock
                    myCar:PivotTo(CFrame.new(myCar.PrimaryPart.Position, location))
                end
            end
        end
    end
end

spawn(function()
    while wait() do
        if plr.PlayerGui:FindFirstChild("LoadingScreen") then return end
        pcall(function()
            if plr.PlayerGui.Races.Container.Visible then
                for i, v in pairs(_G.myCar:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
                for i, v in pairs(plr.Character:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
                for i, v in pairs(workspace:GetChildren()) do
                    if v.ClassName == "Model" and v:FindFirstChild("Container") or v.Name == "PortCraneOversized" then
                        v:Destroy()
                    end
                end
            end
        end)
        pcall(function()
            for i, v in pairs(plr.PlayerGui.Main_User_Interface.Rewards.PlaytimeRewards.Rewards:GetChildren()) do
                if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then
                    clickGui(v.Button)
                end
            end
        end)
        pcall(function()
            for i, v in pairs(plr.PlayerGui.Challenges.Menu.Challenges:GetChildren()) do
                if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then
                    clickGui(v.Action)
                end
            end
        end)
        pcall(function()
            if plr.PlayerGui.DailyRewards.Menu.Today.Claim.Label.Text ~= "Claimed" then
                clickGui(plr.PlayerGui.DailyRewards.Menu.Today.Claim)
            end
        end)
        pcall(function()
            if plr.PlayerGui.RobuxShop.Menu.List.Boosts.Boost.Use.Visible == true then
                clickGui(plr.PlayerGui.RobuxShop.Menu.List.Boosts.Boost.Use)
            end
        end)
        pcall(function()
            clickGui(plr.PlayerGui.Challenges.Menu.Rewards.Claim)
        end)
        pcall(function()
            for i, v in pairs(codes) do
                plr.PlayerGui.RobuxShop.Menu.List.Rewards.Codes.Input.Text = v
                wait()
                clickGui(plr.PlayerGui.RobuxShop.Menu.List.Rewards.Codes.Redeem)
                wait()
            end
        end)
    end
end)


spawn(function()
    while wait() do
        local success, err = pcall(mainAutoFarm)
        if not success then
            print("Error mainAutoFarm: " .. tostring(err))
        end
    end
end)
