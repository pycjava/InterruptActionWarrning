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
frame.eventFilter = {
    ["SPELL_INTERRUPT"] = true
}

-- 定义默认配置
local defaults = {
    enabled = true,
}

-- 创建施法条框架
local castBar = CreateFrame("StatusBar", "InterruptActionWarrningCastBar", UIParent)
castBar:SetSize(800, 35)  -- 增加宽度和高度
castBar:SetPoint("CENTER", 0, 100)  -- 调整位置更靠上
castBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
castBar:SetStatusBarColor(1, 0.7, 0)  -- 金色
castBar:Hide()

-- 添加背景
local bg = castBar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(castBar)
bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

-- 添加法术名称文本
local spellText = castBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")  -- 使用更大的字体
spellText:SetPoint("LEFT", castBar, "LEFT", 10, 0)  -- 稍微调整文本位置
spellText:SetTextColor(1, 1, 1)

-- 添加施法时间文本
local timeText = castBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")  -- 使用更大的字体
timeText:SetPoint("RIGHT", castBar, "RIGHT", -10, 0)  -- 稍微调整文本位置
timeText:SetTextColor(1, 1, 1)

-- 添加目标监控列表
local monitoredTargets = {
    -- 示例格式：["目标名称"] = true,
    ["漫步的岩角麋"] = true
}

-- 检查附近敌对单位是否在监控列表中
local function CheckNearbyEnemies()
    -- 扫描40码范围内的敌对单位
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitCanAttack("player", unit) then
            local name = UnitName(unit)
            Debug("检测到附近敌对单位:", name)
            if monitoredTargets[name] then
                Debug("检测到附近敌对单位:", name)
                -- 如果在监控列表中，检查其施法状态
                local guid = UnitGUID(unit)
                CheckTargetSpell(unit, guid)
            end
        end
    end
end

-- 修改检查目标施法的函数以接受单位ID参数
local function CheckTargetSpell(unit, guid)
    if not unit or not UnitExists(unit) then
        castBar:Hide()
        return
    end
    
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
    local isChanneling = false
    
    if not name then
        name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible = UnitChannelInfo(unit)
        isChanneling = true
    end
    
    -- 如果检测到施法或引导
    if name and not notInterruptible then
        local startTime = startTimeMS / 1000
        local endTime = endTimeMS / 1000
        local totalTime = endTime - startTime
        
        -- 更新施法条
        castBar:SetMinMaxValues(0, totalTime)
        spellText:SetText(name)
        castBar:Show()
        
        -- 创建更新函数
        local function UpdateCastBar()
            if not UnitExists("target") then
                castBar:Hide()
                return
            end
            
            local current = GetTime() - startTime
            local timeLeft = totalTime - current
            
            if current <= totalTime then
                castBar:SetValue(isChanneling and timeLeft or current)
                timeText:SetText(string.format("%.1f", timeLeft))
                
                -- 当剩余时间小于0.5秒时变红
                if timeLeft <= 0.5 then
                    castBar:SetStatusBarColor(1, 0, 0)  -- 红色
                else
                    castBar:SetStatusBarColor(1, 0.7, 0)  -- 金色
                end
                
                C_Timer.After(0.1, UpdateCastBar)
            else
                castBar:Hide()
            end
        end
        
        UpdateCastBar()
    else
        castBar:Hide()
    end
end

-- 注册事件来检测目标变化
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")

-- 注册事件来检测姓名板更新
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

-- 事件处理函数
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Debug("插件已加载！使用 /iaw 查看命令。")
        return
    end
    
    -- 检查插件是否启用
    if not defaults.enabled then return end
    
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, extraSpellID, extraSpellName = CombatLogGetCurrentEventInfo()
        
        -- Debug("收到事件:", eventType)
        -- Debug("源GUID:", sourceGUID)
        -- Debug("玩家GUID:", UnitGUID("player"))
        
        -- if CombatLog_Object_IsA(sourceGUID, COMBATLOG_FILTER_ME) then
        if sourceGUID == UnitGUID("player") then
            -- Debug("收到玩家事件:", eventType)
            
            -- 检查是否是打断事件
            if eventType == "SPELL_INTERRUPT" then  -- 直接使用字符串比较替代过滤器
                Debug("检测到打断!")
                Debug("打断者:", sourceName)
                Debug("目标:", destName)
                Debug("被打断法术:", extraSpellName)
                
                -- 构建喊话信息
                local msg = string.format("已打断 %s 的 %s!", destName or "目标", extraSpellName or "法术")
                -- local msg = string.format("已打断 %s 的 %s!", "测试目标", "测试法术")
                local channel = "SAY"  -- 默认使用喊话

                -- 仅在团队或小队中时改变频道
                if IsInRaid() then
                    channel = "RAID"
                elseif IsInGroup() then
                    channel = "PARTY"
                end

                -- Debug("当前场景:", IsInRaid() and "团队" or IsInGroup() and "小队" or "个人")
                -- Debug("使用频道:", channel)

                -- Debug("准备发送消息...")
                -- Debug("消息内容:", msg)
                -- Debug("目标频道:", channel)
                
                -- 检查频道是否可用
                local canSend = true
                if channel == "RAID" and not IsInRaid() then
                    Debug("不在团队中，无法使用团队频道")
                    canSend = false
                elseif channel == "PARTY" and not IsInGroup() then
                    Debug("不在小队中，无法使用小队频道")
                    canSend = false
                end
                
                -- 根据检查结果选择频道
                if not canSend then
                    Debug("切换到说话频道")
                    channel = "SAY"
                end
                
                -- 使用 DEFAULT_CHAT_FRAME:AddMessage 来显示消息
                C_Timer.After(0.1, function()
                    Debug("尝试发送消息")
                    -- 添加颜色和频道标记
                    -- 发送消息
                    SendChatMessage(msg, channel)
                    local coloredMsg = string.format("|cFFFF0000[%s]|r %s", channel, msg)
                    -- 在自己的聊天框也显示一次
                    DEFAULT_CHAT_FRAME:AddMessage(coloredMsg)
                    Debug("消息发送完成")
                end)
            end
        end
    end

    -- 在事件处理函数中添加
    if event == "PLAYER_TARGET_CHANGED" or 
       (event == "UNIT_SPELLCAST_START" and ... == "target") or
       (event == "UNIT_SPELLCAST_CHANNEL_START" and ... == "target") then
        CheckNearbyEnemies()
    end
end)


-- 打印附近敌对单位
local function PrintNearbyEnemies()
    print("|cFF00FF00[IAW]|r 附近的敌对单位:")
    local found = false
    
    -- 扫描40码范围内的敌对单位
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitCanAttack("player", unit) then
            local name = UnitName(unit)
            local inList = monitoredTargets[name] and " |cFF00FF00(已监控)|r" or ""
            print("  -", name .. inList)
            found = true
        end
    end
    
    if not found then
        print("  没有发现敌对单位")
    end
end

-- 添加命令来管理监控目标
SLASH_IAW1 = "/iaw"
SlashCmdList["IAW"] = function(msg)
    -- 处理空消息
    if msg == "" then
        -- 显示帮助信息
        print("|cFF00FF00[IAW]|r 命令用法:")
        print("  /iaw test - 测试打断通告")
        print("  /iaw toggle - 开启/关闭插件")
        print("  /iaw nearby - 显示附近敌对单位")
        print("  /iaw add 目标名 - 添加监控目标")
        print("  /iaw remove 目标名 - 移除监控目标")
        print("  /iaw list - 显示所有监控目标")
        print("  /iaw clear - 清空监控列表")
        return
    end

    -- 处理单个词命令
    if msg == "test" then
        -- 测试功能代码...
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
        return
    elseif msg == "nearby" then
        PrintNearbyEnemies()
        return
    elseif msg == "list" then
        print("|cFF00FF00[IAW]|r 当前监控目标:")
        for name in pairs(monitoredTargets) do
            print("  -", name)
        end
        return
    elseif msg == "clear" then
        monitoredTargets = {}
        print("|cFF00FF00[IAW]|r 清空监控列表")
        return
    end

    -- 处理带参数的命令
    local cmd, target = msg:match("^(%S+)%s*(.*)$")
    if cmd == "add" and target ~= "" then
        monitoredTargets[target] = true
        print("|cFF00FF00[IAW]|r 添加监控目标:", target)
    elseif cmd == "remove" and target ~= "" then
        monitoredTargets[target] = nil
        print("|cFF00FF00[IAW]|r 移除监控目标:", target)
    else
        -- 未知命令，显示帮助信息
        print("|cFF00FF00[IAW]|r 未知命令。使用 /iaw 查看帮助。")
    end
end

-- 添加边框
castBar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
castBar:SetBackdropColor(0, 0, 0, 0.8)
castBar:SetBackdropBorderColor(0.7, 0.7, 0.7, 0.8)


