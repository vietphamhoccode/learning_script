[span_2](start_span)local codes = _G.codes or {"ThanksFor810k"}[span_2](end_span)

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local plr = Players.LocalPlayer

-- ==================== HÀM CHỜ GAME LOAD HOÀN TOÀN ====================
local function waitForGameToLoad()
    print("[System] ⏳ Đang chờ trò chơi tải dữ liệu...")
    
    -- 1. Chờ game load xong các asset cơ bản của Roblox
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    -- 2. Chờ LocalPlayer tồn tại
    while not plr do 
        task.wait(0.5) 
        plr = Players.LocalPlayer 
    end
    
    -- 3. Chờ Nhân vật (Character) và Nhân thể (HumanoidRootPart) xuất hiện
    if not plr.Character then
        plr.CharacterAdded:Wait()
    end
    local character = plr.Character
    while not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") do
        task.wait(0.5)
    end
    
    -- 4. Chờ giao diện UI chính của game xuất hiện trong PlayerGui
    while not plr:FindFirstChild("PlayerGui") or not plr.PlayerGui:FindFirstChild("Main_User_Interface") do
        task.wait(0.5)
    end
    
    print("[System] ✅ Trò chơi đã tải xong! Bắt đầu kích hoạt Auto Farm...")
end

-- Kích hoạt hàm chờ trước khi chạy các logic phía dưới
waitForGameToLoad()

-- ==================== CẤU HÌNH BIẾN PHỤ TRỢ ====================
local API_URL = "https://keywave.site/api.php"
local http_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
local _lastSentCash = -1
local lastBoostTime = 0
_G.raceProgress = "N/A"

function clickGui(guiObject)
    if not guiObject then return end
    pcall(function()
        if firesignal then
            [span_3](start_span)firesignal(guiObject.Activated)[span_3](end_span)
            [span_4](start_span)firesignal(guiObject.MouseButton1Click)[span_4](end_span)
        else
            guiObject:Activate()
        end
    end)
end

-- Hàm gửi dữ liệu lên API
local function sendData(cashValue, raceProgress)
    if not http_request then return end
    if cashValue == _lastSentCash and raceProgress == _G.raceProgress then return end
    _lastSentCash = cashValue
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
        http_request({Url = API_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
    end)
end

function findMyRace()
    local success, result = pcall(function()
        [span_5](start_span)for i, v in pairs(workspace.Races.Race8.Races:GetChildren()) do[span_5](end_span)
            [span_6](start_span)if v.Racers:FindFirstChild(plr.Name) then[span_6](end_span)
                [span_7](start_span)return v[span_7](end_span)
            end
        end
    end)
    if success then return result end
    return nil
end

-- Hàm lấy giá trị tiền để gửi API
local function getCashValue()
    local ls = plr:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    return cash and cash.Value or 0
end

-- LOGIC AUTO FARM GỐC TỪ FILE TEXT
function mainAutoFarm()
    [span_8](start_span)if plr.PlayerGui:FindFirstChild("LoadingScreen") then[span_8](end_span)
        [span_9](start_span)clickGui(plr.PlayerGui.LoadingScreen.Center.Frame.Play.Button)[span_9](end_span)
        [span_10](start_span)wait(1.5)[span_10](end_span)
    [span_11](start_span)elseif plr.PlayerGui:FindFirstChild("StarterPick") and plr.PlayerGui.StarterPick.Enabled == true then[span_11](end_span)
        [span_12](start_span)clickGui(plr.PlayerGui.StarterPick.Menu.Vehicles["1997 Hassan P34 LT-R"])[span_12](end_span)
        [span_13](start_span)wait(0.5)[span_13](end_span)
        [span_14](start_span)clickGui(plr.PlayerGui.StarterPick.Menu.Buttons.Confirm)[span_14](end_span)
        [span_15](start_span)wait(0.5)[span_15](end_span)
    else
        [span_16](start_span)if not plr.PlayerGui:FindFirstChild("A-Chassis Interface") then[span_16](end_span)
            [span_17](start_span)clickGui(plr.PlayerGui.Main_User_Interface.UI_Frame.Buttons.Spawn)[span_17](end_span)
            [span_18](start_span)for i, v in pairs(plr.PlayerGui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do[span_18](end_span)
                [span_19](start_span)if v:IsA("ImageButton") and v.Name ~= "Teleport" then[span_19](end_span)
                    [span_20](start_span)clickGui(v)[span_20](end_span)
                    [span_21](start_span)wait(1.5)[span_21](end_span)
                    [span_22](start_span)break[span_22](end_span)
                end
            end
        else
            [span_23](start_span)if not plr.PlayerGui.Races.Container.Visible then[span_23](end_span)
                [span_24](start_span)if _G.wasRace then[span_24](end_span)
                    _[span_25](start_span)G.wasRace = nil[span_25](end_span)
                    [span_26](start_span)clickGui(plr.PlayerGui.Main_User_Interface.UI_Frame.Buttons.Spawn)[span_26](end_span)
                    [span_27](start_span)for i, v in pairs(plr.PlayerGui.Main_User_Interface.Garage.Container.Vehicles:GetChildren()) do[span_27](end_span)
                        [span_28](start_span)if v:IsA("ImageButton") and v.Name ~= "Teleport" then[span_28](end_span)
                            [span_29](start_span)clickGui(v)[span_29](end_span)
                            [span_30](start_span)wait(1.5)[span_30](end_span)
                            [span_31](start_span)break[span_31](end_span)
                        end
                    end
                end
                [span_32](start_span)clickGui(plr.PlayerGui.Main_User_Interface.Teleport.Container.Races.Race8.Container.Teleport)[span_32](end_span)
                [span_33](start_span)wait(2)[span_33](end_span)
            else
                [span_34](start_span)local myRace = findMyRace()[span_34](end_span)
                if not myRace then return end 
                
                local racerObj = myRace.Racers:FindFirstChild(plr.Name)
                if not racerObj then return end

                [span_35](start_span)local nextCheckpoint = racerObj:GetAttribute("Checkpoint") + 1[span_35](end_span)
                local checkpointsFolder = nil
                [span_36](start_span)for i, v in pairs(myRace:GetChildren()) do[span_36](end_span)
                    [span_37](start_span)if v.Name == "Checkpoints" and v:IsA("IntValue") then[span_37](end_span)
                        [span_38](start_span)checkpointsFolder = v[span_38](end_span)
                        [span_39](start_span)break[span_39](end_span)
                    end
                end
                
                if not checkpointsFolder then return end
                
                _G.raceProgress = (nextCheckpoint - 1) .. "/" .. checkpointsFolder.Value

                [span_40](start_span)local checkpointPart = checkpointsFolder:FindFirstChild(nextCheckpoint >= checkpointsFolder.Value and "Finish" or tostring(nextCheckpoint))[span_40](end_span)
                [span_41](start_span)local myCar = racerObj.Vehicle.Value[span_41](end_span)
                _[span_42](start_span)G.myCar = myCar[span_42](end_span)
                _[span_43](start_span)G.myRace = myRace[span_43](end_span)
                _[span_44](start_span)G.wasRace = true[span_44](end_span)

                [span_45](start_span)if myCar and myCar.PrimaryPart and checkpointPart then[span_45](end_span)
                    [span_46](start_span)local location = checkpointPart.Position[span_46](end_span)
                    [span_47](start_span)local mathlock = 550[span_47](end_span)
                    [span_48](start_span)myCar.PrimaryPart.Velocity = myCar.PrimaryPart.CFrame.LookVector * mathlock[span_48](end_span)
                    [span_49](start_span)myCar:PivotTo(CFrame.new(myCar.PrimaryPart.Position, location))[span_49](end_span)
                end
            end
        end
    end
end

-- VÒNG LẶP PHỤ: GIỮ NGUYÊN LOGIC GỐC + CONFIG LẠI BOOST CHUẨN 15 PHÚT
spawn(function()
    while wait() do
        [span_50](start_span)if plr.PlayerGui:FindFirstChild("LoadingScreen") then return end[span_50](end_span)
        
        -- Logic Noclip và xoá Object vướng map gốc
        pcall(function()
            [span_51](start_span)if plr.PlayerGui.Races.Container.Visible and _G.myCar then[span_51](end_span)
                [span_52](start_span)for i, v in pairs(_G.myCar:GetDescendants()) do[span_52](end_span)
                    [span_53](start_span)if v:IsA("BasePart") then[span_53](end_span)
                        [span_54](start_span)v.CanCollide = false[span_54](end_span)
                    end
                end
                [span_55](start_span)if plr.Character then[span_55](end_span)
                    [span_56](start_span)for i, v in pairs(plr.Character:GetDescendants()) do[span_56](end_span)
                        [span_57](start_span)if v:IsA("BasePart") then[span_57](end_span)
                            [span_58](start_span)v.CanCollide = false[span_58](end_span)
                        end
                    end
                end
                [span_59](start_span)for i, v in pairs(workspace:GetChildren()) do[span_59](end_span)
                    [span_60](start_span)if v.ClassName == "Model" and v:FindFirstChild("Container") or v.Name == "PortCraneOversized" then[span_60](end_span)
                        [span_61](start_span)v:Destroy()[span_61](end_span)
                    end
                end
            end
         pcall(function()
            [span_62](start_span)for i, v in pairs(plr.PlayerGui.Main_User_Interface.Rewards.PlaytimeRewards.Rewards:GetChildren()) do[span_62](end_span)
                [span_63](start_span)if v:FindFirstChild("Button") and not v.Button.Claimed.Visible then[span_63](end_span)
                    [span_64](start_span)clickGui(v.Button)[span_64](end_span)
                end
            end
        end)
        
        -- Auto nhận thưởng thử thách gốc
        pcall(function()
            [span_65](start_span)for i, v in pairs(plr.PlayerGui.Challenges.Menu.Challenges:GetChildren()) do[span_65](end_span)
                [span_66](start_span)if v:FindFirstChild("Action") and v.Action.Label.Text == "Claim" then[span_66](end_span)
                    [span_67](start_span)clickGui(v.Action)[span_67](end_span)
                end
            end
        end)
        
        -- Auto nhận thưởng Daily Reward gốc
        pcall(function()
            [span_68](start_span)if plr.PlayerGui.DailyRewards.Menu.Today.Claim.Label.Text ~= "Claimed" then[span_68](end_span)
                [span_69](start_span)clickGui(plr.PlayerGui.DailyRewards.Menu.Today.Claim)[span_69](end_span)
            end
        end)
        
        -- FIX MỚI: Chỉ kích hoạt Boost chuẩn 15 phút một lần (900 giây) tránh spam shop công cộng
        pcall(function()
            local now = tick()
            if now - lastBoostTime >= 900 then
                [span_70](start_span)if plr.PlayerGui.RobuxShop.Menu.List.Boosts.Boost.Use.Visible == true then[span_70](end_span)
                    [span_71](start_span)clickGui(plr.PlayerGui.RobuxShop.Menu.List.Boosts.Boost.Use)[span_71](end_span)
                    lastBoostTime = tick()
                    print("[System] ✅ Kích hoạt Boost thành công (Hẹn giờ 15 phút sau làm lại)!")
                end
            end
        end)
        
        -- Thưởng thử thách phụ gốc
        pcall(function()
            [span_72](start_span)clickGui(plr.PlayerGui.Challenges.Menu.Rewards.Claim)[span_72](end_span)
        end)
        
        -- Nhập Giftcode gốc
        pcall(function()
            [span_73](start_span)for i, v in pairs(codes) do[span_73](end_span)
                [span_74](start_span)plr.PlayerGui.RobuxShop.Menu.List.Rewards.Codes.Input.Text = v[span_74](end_span)
                [span_75](start_span)wait()[span_75](end_span)
                [span_76](start_span)clickGui(plr.PlayerGui.RobuxShop.Menu.List.Rewards.Codes.Redeem)[span_76](end_span)
                [span_77](start_span)wait()[span_77](end_span)
            end
        end)
    end
end)

-- VÒNG LẶP CHÍNH CHẠY AUTO FARM GỐC
spawn(function()
    while wait() do
        [span_78](start_span)local success, err = pcall(mainAutoFarm)[span_78](end_span)
        [span_79](start_span)if not success then[span_79](end_span)
            [span_80](start_span)print("Error mainAutoFarm: " .. tostring(err))[span_80](end_span)
        end
    end
end)

-- VÒNG LẶP GỬI DỮ LIỆU ĐỊNH KỲ QUA API (MỖI 1 GIÂY)
spawn(function()
    while task.wait(1) do
        pcall(function()
            sendData(getCashValue(), _G.raceProgress)
        end)
    end
end)
