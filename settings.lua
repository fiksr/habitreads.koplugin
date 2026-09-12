--[[--
HabitReads Settings & Persistence Manager.
Tracks daily pages read, streak history, freeze tokens, and milestones.
--]]--

local Settings = {}
Settings.__index = Settings

function Settings:new()
    local o = setmetatable({}, self)
    return o
end

function Settings:get(key, default)
    if not G_reader_settings then return default end
    local val = G_reader_settings:readSetting("habitreads_" .. key)
    if val ~= nil then return val end
    return default
end

function Settings:save(key, val)
    if not G_reader_settings then return end
    G_reader_settings:saveSetting("habitreads_" .. key, val)
end

function Settings:recordPages(count)
    if not count or count <= 0 then return end
    local today = os.date("%Y-%m-%d")
    local pages_map = self:get("daily_pages", {})
    pages_map[today] = (pages_map[today] or 0) + count
    self:save("daily_pages", pages_map)
end

function Settings:getDailyPages(date_str)
    local pages_map = self:get("daily_pages", {})
    return pages_map[date_str] or 0
end

function Settings:getAllDailyPages()
    return self:get("daily_pages", {})
end

function Settings:getFreezeTokens()
    return self:get("freeze_tokens", 2)
end

function Settings:useFreezeToken()
    local cur = self:getFreezeTokens()
    if cur > 0 then
        self:save("freeze_tokens", cur - 1)
        return true
    end
    return false
end

function Settings:getAchievements()
    return self:get("achievements", {})
end

function Settings:unlockAchievement(id)
    local ach = self:getAchievements()
    if not ach[id] then
        ach[id] = os.time()
        self:save("achievements", ach)
        return true
    end
    return false
end

-- Calculate current and best reading streak
function Settings:calculateStreaks()
    local pages_map = self:getAllDailyPages()
    local now = os.time()
    local one_day = 86400

    local today_str = os.date("%Y-%m-%d", now)
    local yesterday_str = os.date("%Y-%m-%d", now - one_day)

    -- Current streak
    local cur_streak = 0
    local check_time = now

    -- If read today, start from today; else if read yesterday, start from yesterday
    if (pages_map[today_str] or 0) > 0 then
        check_time = now
    elseif (pages_map[yesterday_str] or 0) > 0 then
        check_time = now - one_day
    else
        check_time = nil
    end

    if check_time then
        while true do
            local d_str = os.date("%Y-%m-%d", check_time)
            if (pages_map[d_str] or 0) > 0 then
                cur_streak = cur_streak + 1
                check_time = check_time - one_day
            else
                break
            end
        end
    end

    -- Longest streak calculation over all recorded history
    local sorted_dates = {}
    for d, _ in pairs(pages_map) do
        if (pages_map[d] or 0) > 0 then
            table.insert(sorted_dates, d)
        end
    end
    table.sort(sorted_dates)

    local best_streak = 0
    local running_streak = 0
    local prev_t = nil

    for _, d_str in ipairs(sorted_dates) do
        local y, m, d = d_str:match("(%d+)-(%d+)-(%d+)")
        if y and m and d then
            local t = os.time{ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }
            if prev_t then
                local diff_days = math.floor((t - prev_t) / one_day + 0.5)
                if diff_days == 1 then
                    running_streak = running_streak + 1
                elseif diff_days > 1 then
                    running_streak = 1
                end
            else
                running_streak = 1
            end
            prev_t = t
            if running_streak > best_streak then
                best_streak = running_streak
            end
        end
    end

    if cur_streak > best_streak then
        best_streak = cur_streak
    end

    return cur_streak, best_streak, #sorted_dates
end

return Settings
