--------------------------------------------------------------------------------
-- Server Making
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Making_Try
--------------------------------------------------------------------------------

gMaking = {}
gMaking.db = GameData.making
gMaking.maxMakingCount = 999


Server.GetTopic("Making_GetData").Add(function() gMaking:SendData(unit) end)
Server.GetTopic("Making_Effect").Add(function() gMaking:ShowEffect(unit) end)
Server.GetTopic("Making_Try").Add(function(...) gMaking:Try(unit, ...) end)


--* 제작관련 보유아이템, 한정데이터를 클라이언트로 전송합니다.
function gMaking:SendData(unit)
    gMaking:CheckResetLimit(unit)
    local strItems = injson( GetBagItems(unit, true) )
    local strLimitData = unit.GetStringVar( csvar.limit_making )
    unit.FireEvent("Making_SendData", strItems, strLimitData)
end


--* 제작 한정 데이터 초기화를 체크합니다.
function gMaking:CheckResetLimit(unit, targetCode)
    local strLimitData = unit.GetStringVar( csvar.limit_making )
    local limitData = dejson(strLimitData)
    local nowDate = GetDate(os.time() + 3600*9)

    local isChange = false 
    for code, data in pairs(limitData) do
        if (not targetCode) or (code == targetCode) then
            local sdata = GameData.making.list[code]
            local resetType = (sdata and sdata.limit) and sdata.limit.resetType or 0
            if (not sdata)
            or ( resetType == 1 and CheckPassByDay(data.lastDate, nowDate) )
            or ( resetType == 2 and CheckPassByWeek(data.lastDate, nowDate) )
            or ( resetType == 3 and CheckPassByMonth(data.lastDate, nowDate) )
            or ( resetType == 0 and data.deleteDate and data.deleteDate < nowDate ) then
                limitData[code] = nil
                isChange = true
            end
        end
    end
    local afterStrLimitData = injson(limitData)
    if strLimitData ~= afterStrLimitData then
        unit.SetStringVar(csvar.limit_making, afterStrLimitData)
        return isChange, limitData[targetCode]
    end
    return isChange, limitData[targetCode]
end


--* 제작 한정 데이터를 추가합니다.
function gMaking:AddLimit(unit, makingCode, tryCount)
    local data = GameData.making.list[makingCode]
    if not (data and data.limit) then
        return
    end
    local limitData = dejson( unit.GetStringVar( csvar.limit_making ) )
    local limit = limitData[makingCode] or {}
    limit.count = limit.count and (limit.count + tryCount) or tryCount
    limit.lastDate = GetDate(os.time() + 3600*9)
    limit.deleteDate = data.limit.deleteDate or nil
    limitData[makingCode] = limit
    unit.SetStringVar(csvar.limit_making, injson(limitData))
    return limit
end


--* 제작 이펙트를 띄웁니다.
function gMaking:ShowEffect(unit)
    PlaySE(unit, cse.making)
    unit.StartGlobalEvent(cevent.making)
end



--* 아이템을 제작합니다.
function gMaking:Try(unit, makingCode, tryCount)
    if (not (unit and makingCode and tryCount)) or (not CheckUserSystemDelay(unit)) then return end
    if CheckBagFull(unit, true) then return end

    local makingCode = makingCode
    local tryCount = math.rounddown(tryCount)
    local data = self.db.list[makingCode]
    if not (data and tryCount > 0) then
        ShowWrongRequestMsg(unit)
        gMaking:SendData(unit)
        return
    end

    local itemName = GetItemName(data.target.hit[1])
    local itemData = GetItemData(data.target.hit[1])
    local isChangeLimitData, nowUserLimitData = gMaking:CheckResetLimit(unit, makingCode)
    local remainingLimitCount = data.limit and (data.limit.count - (nowUserLimitData and nowUserLimitData.count or 0)) or self.maxMakingCount
    local maxTryCount = math.min( data.oneTimeMaxCount or ((itemData.type or 0)>100 and 1 or self.maxMakingCount), remainingLimitCount )

    if isChangeLimitData then
        ShowErrMsg(unit, "한정 정보가 변경되었습니다.\n잠시 후 다시 시도해주세요.")
        gMaking:SendData(unit)
        return
    end

    if data.period then
        local nowDate = GetDate(os.time() + 3600*9)
        local startDate = data.period.startDate or 0
        local endDate = data.period.endDate or 20991231
        if not (startDate <= nowDate and nowDate <= endDate) then
            ShowErrMsg(unit, "제작 가능 기한이 아닙니다.")
            return
        end
    end

    if data.reqLevel and data.reqLevel > unit.level then
        ShowReqLevelMsg(unit, data.reqLevel)
        return
    end

    if maxTryCount < tryCount then
        ShowErrMsg(unit, "최대 제작 개수를 초과하였습니다.")
        return
    end

    -- 재료 확인
    local sumNeedLog, sumHaveLog = {}, {}
    for i, need in pairs(data.need) do
        local needCount = need[2] * tryCount
        local haveCount, haveLog = CountItem(unit, need[1], true, true)
        if haveCount < needCount then
            ShowLackMsg(unit, "제작")
            return
        end
        sumNeedLog[tostring(i)] = { dataID = need[1], needCount = needCount, haveCount = haveCount }
        sumHaveLog[tostring(i)] = haveLog
    end

    -- 결과 계산
    local hitRate = data.hitRate or 100
    local bigHitRate = data.bigHitRate or 0
    local hitCount, bigHitCount, failCount = 0, 0, 0
    for i=1, tryCount do
        local isHit = hitRate >= 100 and true or ( rand(1, 10^10+1) <= (hitRate/100 * 10^10) and true or false )
        local isBigHit = (isHit and bigHitRate > 0) and ( rand(1, 10^10+1) <= (bigHitRate/100 * 10^10) and true or false )
        hitCount = hitCount + ((isHit and (not isBigHit)) and 1 or 0) 
        bigHitCount = bigHitCount + (isBigHit and 1 or 0) 
        failCount = failCount + ((not isHit) and 1 or 0)
    end

    -- 한정 데이터 입력
    local afterUserLimitData = gMaking:AddLimit(unit, makingCode, (hitCount + bigHitCount))
    
    -- 재료 소모
    local sumUseLog = {}
    for strI, need in pairs(sumNeedLog) do
        sumUseLog[strI] = RemoveItem(unit, need.dataID, need.needCount, true, true)
    end
    local isHit = hitRate >= 100 and true or (rand(1, 10 ^ 10 + 1) <= (hitRate / 100 * 10 ^ 10) and (true or false))

    -- 아이템 지급
    local sumResultItems ={}
    if bigHitCount > 0 then
        local target = data.target.bigHit
        local dataID = target[1]
        local sumCount = (target[2] or 1) * bigHitCount
        AddItem(unit, dataID, sumCount)
        sumResultItems[tostring(dataID)] = sumResultItems[tostring(dataID)] and (sumResultItems[tostring(dataID)] + sumCount) or sumCount
    end
    if hitCount > 0 then
        local target = data.target.hit
        local dataID = target[1]
        local sumCount = (target[2] or 1) * hitCount
        AddItem(unit, dataID, sumCount)
        sumResultItems[tostring(dataID)] = sumResultItems[tostring(dataID)] and (sumResultItems[tostring(dataID)] + sumCount) or sumCount
    end

    if failCount > 0 and data.target.fail then
        local target = data.target.fail
        local dataID = target[1]
        local sumCount = (target[2] or 1) * failCount
        AddItem(unit, dataID, sumCount)
        sumResultItems[tostring(dataID)] = sumResultItems[tostring(dataID)] and (sumResultItems[tostring(dataID)] + sumCount) or sumCount
    end
    if failCount > 0 and data.target.failMore then
        for _, target in pairs(data.target.failMore) do
            local dataID = target[1]
            local sumCount = (target[2] or 1) * failCount
            AddItem(unit, dataID, sumCount)
            sumResultItems[tostring(dataID)] = sumResultItems[tostring(dataID)] and (sumResultItems[tostring(dataID)] + sumCount) or sumCount
        end
    end
    
    if (hitCount + bigHitCount <= 0) then PlaySE(unit, cse.broken) unit.StartGlobalEvent(cevent.flash_1_red)
    elseif bigHitCount >= 1 then PlaySE(unit, cse.success) unit.StartGlobalEvent(cevent.flash_1_yellow)
    else PlaySE(unit, cse.signal) unit.StartGlobalEvent(cevent.flash_1)
    end

    -- 알림
    local popupDecs = "총 ".. tryCount .. "회 중 " .. (bigHitCount + hitCount) .. "회 성공" .. (bigHitCount >= 1 and (" (대성공 " .. bigHitCount .. "회)") or "") 
    ShowItemPopup(unit, sumResultItems, "<size=12>" .. popupDecs .. "</size>", nil, (hitCount + bigHitCount) <= 0 and "제작 실패" or nil)
    gMaking:SendData(unit)

    ----------------------------------------------------------

    local logMsg = "[" .. makingCode .. "]_[" .. GetItemName(CheckItemTable(data.target.hit)) 
    logMsg = logMsg .. ((data.target[2] and data.target[2] > 1) and (" x" .. data.target[2]) or "") .."]" 
    logMsg = logMsg .. "_[" .. popupDecs .. "]"
    local logData = {
        makingCode = makingCode, tryCount = tryCount,
        hit = hitCount, bigHit = bigHitCount, fail = failCount,
        need = sumNeedLog, have = sumHaveLog, use = sumUseLog,
    }
    SendLog(unit, "Making_Try", logMsg, injson(logData))
    SetUserSystemDelay(unit)

    
    if (bigHitCount + hitCount) >= 1 and data.serverNotice then
        Chat(Server, "[#] " .. unit.player.name .."님께서 " .. itemName .. " 제작에 성공하셨습니다.", cc.yellow)
    end
end

