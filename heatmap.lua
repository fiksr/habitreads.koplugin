--[[--
HabitReads E-Ink Contribution Heatmap & Dashboard.
Renders an authentic 52-week x 7-day contribution grid with streak stats and milestone badges.
--]]--

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = Device.screen

local Streaks = require("streaks")

local HeatmapModal = InputContainer:extend{
    name = "habitreads_heatmap_modal",
    settings = nil,
}

function HeatmapModal:init()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h }

    self:buildView()
end

-- Get color level for pages count
local function getColorForPages(pages)
    if not pages or pages <= 0 then
        return Blitbuffer.COLOR_WHITE, 1 -- 0: White with border
    elseif pages <= 15 then
        return Blitbuffer.COLOR_LIGHT_GRAY, 0
    elseif pages <= 35 then
        return Blitbuffer.COLOR_GRAY, 0
    elseif pages <= 60 then
        return Blitbuffer.COLOR_DARK_GRAY, 0
    else
        return Blitbuffer.COLOR_BLACK, 0
    end
end

function HeatmapModal:buildView()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()

    local content_w = math.min(1050, screen_w - 40)

    local cur_streak, best_streak, total_days = self.settings:calculateStreaks()
    local pages_map = self.settings:getAllDailyPages()

    -- 1. Header & Stats Row
    local stats_row = HorizontalGroup:new{
        align = "center",
        TextWidget:new{
            text = string.format(_("🔥 Streak: %d Days"), cur_streak),
            face = Font:getFace("cfont", 20),
            bold = true,
        },
        HorizontalSpan:new{ width = 30 },
        TextWidget:new{
            text = string.format(_("🏆 Best: %d Days"), best_streak),
            face = Font:getFace("cfont", 20),
            bold = true,
        },
        HorizontalSpan:new{ width = 30 },
        TextWidget:new{
            text = string.format(_("📅 Total Days: %d"), total_days),
            face = Font:getFace("cfont", 20),
            bold = true,
        },
    }

    -- 2. Build 52-Week Heatmap Grid
    -- Square size calculation: cell 14px + 3px gap = 17px per week -> 52 * 17 = 884 px
    local cell_size = 14
    local cell_gap = 3
    local num_weeks = 52

    local now = os.time()
    local one_day = 86400
    local day_of_week = tonumber(os.date("%w", now)) -- 0 = Sunday, 1 = Monday, ...

    -- End on today's week
    local week_columns = {}

    for w = num_weeks - 1, 0, -1 do
        local col_cells = {}
        for d = 0, 6 do -- Sunday to Saturday
            local days_ago = (w * 7) + (day_of_week - d)
            local cell_time = now - (days_ago * one_day)
            local date_str = os.date("%Y-%m-%d", cell_time)
            local p_count = pages_map[date_str] or 0
            local color, border = getColorForPages(p_count)

            local cell = FrameContainer:new{
                width = cell_size,
                height = cell_size,
                background = color,
                bordersize = border,
                color = Blitbuffer.COLOR_GRAY,
                padding = 0,
                margin = 0,
            }
            table.insert(col_cells, cell)
            if d < 6 then
                table.insert(col_cells, VerticalSpan:new{ width = cell_gap })
            end
        end
        table.insert(week_columns, VerticalGroup:new(col_cells))
        if w > 0 then
            table.insert(week_columns, HorizontalSpan:new{ width = cell_gap })
        end
    end

    local grid_widget = HorizontalGroup:new(week_columns)

    -- Heatmap Legend
    local legend_row = HorizontalGroup:new{
        align = "center",
        TextWidget:new{ text = _("Less"), face = Font:getFace("cfont", 13), fgcolor = Blitbuffer.COLOR_DARK_GRAY },
        HorizontalSpan:new{ width = 8 },
        FrameContainer:new{ width = 12, height = 12, background = Blitbuffer.COLOR_WHITE, bordersize = 1, color = Blitbuffer.COLOR_GRAY },
        HorizontalSpan:new{ width = 4 },
        FrameContainer:new{ width = 12, height = 12, background = Blitbuffer.COLOR_LIGHT_GRAY, bordersize = 0 },
        HorizontalSpan:new{ width = 4 },
        FrameContainer:new{ width = 12, height = 12, background = Blitbuffer.COLOR_GRAY, bordersize = 0 },
        HorizontalSpan:new{ width = 4 },
        FrameContainer:new{ width = 12, height = 12, background = Blitbuffer.COLOR_DARK_GRAY, bordersize = 0 },
        HorizontalSpan:new{ width = 4 },
        FrameContainer:new{ width = 12, height = 12, background = Blitbuffer.COLOR_BLACK, bordersize = 0 },
        HorizontalSpan:new{ width = 8 },
        TextWidget:new{ text = _("More"), face = Font:getFace("cfont", 13), fgcolor = Blitbuffer.COLOR_DARK_GRAY },
    }

    -- 3. Milestones Section
    local unlocked_achievements = self.settings:getAchievements()
    local milestone_items = {
        align = "left",
        TextWidget:new{ text = _("MILESTONES & BADGES"), face = Font:getFace("cfont", 13), bold = true, fgcolor = Blitbuffer.COLOR_DARK_GRAY },
        VerticalSpan:new{ width = 8 },
    }

    local all_m = Streaks.getMilestoneList()
    for idx, m in ipairs(all_m) do
        local is_unlocked = (unlocked_achievements[m.id] ~= nil)
        local status_icon = is_unlocked and "✅" or "🔒"
        local row = TextWidget:new{
            text = string.format("%s %s — %s", status_icon, m.title, m.desc),
            face = Font:getFace("cfont", 14),
            bold = is_unlocked,
            fgcolor = is_unlocked and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_DARK_GRAY,
            max_width = content_w - 40,
        }
        table.insert(milestone_items, row)
        table.insert(milestone_items, VerticalSpan:new{ width = 4 })
    end

    local btn_close = Button:new{
        text = _("✕ Close"),
        callback = function()
            UIManager:close(self)
        end,
        bordersize = 1,
        padding = 10,
    }

    local card_items = {
        align = "center",
        TextWidget:new{
            text = _("📊 Reading Activity & Contribution Heatmap"),
            face = Font:getFace("cfont", 22),
            bold = true,
        },
        VerticalSpan:new{ width = 12 },
        stats_row,
        VerticalSpan:new{ width = 20 },
        LineWidget:new{ background = Blitbuffer.COLOR_GRAY, dimen = Geom:new{ w = content_w - 40, h = 1 } },
        VerticalSpan:new{ width = 16 },
        grid_widget,
        VerticalSpan:new{ width = 10 },
        legend_row,
        VerticalSpan:new{ width = 20 },
        LineWidget:new{ background = Blitbuffer.COLOR_GRAY, dimen = Geom:new{ w = content_w - 40, h = 1 } },
        VerticalSpan:new{ width = 16 },
        VerticalGroup:new(milestone_items),
        VerticalSpan:new{ width = 24 },
        btn_close,
    }

    local card = FrameContainer:new{
        width = content_w,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 2,
        color = Blitbuffer.COLOR_BLACK,
        padding = 20,
        margin = 0,
        VerticalGroup:new(card_items),
    }

    self[1] = FrameContainer:new{
        width = screen_w,
        height = screen_h,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = screen_w, h = screen_h },
            card,
        },
    }
end

function HeatmapModal:onClose()
    UIManager:setDirty(nil, "full")
end

return HeatmapModal
