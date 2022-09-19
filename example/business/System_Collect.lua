--------------------------------------------------------------------------------
-- Server Collect
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Collect_Go
--------------------------------------------------------------------------------

gCollect = {}
gCollect.db = GameData.collect

Server.GetTopic("Collect_GetData").Add(function() gCollect:SendData(unit) end)
Server.GetTopic("Collect_Go").Add(function(code, num, strItemID) gCollect:Go(unit, code, num, strItemID) end)


--* 수집관련 능력치를 계산합니다.
function gCollect:CalStats(unit, stats)
    local statList = dejson(unit.GetStringVar(csvar.collect_stats))
    for strStatID, value in pairs(statList) do
        local statID = tonumber(strStatID)
        stats[statID] = stats[statID] and (stats[statID] + value) or value
    end
    return stats
end


--* 수집관련 능력치를 stringVar에 미리 저장해놓습니다 (최적화)
function gCollect:SaveStats(unit)
    local list = dejson(unit.GetStringVar(csvar.collect_list))
    
    local stats = {}
    for code, collects in pairs(list) do
        local data = self.db.list[code]
        if data then
            local isCollect = true
            for i, collect in pairs(collects) do
                if collect == 1 then
                    local stat = data.stat.each[i]
                    if stat then
                        local strStatID = tostring(stat[1])
                        stats[strStatID] = stats[strStatID] and (stats[strStatID] + stat[2]) or stat[2]
                    end
                else
                    isCollect = false
                end
            end
            if isCollect then
                local stat = data.stat.complete
                if stat then
                    local strStatID = tostring(stat[1])
                    stats[strStatID] = stats[strStatID] and (stats[strStatID] + stat[2]) or stat[2]
                end
            end 
        end
    end

    local strStats = injson(stats)
    unit.SetStringVar(csvar.collect_stats, strStats)
end


--* 수집관련 데이터를 전송합니다.
function gCollect:SendData(unit) 
    local strList = unit.GetStringVar(csvar.collect_list)
    local items = {} 
    for i, item in pairs(unit.player.GetItems()) do
        if not unit.isEquippedItem(item.id) then
            items[tostring(item.id)] = ItemToTable(item)
        end
    end
    unit.FireEvent("Collect_SendData", strList, injson(items))
end


--* 수집 등록합니다. 
function gCollect:Go(unit, code, num, strItemID)
    if not (unit and code and num and strItemID and CheckUserSystemDelay(unit)) then return end

    local data = self.db.list[code]
    if not data then ShowWrongRequestMsg(unit) return end

    local needList = data.item
    local var = dejson(unit.GetStringVar(csvar.collect_list))

    local nowList = var[code]
    local beforeNowList = injson(nowList)
    if not nowList then
        nowList = {}
        for i=1, #needList do nowList[i] = 0 end
    end
    if not (nowList[num] and nowList[num] == 0) then ShowErrMsg(unit, "이미 등록된 항목입니다.") return end

    local targetItem = type(data.item[num]) == "table" and data.item[num][1] or data.item[num]
    local targetItem2 = type(data.item[num]) == "table" and data.item[num][2] or nil
    local item = unit.player.GetItem(tonumber(strItemID))
    if not (item and (item.dataID == targetItem or item.dataID == targetItem2)) then ShowWrongRequestMsg(unit) return end
    if unit.isEquippedItem(item.id) then ShowErrMsg(unit, "장착된 아이템은 등록할 수 없습니다.") return end

    local itemName = GetItemName(item)
    local titem = ItemToTable(item)
    nowList[num] = 1

    local isCollect = true
    for i=1, #nowList do
        if nowList[i] == 0 then 
            isCollect = false 
            break
        end
    end

    local targetStatData = data.stat.each[num]
    if not targetStatData then ShowWrongRequestMsg(unit) return end
    local targetStatText = common.statName[targetStatData[1]] .. "+" .. targetStatData[2]

    var[code] = nowList
    local strVar = injson(var)
    unit.SetStringVar( csvar.collect_list, strVar )
    unit.RemoveItemByID(item.id, 1, false)

    PlaySE(unit, cse.signal)
    ShowMsg(unit, "<color=" .. cc.greenLight .. ">수집 등록에 성공하였습니다!</color>\n" .. targetStatText)
    if isCollect then
        local collectStatData = data.stat.complete
        local collectStatText = common.statName[collectStatData[1]] .. "+" .. collectStatData[2]
        Server.RunLater(function()
            if not unit then return end
            PlaySE(unit, cse.signal)
            ShowMsg(unit, "<color=" .. cc.greenLight .. ">" .. data.name .. " 테마를 완성하였습니다!</color>\n" .. collectStatText)
        end, 2)
    end

    gCollect:SaveStats(unit)
    unit.RefreshStats()
    unit.FireEvent("Collect_Success", code, num, strItemID)

    local logMsg = "[" .. data.name .. "] " .. injson(nowList) 
    local logData = {
        code = code,
        theme = data.name,
        beforeNowList = beforeNowList,
        afterNowList = nowList,
        list = var,
    }
    SendLog(unit, "Collect_Go", logMsg, injson(logData))
    SetUserSystemDelay(unit)

end










