--------------------------------------------------------------------------------
-- Server Shop
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Shop_Buy
-- Shop_Buy_Cube
--------------------------------------------------------------------------------

gShop = {}
gShop.db = GameData.shop
gShop.maxBuyCount = 999
gShop.mileageItemID = 18
gShop.mileagePer = 10

Server.GetTopic("Shop_GetData").Add(function(isFirst) gShop:SendData(unit, isFirst) end)
Server.GetTopic("Shop_Buy").Add(function(shopCode, buyCount) gShop:Buy(unit, shopCode, buyCount) end)
Server.GetTopic("Shop_GetMileage").Add(function() gShop:GetMileage(unit) end)

Server.GetTopic("Shop_AddBookmark").Add(function(targetCode) gShop:AddBookmark(unit, targetCode) end)
Server.GetTopic("Shop_RemoveBookmark").Add(function(targetCode) gShop:RemoveBookmark(unit, targetCode) end)
Server.GetTopic("Shop_ResetBookmark").Add(function() gShop:ResetBookmark(unit) end)

--* 클라이언트로 한정구입, 보유재화 데이터를 전송합니다.
function gShop:SendData(unit, isFirst)
    gShop:CheckResetLimit(unit)
    gShop:CheckBookmark(unit)
    local strHaveItemCount = injson( GetBagItemsByCount(unit) )
    local strLimitData = unit.GetStringVar( csvar.limit_shop )
    local payCube = unit.GetVar(cvar.payCube)
    local gainMileage = unit.GetVar(cvar.gain_mileage)
    local bookmark = unit.GetStringVar(csvar.shop_bookmark)
    unit.FireEvent("Shop_SendData", strHaveItemCount, strLimitData, payCube, gainMileage, bookmark, isFirst)
end


--* 한정 구입 초기화를 체크합니다.
function gShop:CheckResetLimit(unit, targetCode)
    local strLimitData = unit.GetStringVar( csvar.limit_shop )
    local limitData = dejson(strLimitData)
    local nowDate = GetDate( os.time() + 3600*9 )

    local isChange = false 
    for code, data in pairs(limitData) do
        if (not targetCode) or (code == targetCode) then
            local sdata = GameData.shop.list[code]
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
        unit.SetStringVar(csvar.limit_shop, afterStrLimitData)
        return isChange, limitData[targetCode]
    end

    return isChange, limitData[targetCode]
end


--* 한정 데이터를 추가합니다.
function gShop:AddLimit(unit, shopCode, buyCount)
    local data = GameData.shop.list[shopCode]
    if not (data and data.limit) then return  end
    local limitData = dejson( unit.GetStringVar( csvar.limit_shop ) )
    local limit = limitData[shopCode] or {}
    limit.count = limit.count and (limit.count + buyCount) or buyCount
    limit.lastDate = GetDate( os.time() + 3600*9 )
    limit.deleteDate = data.limit.deleteDate or nil
    limitData[shopCode] = limit
    unit.SetStringVar(csvar.limit_shop, injson(limitData))
    return limit
end


--* 한정 데이터를 확인 후 횟수가 남아있는 지 확인합니다.
function gShop:IsOKLimit(unit, code)
    local data = GameData.shop.list[code]
    if not data then
        ShowErrMsg(unit, "존재하지 않는 상품입니다.\n관리자에게 문의해주세요.")
        return false
    end
    if not data.limit then
        return true
    end
    local limitData = dejson( unit.GetStringVar( csvar.limit_shop ) )
    local nowCount = limitData[code] and limitData[code].count or 0
    local maxCount = data.limit.count
    if nowCount >= maxCount then
        ShowErrMsg(unit, "최대 구입 가능 개수를 초과하였습니다.")
        return false
    end
    return true
end


--* 아이템을 구입합니다.
function gShop:Buy(unit, shopCode, buyCount)
    if not (unit and shopCode and buyCount and CheckUserSystemDelay(unit)) then return  end
    local data = GameData.shop.list[shopCode]
    if not data then return end

    local buyCount = math.rounddown(buyCount)

    local targetItemDataID = data.target.dataID
    local targetItemName = GetItemName(targetItemDataID)
    local targetItemCount = (data.target.count or 1) * buyCount
    local targetItemLevel = data.target.level or 0

    local needItemDataID = data.price.dataID
    local needItemName = GetItemName(needItemDataID)
    local needItemCount = (data.price.count or 1) * buyCount

    local haveItemCount = CountItem(unit, needItemDataID)
    
    local isChangeLimitData, nowUserLimitData = gShop:CheckResetLimit(unit, shopCode)
    local remainingLimitCount = data.limit and (data.limit.count - (nowUserLimitData and nowUserLimitData.count or 0)) or self.maxBuyCount
    local maxBuyCount = math.min( data.oneTimeMaxCount or self.maxBuyCount, remainingLimitCount )

    if isChangeLimitData then
        ShowErrMsg(unit, "한정 구입 정보가 갱신되었습니다.\n잠시 후 다시 시도해주세요.")
        gShop:SendData(unit)
        unit.FireEvent("Shop_BuyUIDestroy")
        return
    end

    if data.period then
        local nowDate = GetDate( os.time() + 3600*9 )
        local startDate = data.period.startDate or 0
        local endDate = data.period.endDate or 20991231
        if not (startDate <= nowDate and nowDate <= endDate) then
            ShowErrMsg(unit, "지금은 구입할 수 없는 상품입니다.")
            return
        end
    end

    if buyCount <= 0 then
        ShowWrongRequestMsg(unit)
        return
    end

    if maxBuyCount < buyCount then
        ShowErrMsg(unit, "최대 구입 가능 개수를 초과하였습니다.")
        return
    end

    if data.reqLevel and data.reqLevel > unit.level then
        ShowReqLevelMsg(unit, data.reqLevel)
        return
    end

    if common.moneyName[needItemDataID] == "cube" then -- 큐브 아이템
        unit.StartGlobalEvent(data.eventNum)
        return 
    end

    if haveItemCount < needItemCount then
        ShowErrMsg(unit, "구입에 필요한 <color=" .. cc.white .. ">" .. needItemName .. "</color>이(가) 부족합니다.")
        return
    end

    if data.func then
        if not data.func(unit, buyCount) then return end
        RemoveItem(unit, needItemDataID, needItemCount)
    else
        RemoveItem(unit, needItemDataID, needItemCount)
        if targetItemLevel == 0 then AddItem(unit, targetItemDataID, targetItemCount)
        else AddItemByTItem(unit, { dataID = targetItemDataID, count = targetItemCount, level = targetItemLevel })
        end
        ShowBuyItemMsg(unit, targetItemDataID, targetItemCount, targetItemLevel)
        PlaySE(unit, cse.coin)
    end

    local bonusItemDataID, bonusItemName, bonusItemCount
    if data.bonus then
        bonusItemDataID = data.bonus[1]
        bonusItemName = GetItemName(bonusItemDataID)
        bonusItemCount = (data.bonus[2]) * buyCount
        AddItem(unit, bonusItemDataID, bonusItemCount)
        Server.RunLater(function() ShowMsg(unit, bonusItemName .. " " .. bonusItemCount .. "개 보너스 지급!") end, 1)
    end

    local afterUserLimitData = gShop:AddLimit(unit, shopCode, buyCount)

    gShop:SendData(unit)
    unit.FireEvent("Shop_BuyUIDestroy")

    local logTitle = "Shop_Buy"
    local logMsg = "[" .. shopCode .. "] " .. targetItemName .. " x" .. targetItemCount .. " Buy"
    local logData = {
        shopCode = shopCode,
        buyCount = buyCount,
        target = {
            name = targetItemName,
            dataID = targetItemDataID,
            level = targetItemLevel,
            count = targetItemCount / buyCount,
            sumCount = targetItemCount,
        },
        need = {
            name = needItemName,
            dataID = needItemDataID,
            count = needItemCount / buyCount,
            sumCount = needItemCount,
            haveCount = haveItemCount,
        },
        userLimitData = afterUserLimitData,
    }

    if data.bonus then
        logData.bonus = {
            name = bonusItemName,
            dataID = bonusItemDataID,
            count = bonusItemCount / buyCount,
            sumCount = bonusItemCount,
        }
    end

    SendLog(unit, logTitle, logMsg, logData)

    if needItemDataID == ttt.itemDataID then
        ttt:RecordUseTokenData(unit, needItemCount)
    end

    SetUserSystemDelay(unit)
end


--* 큐브아이템 구입 성공 처리합니다.
function gShop:BuyCubeItem(unit, shopCode)
    local data = GameData.shop.list[shopCode]

    local buyCount = 1

    local targetItemDataID = data.target.dataID
    local targetItemName = GetItemName(targetItemDataID)
    local targetItemCount = (data.target.count or 1) * buyCount
    local targetItemLevel = data.target.level or 0

    local needItemDataID = data.price.dataID
    local needItemName = GetItemName(needItemDataID)
    local needItemCount = (data.price.count or 1) * buyCount

    if data.func then
        data.func(unit, 1)
    else
        if targetItemLevel == 0 then AddItem(unit, targetItemDataID, targetItemCount)
        else AddItemByTItem(unit, { dataID = targetItemDataID, count = targetItemCount, level = targetItemLevel })
        end
        ShowBuyItemMsg(unit, targetItemDataID, targetItemCount, targetItemLevel)
        PlaySE(unit, cse.coin)
    end

    local afterUserLimitData = gShop:AddLimit(unit, shopCode, buyCount)

    gShop:SendData(unit)
    unit.FireEvent("Shop_BuyUIDestroy")

    local logTitle = "Shop_Buy_Cube"
    local logMsg = "[" .. shopCode .. "] " .. targetItemName .. " x" .. targetItemCount .. " Buy"
    local logData = {
        shopCode = shopCode,
        buyCount = buyCount,
        target = {
            name = targetItemName,
            dataID = targetItemDataID,
            level = targetItemLevel,
            count = targetItemCount,
        },
        need = {
            name = needItemName,
            dataID = needItemDataID,
            count = needItemCount,
        },
        userLimitData = afterUserLimitData,
    }
    SendLog(unit, logTitle, logMsg, logData)

    SetUserSystemDelay(unit)
end


--* 마일리지를 획득합니다.
function gShop:GetMileage(unit)
    if not (unit and CheckUserSystemDelay(unit)) then return  end
    local payCube = unit.GetVar(cvar.payCube)
    local gainMileage = unit.GetVar(cvar.gain_mileage)
    local maxMileage = payCube * self.mileagePer/100
    local targetMileage = math.rounddown(maxMileage - gainMileage)

    if targetMileage <= 0 then
        ShowMsg("획득 가능한 마일리지가 없습니다.\n<color=" .. cc.yellowLight .. "><size=14>큐브상품 구입 시 큐브의 10% 만큼 획득이 가능합니다.</size></color>")
        return
    end

    unit.SetVar(cvar.gain_mileage, gainMileage + targetMileage)
    AddItem(unit, self.mileageItemID, targetMileage)
    ShowAddItemMsg(unit, self.mileageItemID, targetMileage)
    ShowItemPopup(unit, { [tostring(self.mileageItemID)] = targetMileage })
    PlaySE(unit, cse.signal)

    gShop:SendData(unit)
    local logTitle = "Shop_GetMileage"
    local logMsg = targetMileage
    local logData = { payCube = payCube, gainMileage = gainMileage, maxMileage = maxMileage, targetMileage = targetMileage }
    SendLog(unit, logTitle, logMsg, logData)
    SetUserSystemDelay(unit)
end



--* 사라진 즐겨찾기가 있는지 체크합니다.
function gShop:CheckBookmark(unit)
    local var = dejson(unit.GetStringVar(csvar.shop_bookmark))
    local isChanged = false
    for i, code in pairs(var) do
        local db = self.db.list[targetCode]
        if not db then
            isChanged = true
            var[code] = nil
        end
    end
    if isChanged then
        unit.SetStringVar(csvar.shop_bookmark, injson(var))
    end
end



--* 새롭게 즐겨찾기를 등록합니다.
function gShop:AddBookmark(unit, targetCode)
    if not (unit and targetCode and CheckUserSystemDelay(unit)) then return end
    local db = self.db.list[targetCode]
    if not db then return end
    local var = dejson(unit.GetStringVar(csvar.shop_bookmark))
    if #var >= 20 then
        ShowErrMsg(unit, "즐겨찾기는 최대 20개까지만 등록이 가능합니다.")
        return
    end
    for i, code in pairs(var) do
        if code == targetCode then
            ShowErrMsg(unit, "이미 즐겨찾기에 추가된 항목입니다.")
            return
        end
    end
    table.insert(var, targetCode)
    unit.SetStringVar(csvar.shop_bookmark, injson(var))
    gShop:SendData(unit)
    SetUserSystemDelay(unit)
end


--* 즐겨찾기를 등록해제합니다.
function gShop:RemoveBookmark(unit, targetCode)
    if not (unit and targetCode and CheckUserSystemDelay(unit)) then return end
    local db = self.db.list[targetCode]
    if not db then return end
    local var = dejson(unit.GetStringVar(csvar.shop_bookmark))
    local pos = -1
    for i, code in pairs(var) do
        if code == targetCode then
            pos = i
        end
    end
    if pos == -1 then
        ShowWrongRequestMsg(unit)
        return
    end
    table.remove(var, pos)
    unit.SetStringVar(csvar.shop_bookmark, injson(var))
    gShop:SendData(unit)
    SetUserSystemDelay(unit)
end


--* 즐겨찾기를 초기화합니다.
function gShop:ResetBookmark(unit)
    if not (unit and CheckUserSystemDelay(unit)) then return end
    unit.SetStringVar(csvar.shop_bookmark, injson({}))
    ShowMsg(unit, "모든 즐겨찾기가 초기화되었습니다.")
    gShop:SendData(unit)
    SetUserSystemDelay(unit)
end





