--------------------------------------------------------------------------------
-- Server Prairie Boss 북쪽초원 보스 소환
--------------------------------------------------------------------------------

gPrairieBoss = {}
gPrairieBoss.db = GameData.prairieBoss

Server.GetTopic("PrairieBoss_GetData").Add(function(code) gPrairieBoss:SendData(unit, code) end)
Server.GetTopic("PrairieBoss_Spawn").Add(function(code, isTest) gPrairieBoss:SpawnBoss(unit, code, isTest) end)


--* 보유 아이템 개수를 전송합니다.
function gPrairieBoss:SendData(unit, code)
    local code = tonumber(code)
    local data = self.db.list[code]
    local haveItemCount = CountItem(unit, data.needItemID)
    unit.FireEvent("PrairieBoss_SendData", haveItemCount)
end


--* 마물을 소환합니다.
function gPrairieBoss:SpawnBoss(unit, code, isTest)
    if not (unit and code and CheckUserSystemDelay(unit)) then return end

    local code = tonumber(code)
    local data = self.db.list[code]
    if not data then ShowWrongRequestMsg(unit) return end

    local map = data.map
    local fieldID = unit.field.dataID
    if map[1] ~= fieldID then
        ShowErrMsg(unit, "소환할 수 없는 장소입니다.")
        unit.FireEvent("PrairieBoss_DestroyUI")
        return
    end

    local needItemID = data.needItemID
    local needItemCount = isTest and 0 or 10
    local haveItemCount = CountItem(unit, needItemID)
    if needItemCount > haveItemCount then
        ShowLackMsg(unit, "소환")
        return
    end

    if not isTest then
        RemoveItem(unit, needItemID, needItemCount)
    end
    local targetMonsterID = isTest and data.testMonsterID or data.monsterID
    unit.field.SpawnEnemy(targetMonsterID, map[2] * 32, map[3] * -32)
    ShowMsg(unit, data.name .. "이 소환되었습니다.")
    if isTest then
        ShowMsg(unit, "연습 소환은 보상이 지급되지 않습니다.", nil, 1)
    end
    unit.FireEvent("PrairieBoss_DestroyUI")
    unit.StartGlobalEvent(cevent.quake_1)
    
    ----------------------------------------------------------
    local logMsg = "[" .. code .. "] " .. data.name .. (isTest and "(Test)" or "")
    local logData = { code = code, isTest = isTest, needItemCount = needItemCount, haveItemCount = haveItemCount }
    SendLog(unit, "PrairieBoss_Spawn", logMsg, injson(logData))

    SetUserSystemDelay(unit)
end










































