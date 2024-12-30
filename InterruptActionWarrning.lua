local frame = CreateFrame("Frame")
local addonName = ...
local IAW = {}

-- 在文件开头添加一个调试函数
local function Debug(...)
    print("|cFF00FF00[打断提示]|r", ...)
end

-- 初始化事件监听
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- 定义默认配置
local defaults = {
    enabled = true,
}

-- 事件处理函数
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Debug("插件已加载！使用 /iaw 查看命令。")
        return
    end
    
    -- 检查插件是否启用
    if not defaults.enabled then return end
    
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, 
              sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, 
              spellId, spellName, _, extraSpellId, extraSpellName = CombatLogGetCurrentEventInfo()

        -- 检查是否是打断事件
        if subevent == "SPELL_INTERRUPT" then
            -- 确保是玩家造成的打断
            if sourceGUID == UnitGUID("player") then
                Debug("检测到打断！")
                Debug("打断者:", sourceName)
                Debug("目标:", destName)
                Debug("被打断法术:", extraSpellName)
                
                -- 构建喊话信息
                local msg = string.format("已打断 %s 的 %s！", destName or "目标", extraSpellName or "法术")
                local channel = "YELL"  

                -- 如果在团队中，使用团队频道
                if IsInRaid() then
                    channel = "RAID"
                -- 如果在小队中，使用小队频道
                elseif IsInGroup() then
                    channel = "PARTY"
                end

                Debug("当前场景:", IsInRaid() and "团队" or IsInGroup() and "小队" or "个人")
                Debug("使用频道:", channel)
                
                -- 发送喊话
                SendChatMessage(msg, channel)
                
                -- 在自己的聊天框也显示一次
                print("|cFFFF0000[打断]|r " .. msg)
            end
        end
    end
end)

-- 添加斜杠命令
SLASH_IAW1 = "/iaw"
SlashCmdList["IAW"] = function(msg)
    if msg == "toggle" then
        defaults.enabled = not defaults.enabled
        print("|cFF00FF00打断提示已" .. (defaults.enabled and "启用" or "禁用"))
    elseif msg == "test" then
        print("|cFF00FF00[测试打断]|r")
        
        -- 发送测试喊话
        local msg = string.format("已打断 %s 的 %s！", "测试目标", "测试法术")
        local channel = "YELL"
        if IsInRaid() then
            channel = "RAID"
        elseif IsInGroup() then
            channel = "PARTY"
        end
        SendChatMessage(msg, channel)
    else
        -- 显示帮助信息
        print("|cFF00FF00打断提示插件命令：")
        print("|cFFFFFF00/iaw toggle|r - 开启/关闭打断提示")
        print("|cFFFFFF00/iaw test|r - 测试打断提示")
        print("|cFFFFFF00/iaw|r - 显示此帮助信息")
    end
end
