--[[--
HabitReads Main Plugin for KOReader.
Tracks daily pages read, updates streaks, and displays the annual contribution heatmap.
--]]--

local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

-- Safe submodule loader
local plugin_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or ""
local Settings = dofile(plugin_dir .. "settings.lua")
local Streaks = dofile(plugin_dir .. "streaks.lua")
local HeatmapModal = dofile(plugin_dir .. "heatmap.lua")

-- Register into KOReader's menu order system
local function addToMenuOrder(module_path, section, name)
    local ok, order = pcall(require, module_path)
    if ok and order and order[section] then
        for i, v in ipairs(order[section]) do
            if v == name then return end
        end
        table.insert(order[section], name)
    end
end
addToMenuOrder("ui/elements/reader_menu_order", "more_tools", "habitreads")
addToMenuOrder("ui/elements/filemanager_menu_order", "more_tools", "habitreads")

local HabitReads = WidgetContainer:extend{
    name = "habitreads",
    is_doc_only = false,
}


function HabitReads:onDispatcherRegisterActions()
    Dispatcher:registerAction("habitreads", {
        category = "none",
        event = "ShowHabitReads",
        title = _("📊 Reading Heatmap & Streaks"),
        general = true,
    })
end

function HabitReads:onShowHabitReads()
    self:showHeatmap()
end

function HabitReads:init()
    self.settings = Settings:new()
    self.last_page = nil

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function HabitReads:onReaderReady()
    if self.ui and self.ui.getCurrentPage then
        self.last_page = self.ui:getCurrentPage()
    end
end

function HabitReads:onPageUpdate(pageno)
    if not self.last_page then
        self.last_page = pageno
        return
    end

    local diff = math.abs(pageno - self.last_page)
    self.last_page = pageno

    -- Only count normal reading page turns (1 to 10 pages, ignoring massive jumps)
    if diff >= 1 and diff <= 10 then
        self.settings:recordPages(diff)

        local today_str = os.date("%Y-%m-%d")
        local today_pages = self.settings:getDailyPages(today_str)
        local unlocks = Streaks.checkActivity(self.settings, today_pages)

        if #unlocks > 0 then
            UIManager:show(InfoMessage:new{
                text = string.format(_("🌟 Milestone Unlocked!\n\n%s"), table.concat(unlocks, "\n")),
                timeout = 4,
            })
        end
    end
end

function HabitReads:addToMainMenu(menu_items)
    menu_items.habitreads = {
        text = _("📊 HabitReads"),
        sorting_hint = "more_tools",
        sub_item_table_func = function()
            return self:getSubMenuItems()
        end,
        sub_item_table = self:getSubMenuItems(),
    }
end

function HabitReads:getSubMenuItems()
    local cur_streak, best_streak, total_days = self.settings:calculateStreaks()
    local today_str = os.date("%Y-%m-%d")
    local today_pages = self.settings:getDailyPages(today_str)

    return {
        {
            text = _("📊 View Annual Heatmap & Badges"),
            callback = function()
                local modal = HeatmapModal:new{
                    settings = self.settings,
                }
                UIManager:show(modal)
            end,
        },
        {
            text = string.format(_("🔥 Current Streak: %d Days (Best: %d)"), cur_streak, best_streak),
            enabled = false,
        },
        {
            text = string.format(_("📖 Read Today: %d pages  •  Total Days: %d"), today_pages, total_days),
            enabled = false,
        },
        {
            text_func = function()
                return string.format(_("🛡️ Streak Freeze Shields: %d available"), self.settings:getFreezeTokens())
            end,
            callback = function()
                local tokens = self.settings:getFreezeTokens()
                UIManager:show(InfoMessage:new{
                    text = string.format(_("You have %d Streak Freeze Shields.\n\nFreeze shields automatically protect your streak if you miss a day while traveling or sick."), tokens),
                    timeout = 4,
                })
            end,
        },
    }
end

return HabitReads
