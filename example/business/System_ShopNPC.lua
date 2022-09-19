--------------------------------------------------------------------------------
-- Server NPC Shop
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- NPCShop_Buy
--------------------------------------------------------------------------------

gNPCShop = {}
gNPCShop.maxBuyCount = 999

Server.GetTopic("NPCShop_GetData").Add(function() gNPCShop:SendData(unit) end)
Server.GetTopic("NPCShop_Buy").Add(function(itemCode, buyCount) gNPCShop:Buy(unit, itemCode, buyCount) end)


--* 특정 NPC Shop을 Open 합니다.
function ShowNPCShop(unit, shopCode, shopName)
    unit.FireEvent("ShowNPCShop", shopCode, shopName)
end


--* 클라이언트로 한정구입, 보유재화 데이터를 전송합니다.
function gNPCShop:SendData(unit)
    gNPCShop:CheckResetLimit(unit)
    local strHaveItemCount = injson( GetBagItemsByCount(unit) )
    local strLimitData = unit.GetStringVar( csvar.limit_npcShop )
    unit.FireEvent("NPCShop_SendData", strHaveItemCount, strLimitData)
end


--* 한정 구입 초기화를 체크합니다.
function gNPCShop:CheckResetLimit(unit, targetCode)
    local strLimitData = unit.GetStringVar( csvar.limit_npcShop )
    local limitData = dejson(strLimitData)
    local nowDate = GetDate( os.time() + 3600*9 )

    local isChange = false 
    for code, data in pairs(limitData) do
        if (not targetCode) or (code == targetCode) then
            local sdata = GameData.npcShop.list[code]
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
        unit.SetStringVar(csvar.limit_npcShop, afterStrLimitData)
        return isChange, limitData[targetCode]
    end

    return isChange, limitData[targetCode]
end


--* 한정 데이터를 추가합니다.
function gNPCShop:AddLimit(unit, itemCode, buyCount)
    local data = GameData.npcShop.list[itemCode]
    if not (data and data.limit) then return end

    local limitData = dejson( unit.GetStringVar( csvar.limit_npcShop ) )

    local limit = limitData[itemCode] or {}
    limit.count = limit.count and (limit.count + buyCount) or buyCount
    limit.lastDate = GetDate( os.time() + 3600*9 )
    limit.deleteDate = data.limit.deleteDate or nil
    limitData[itemCode] = limit

    unit.SetStringVar(csvar.limit_npcShop, injson(limitData))

    return limit
end


--* 아이템을 구입합니다.
function gNPCShop:Buy(unit, itemCode, buyCount)
    if not (unit and itemCode and buyCount and CheckUserSystemDelay(unit)) then return  end
    local data = GameData.npcShop.list[itemCode]
    if not data then return  end

    local buyCount = math.rounddown(buyCount)

    local targetItemDataID = data.target.dataID
    local targetItemName = GetItemName(targetItemDataID)
    local targetItemCount = (data.target.count or 1) * buyCount
    local targetItemLevel = data.target.level or 0
    local itemData = GetItemData(targetItemDataID) or {}

    local needItemDataID = data.price.dataID
    local needItemName = GetItemName(needItemDataID)
    local needItemCount = (data.price.count or 1) * buyCount

    local haveItemCount = CountItem(unit, needItemDataID)
    
    local serverMaxBuyCount = itemData.type == 4 and 9999 or self.maxBuyCount
    local isChangeLimitData, nowUserLimitData = gNPCShop:CheckResetLimit(unit, itemCode)
    local remainingLimitCount = data.limit and (data.limit.count - (nowUserLimitData and nowUserLimitData.count or 0)) or serverMaxBuyCount
    local maxBuyCount = math.min( data.oneTimeMaxCount or serverMaxBuyCount, remainingLimitCount )

    if isChangeLimitData then
        ShowErrMsg(unit, "한정 구입 정보가 갱신되었습니다.\n잠시 후 다시 시도해주세요.")
        gNPCShop:SendData(unit)
        unit.FireEvent("NPCShop_BuyUIDestroy")
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

    if haveItemCount < needItemCount then
        ShowErrMsg(unit, "구입에 필요한 <color=" .. cc.white .. ">" .. needItemName .. "</color>이(가) 부족합니다.")
        return
    end

    local afterUserLimitData = gNPCShop:AddLimit(unit, itemCode, buyCount)
    
    RemoveItem(unit, needItemDataID, needItemCount)
    if targetItemLevel == 0 then
        AddItem(unit, targetItemDataID, targetItemCount)
    else
        AddItemByTItem(unit, { dataID = targetItemDataID, count = targetItemCount, level = targetItemLevel })
    end
    ShowBuyItemMsg(unit, targetItemDataID, targetItemCount, targetItemLevel)
    PlaySE(unit, cse.coin)

    gNPCShop:SendData(unit)
    unit.FireEvent("NPCShop_BuyUIDestroy")

    local logTitle = "NPCShop_Buy"
    local logMsg = "[" .. itemCode .. "] " .. targetItemName .. " x" .. targetItemCount .. " Buy"
    local logData = {
        itemCode = itemCode,
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
    SendLog(unit, logTitle, logMsg, logData)

    SetUserSystemDelay(unit)
end








