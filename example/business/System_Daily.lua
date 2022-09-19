--------------------------------------------------------------------------------
-- Server Daily
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Daily_Complete
--------------------------------------------------------------------------------

gDaily = {}
gDaily.db = GameData.daily


Server.GetTopic("Daily_GetData").Add(function() gDaily:SendData(unit) end)
Server.GetTopic("Daily_Complete").Add(function(step) gDaily:Complete(unit, step) end)


--* 일일출석과 관련해 초기화 여부를 체크합니다.
function gDaily:CheckReset(unit)
    local lastDate = unit.GetVar(cvar.daily_lastData)
    local nowDate = GetDate(os.time() + 3600*9)
    if lastDate == nowDate then
        local isComplete = unit.GetVar(cvar.daily_complete) == 0 and true or false
        local isKillMonsters = unit.GetVar(cvar.daily_monsterCount) >= self.db.needMonsterCount and true or false
        local db = self.db.list[unit.GetVar(cvar.daily_step)+1]
        return (isComplete and isKillMonsters and db) and true or false
    end
    unit.SetVar(cvar.daily_lastData, nowDate)
    unit.SetVar(cvar.daily_complete, 0)
    if CheckPassByMonth(lastDate == 0 and "19910000" or lastDate, nowDate) then
        unit.SetVar(cvar.daily_step, 0)
    end
    return false
end


--* 몬스터를 카운팅합니다
function gDaily:AddMonsterCount(a, b)
    if not (a and b and a.type == 0 and b.type == 2) then return end
    if a.GetVar(cvar.daily_complete) == 1 then return end
    local nowCount = a.GetVar(cvar.daily_monsterCount)
    if nowCount >= self.db.needMonsterCount then return end
    nowCount = nowCount + 1 
    a.SetVar(cvar.daily_monsterCount, nowCount)
    if nowCount >= self.db.needMonsterCount then
        ShowMsg(a, "몬스터 " .. self.db.needMonsterCount .. "마리 처치 완료!\n일일 보상 수령이 가능합니다.")
    end
end


--* 일일출석관련 데이터를 전송합니다
function gDaily:SendData(unit)
    gDaily:CheckReset(unit)
    local lastDate = unit.GetVar(cvar.daily_lastData)
    local step = unit.GetVar(cvar.daily_step)
    local monsterCount = unit.GetVar(cvar.daily_monsterCount)
    local complete = unit.GetVar(cvar.daily_complete) == 1 and true or false
    unit.FireEvent("Daily_SendData", lastDate, step, monsterCount, complete)
end


--* 일일 선물을 수령합니다.
function gDaily:Complete(unit, cstep)
    if not (unit and cstep and CheckUserSystemDelay(unit)) then return end
    
    gDaily:CheckReset(unit)

    local targetStep = unit.GetVar(cvar.daily_step) + 1
    if (cstep + 1) ~= targetStep then return end

    local complete = unit.GetVar(cvar.daily_complete) == 1 and true or false
    if complete then
        ShowErrMsg(unit, "오늘은 이미 선물을 수령했습니다.")
        gDaily:SendData(unit)
        return
    end

    local db = self.db.list[targetStep]
    if not db then
        ShowErrMsg(unit, "이번 달은 더 이상 받을 선물이 없습니다.")
        gDaily:SendData(unit)
        return
    end

    local nowMonsterCount = unit.GetVar(cvar.daily_monsterCount)
    if nowMonsterCount < self.db.needMonsterCount then
        ShowErrMsg(unit, "몬스터를 모두 처치하지 못하였습니다.")
        gDaily:SendData(unit)
        return
    end

    local item = db.item
    local dataID = item[1]
    local count = item[2]

    AddItem(unit, dataID, count)
    ShowAddItemMsg(unit, dataID, count)
    ShowItemPopup(unit, { [tostring(dataID)] = count }) 

    unit.SetVar(cvar.daily_monsterCount, 0)
    unit.SetVar(cvar.daily_step, targetStep)
    unit.SetVar(cvar.daily_complete, 1)
    gDaily:SendData(unit)

    PlaySE(unit, cse.signal)

    local targetItemName = GetItemName(dataID) .. " x" .. count

    local logMsg = "[" .. targetStep .. "] " .. targetItemName
    local logData = { targetStep = targetStep, dataID = dataID, count = count }
    SendLog(unit, "Daily_Complete", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end
















