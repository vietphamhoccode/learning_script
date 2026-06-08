local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- ── CONFIG ──────────────────────────────────────────────
local API_URL       = "http://180.93.32.170/api.php"
local SEND_INTERVAL = 5
local CASH_NAMES    = {"Cash", "Money", "Coins", "Points", "Credits"}
-- ────────────────────────────────────────────────────────

-- Chờ LocalPlayer
local player = Players.LocalPlayer
if not player then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    player = Players.LocalPlayer
end

-- Tìm http_request một lần duy nhất
local http_request = request
    or http_request
    or (syn  and syn.request)
    or (fluxus and fluxus.request)
    or (http  and http.request)

if not http_request then
    warn("[API] Không tìm thấy http_request! Cần executor hỗ trợ: Synapse, Krnl, Scriptware, Fluxus")
end

-- ── GỬI DATA ────────────────────────────────────────────
local function sendData(cashValue, reason)
    if not http_request then return false end

    local payload = HttpService:JSONEncode({
        username      = player.Name,
        user_id       = player.UserId,
        cash          = cashValue or 0,
        race_progress = reason or "N/A",
        place_id      = game.PlaceId,
        server_id     = game.JobId,
        timestamp     = os.time(),
    })

    local ok, err = pcall(function()
        local res = http_request({
            Url     = API_URL,
            Method  = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body    = payload,
        })
        print(string.format("[API] %s | status=%s | cash=%s", reason, tostring(res and res.StatusCode), tostring(cashValue)))
    end)

    if not ok then
        warn("[API] Lỗi: " .. tostring(err))
    end
    return ok
end

-- ── ĐỌC CASH ────────────────────────────────────────────
local function findCashStat()
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return nil end
    for _, name in ipairs(CASH_NAMES) do
        local stat = ls:FindFirstChild(name)
        if stat then return stat end
    end
    return nil
end

local function getCashValue()
    local stat = findCashStat()
    return stat and stat.Value or 0
end

-- ── KHỞI ĐỘNG ───────────────────────────────────────────
print(string.format("[SCRIPT] Player=%s | Place=%s | Interval=%ds", player.Name, game.PlaceId, SEND_INTERVAL))
sendData(getCashValue(), "START")

-- ── POLLING ─────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(SEND_INTERVAL)
        sendData(getCashValue(), "AUTO")
    end
end)

-- ── LẮNG NGHE THAY ĐỔI CASH ─────────────────────────────
local function attachCashListener(stat)
    local lastValue = stat.Value
    stat:GetPropertyChangedSignal("Value"):Connect(function()
        if stat.Value ~= lastValue then
            lastValue = stat.Value
            sendData(lastValue, "CHANGE")
        end
    end)
    print("[SCRIPT] Đã gắn listener vào: " .. stat.Name)
end

local cashStat = findCashStat()
if cashStat then
    attachCashListener(cashStat)
else
    -- Thử lại khi leaderstats xuất hiện
    player.ChildAdded:Connect(function(child)
        if child.Name == "leaderstats" then
            task.wait(0.5) -- chờ các stat con load xong
            local stat = findCashStat()
            if stat then attachCashListener(stat) end
        end
    end)
    print("[WARN] Chưa tìm thấy Cash — đang chờ leaderstats...")
end
