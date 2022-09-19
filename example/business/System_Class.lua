--------------------------------------------------------------------------------
-- Server Class
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Class_UP
--------------------------------------------------------------------------------

gClass = {}
gClass.db = GameData.class

Server.GetTopic("Class_GetData").Add(function() gClass:SendData(unit) end)
Server.GetTopic("Class_Teleport").Add(function() gClass:Teleport(unit) end)
Server.GetTopic("Class_Up").Add(function(cTargetClass) gClass:Up(unit, cTargetClass) end)


--* 현재 클래스에 따른 보너스 능력치를 계산합니다.
function gClass:CalStats(unit, stats)
    local nowClass = unit.GetVar( cvar.class )
    local data = self.db.list[nowClass]
    if not data then return end
    for statID, value in pairs(data.bonusStat) do
        stats[statID] = stats[statID] + value
    end
end


-- 클래스관련 데이터를 전송합니다.
function gClass:SendData(unit)
    local nowClass = unit.GetVar(cvar.class)
    local items = GetBagItemsByCount(unit)
    unit.FireEvent("Class_SendData", nowClass, injson(items))
end


-- 클래스 업을 위해 장로 앞으로 이동합니다.
function gClass:Teleport(unit)
    if not (unit and CheckUserSystemDelay(unit)) then return end
    gTeleport:Go(unit, "classup_npc")
end


-- 클래스 업!
function gClass:Up(unit, cTargetClass)
    if not (unit and cTargetClass and CheckUserSystemDelay(unit)) then return end

    local nowClass = unit.GetVar( cvar.class )
    local targetClass = nowClass + 1

    if targetClass ~= cTargetClass then
        ShowWrongRequestMsg(unit)
        return
    end

    local data = self.db.list[targetClass] 
    if not data then
        ShowErrMsg(unit, "현재로서는, 최고 경지에 도달하였습니다.")
        return
    end

    if data.reqLevel > unit.level then
        ShowReqLevelMsg(unit, data.reqLevel)
        return
    end

    local sumNeedLog, sumHaveLog = {}, {}
    for i, need in pairs(data.needItem) do
        local dataID, needCount = need[1], need[2]
        local haveCount, haveLog = CountItem(unit, dataID, true, true)
        if haveCount < needCount then
            ShowLackMsg(unit, "승급")
            return
        end
        sumNeedLog[tostring(i)] = { dataID = dataID, needCount = needCount, haveCount = haveCount }
        sumHaveLog[tostring(i)] = haveLog
    end

    local sumUseLog = {}
    for strI, need in pairs(sumNeedLog) do
        sumUseLog[strI] = RemoveItem(unit, need.dataID, need.needCount, true)
    end

    unit.SetVar( cvar.class, targetClass )
    unit.FireEvent("Class_DestroyUI")
    ShowMsg(unit, targetClass .. "차 승급 완료 !", cc.yellow)
    unit.ShowAnimation(4)
    PlaySE(unit, cse.classUp)
    Chat(Server, "[#] " .. unit.player.name .. "님께서 " .. targetClass .. "차 승급을 완료하였습니다." , cc.green) 

    local logMsg = nowClass .. " ▶ " .. targetClass
    local logData = {
        nowClass = nowClass, targetClass = targetClass, 
        sumNeedLog = sumNeedLog, sumHaveLog = sumHaveLog, sumUseLog = sumUseLog,
    }
    SendLog(unit, "Class_UP", logMsg, logData)
    SetUserSystemDelay(unit)

    unit.RefreshStats()
    if targetClass%5 == 0 then
        ChangeSkillSet(unit, GetSkillSetNumber(unit))
    end
end



-- 대죄악 소환
function gClass:SpwanDownTownBoss(unit)
    if not unit then return end

    local field = unit.field
    local fieldID = field.dataID

    if fieldID ~= 144 then return end

    -- 재료 확인
    local needs = { 
        { dataID = {939, 940} },
        { dataID = {941, 942} },
        { dataID = {943, 944} },
        { dataID = {945, 946} },
        { dataID = {947, 948} },
    }
    local sumNeedLog, sumHaveLog = {}, {}
    for i, need in pairs(needs) do
        local needCount = need.count or 1
        local haveCount, haveLog = CountItem(unit, need.dataID, true)
        if haveCount < needCount then
            ShowLackMsg(unit, "소환")
            return
        end
        sumNeedLog[tostring(i)] = { dataID = need.dataID, needCount = needCount, haveCount = haveCount }
        sumHaveLog[tostring(i)] = haveLog
    end

    -- 재료 소모
    local sumUseLog = {}
    for strI, need in pairs(sumNeedLog) do
        sumUseLog[strI] = RemoveItem(unit, need.dataID, need.needCount, true)
    end

    -- 소환
    field.SpawnEnemy(531, 24*32, 18*-32)

    local logData = {
        sumNeedLog = sumNeedLog,
        sumHaveLog = sumHaveLog,
        sumUseLog = sumUseLog,
    }
    SendLog(unit, "Class_Spwan", "대죄악", injson(logData))
end
