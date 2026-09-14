--[[--
HabitReads Achievements & Milestone System.
Evaluates milestones and handles reading streak gamification.
--]]--

local _ = require("gettext")

local Streaks = {}

local MILESTONES = {
    { id = "first_step", title = "First Step", desc = "Read your first pages with HabitReads tracked."},
    { id = "night_owl", title = "Night Owl", desc = "Read during the quiet hours between midnight and 4 AM."},
    { id = "early_bird", title = "Early Bird", desc = "Read early in the morning before 7 AM."},
    { id = "marathon", title = "Reading Marathon", desc = "Read 50 or more pages in a single day."},
    { id = "centurion", title = "Centurion", desc = "Read 100 or more pages in a single day."},
    { id = "week_streak", title = "7-Day Streak", desc = "Maintained a daily reading streak for 7 consecutive days."},
    { id = "month_streak", title = "30-Day Streak", desc = "A full month of consistent daily reading!"},
}

function Streaks.getMilestoneList()
    return MILESTONES
end

function Streaks.checkActivity(settings, pages_today)
    local cur_streak, best_streak, total_days = settings:calculateStreaks()
    local hour = tonumber(os.date("%H"))

    local new_unlocks = {}

    if pages_today >= 1 then
        if settings:unlockAchievement("first_step") then
            table.insert(new_unlocks, "First Step")
        end
    end

    if hour >= 0 and hour < 4 then
        if settings:unlockAchievement("night_owl") then
            table.insert(new_unlocks, "Night Owl")
        end
    elseif hour >= 5 and hour < 7 then
        if settings:unlockAchievement("early_bird") then
            table.insert(new_unlocks, "Early Bird")
        end
    end

    if pages_today >= 50 then
        if settings:unlockAchievement("marathon") then
            table.insert(new_unlocks, "Reading Marathon")
        end
    end

    if pages_today >= 100 then
        if settings:unlockAchievement("centurion") then
            table.insert(new_unlocks, "Centurion")
        end
    end

    if cur_streak >= 7 then
        if settings:unlockAchievement("week_streak") then
            table.insert(new_unlocks, "7-Day Streak")
        end
    end

    if cur_streak >= 30 then
        if settings:unlockAchievement("month_streak") then
            table.insert(new_unlocks, "30-Day Streak")
        end
    end

    return new_unlocks
end

return Streaks
