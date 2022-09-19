--------------------------------------------------------------------------------
-- Server Exchange
--------------------------------------------------------------------------------

gExchange = {}
gExchange.db = GameData.exchange

gExchange.itemList = {}
gExchange.strItemList = injson({})

Server.GetTopic("Exchange_GetItemListData").Add(function(...) gExchange:SendItemListData(unit, ...) end)
Server.GetTopic("Exchange_GetMyItemListData").Add(function(...) gExchange:SendMyItemListData(unit, ...) end)
Server.GetTopic("Exchange_GetMyLogData").Add(function(...) gExchange:SendMyLogData(unit, ...) end)
Server.GetTopic("Exchange_RegMyItem").Add(function(...) gExchange:RegMyItem(unit, ...) end)
Server.GetTopic("Exchange_UnregMyItem").Add(function(...) gExchange:UnregMyItem(unit, ...) end)
Server.GetTopic("Exchange_CalMyItem").Add(function(...) gExchange:CalMyItem(unit, ...) end)
Server.GetTopic("Exchange_BuyItem").Add(function(...) gExchange:BuyItem(unit, ...) end)


--* 거래소 이용 딜레이를 가져옵니다.
function GetUserExchangeDelay(unit)
    return unit.GetVar(cvar.exchangeDelay)
end


--* 거래소 이용 딜레이를 추가합니다.
function SetUserExchangeDelay(unit)
    local saveNum = GetTimeStamp() * 100 -- 유저 변수는 정수만 저장되기에 100배율 저장
    unit.SetVar(cvar.exchangeDelay, saveNum)
end


--* 거래소 이용 딜레이를 확인 후 가능/불가 여부를 반환합니다.
function CheckUserExchangeDelay(unit, notify, count)
    local notify = notify ~= false and true or false
    local lastTime = GetUserExchangeDelay(unit)/100 + (count or gExchange.db.delay)
    local nowTime = GetTimeStamp()
    local pass = lastTime < nowTime and true or false
    if (not pass) and notify then
        ShowErrMsg(unit, "거래소 이용 대기 시간이 적용중입니다.\n" .. math.roundup(lastTime - nowTime) .. "초 후 다시 시도해주세요.")
    end
    return pass
end


--* 거래소에 등록 가능한 아이템인지 판단합니다.
function IsCanRegExchange(item)
    local canTrade = (Server.GetItem(item.dataID).canTrade or gExchange.db.expCanTrade[item.dataID])
    if gExchange.db.expCannotTrade[item.dataID] then canTrade = false end
    return canTrade and true or false
end


--* 거래소에 등록 가능한 아이템인지 판단합니다. (유닛의 장착 여부도 판단)
function IsCanRegExchangeByUnit(unit, item)
    local canTrade = (Server.GetItem(item.dataID).canTrade or gExchange.db.expCanTrade[item.dataID])
    if gExchange.db.expCannotTrade[item.dataID] then canTrade = false end
    return (canTrade and (not unit.IsEquippedItem(item.id))) and true or false
end


--* 거래소에 등록 가능한 table 형태로 저장해 반환합니다.
function GetCanExchangeBagItems(unit)
    local itemList = {}
    for i, item in pairs(unit.player.GetItems()) do
        if IsCanRegExchangeByUnit(unit, item) then
            itemList[tostring(item.id)] = ItemToTable(item)
        end
    end
    return itemList
end


--* 거래소 목록을 업데이트 합니다.
function gExchange:Update()
    local nowTs = GetTimeStamp()
    local list = {}
    local num = 0
    for _, player in pairs(Server.players) do
        local unit = player.unit
        local unitsItemList = dejson( unit.GetStringVar( csvar.exchange_items ) )
        if table.len(unitsItemList) > 0 then
            for _, data in pairs(unitsItemList) do
                if (not data.selled) and (data.ts+50 <= nowTs) and IsCanRegExchange(data.item) then
                    num = num + 1
                    list[tostring(num)] = data
                end
            end
        end 
    end
    self.itemList = list
    self.strItemList = injson(list)
end
ontick.Add(function() gExchange:Update() end, 10, 8)


--* 거래소 데이터 전송 : 거래소 아이템 리스트
function gExchange:SendItemListData(unit, onlyUpdate)
    unit.FireEvent("Exchange_SendData_ItemList", onlyUpdate, self.strItemList)
end


--* 거래소 데이터 전송 : 내 아이템 리스트
function gExchange:SendMyItemListData(unit, onlySellItem, needScroll)
    local strMyItemList = unit.GetStringVar( csvar.exchange_items )
    local bag = (not onlySellItem) and GetCanExchangeBagItems(unit) or nil
    unit.FireEvent("Exchange_SendData_MyItemList", needScroll, strMyItemList, bag and injson(bag) or nil)
end


--* 거래소 데이터 전송 : 구입/판매 기록 리스트
function gExchange:SendMyLogData(unit)
    local strMyLog = unit.GetStringVar( csvar.exchange_logs )
    unit.FireEvent("Exchange_SendData_MyLog", strMyLog)
end


--* 내 아이템 관리 : 아이템을 판매란에 등록합니다.
function gExchange:RegMyItem(unit, strItem, targetCount, price)
    if not (unit and strItem and targetCount and price and CheckUserSystemDelay(unit)) then return end
    if not CheckUserExchangeDelay(unit) then return end
    if unit.level < self.db.reqLevel.sell then ShowReqLevelMsg(unit, self.db.reqLevel.sell) return end

    local myItemList = dejson( unit.GetStringVar( csvar.exchange_items ) )

    local citem = dejson(strItem)
    local item = unit.player.GetItem(citem.id)
    local targetCount = math.rounddown(targetCount)
    local price = math.max(1, math.rounddown(price))
    local maxSlotCount = self.db.maxSlotCount + (unit.HasBuff(7) and 10 or 0)

    if (not item)
    or (table.len(myItemList) >= maxSlotCount) 
    or (not IsCanRegExchange(item))
    or (not (self.db.minPrice <= price and price <= self.db.maxPrice))
    or (item.dataID ~= citem.dataID) 
    or (item.level ~= citem.level) 
    or (not (1 <= targetCount and targetCount <= item.count))
    or unit.IsEquippedItem(item.id) then
        ShowWrongRequestMsg(unit)
        gExchange:SendMyItemListData(unit)
        return
    end

    local haveGold = CountGold(unit)
    local needGold = self.db.regGold
    if needGold > haveGold then
        ShowErrMsg("등록에 필요한 골드가 부족합니다.")
        return
    end

    local itemName = GetItemName(item)

    local titem = ItemToTable(item)
    titem.id = rand(1, 1000000+1)
    titem.count = targetCount
    local slot = { id = unit.player.id, selled = false, item = titem, price = price, ts = math.rounddown(GetTimeStamp()) }
    table.insert( myItemList, slot )

    local strMyItemList = injson(myItemList)
    if not unit.SetStringVar( csvar.exchange_items, strMyItemList ) then return end
    RemoveGold(unit, 500)
    unit.RemoveItemByID(item.id, targetCount, false)
    gExchange:SendMyItemListData(unit, nil, true)
    ShowMsg(unit, "등록 성공")
    PlaySE(unit, cse.signal)
    unit.FireEvent("Exchange_RegUI_Destroy")

    local logMsg = itemName .. " x" .. targetCount .. " (" .. math.comma(price) .. " gold)"
    local logData = {
        item = citem, targetCount = targetCount, price = price,
        slot = slot, afterItemList = myItemList, needGold = needGold, haveGold = haveGold
    }
    SendLog(unit, "Exchange_RegItem", logMsg, injson(logData))
    SetUserSystemDelay(unit)
    SetUserExchangeDelay(unit)
end


--* 내 아이템 관리 : 등록된 아이템을 다시 회수합니다. 
function gExchange:UnregMyItem(unit, num, strSlot)
    if not (unit and num and strSlot and CheckUserSystemDelay(unit)) then return end

    local myItemList = dejson( unit.GetStringVar( csvar.exchange_items ) )
    local cSlot = dejson(strSlot)
    local slot = myItemList[num]

    if (not slot) or cSlot.item.id ~= slot.item.id or slot.sell then
        ShowErrMsg(unit, "아이템의 판매 상태가 변경되었습니다.\n다시 시도해주세요.")
        gExchange:SendMyItemListData(unit, true)
        return
    end

    local itemName = GetItemName(slot.item)

    table.remove( myItemList, num )
    local strMyItemList = injson(myItemList)
    if not unit.SetStringVar( csvar.exchange_items, strMyItemList ) then return end
    AddItemByTItem(unit, slot.item, true)
    gExchange:SendMyItemListData(unit)
    ShowMsg(unit, "등록 취소 성공")
    PlaySE(unit, cse.signal)

    local logMsg = itemName .. " x" .. slot.item.count .. " (" .. math.comma(slot.price) .. " gold)"
    local logData = { slot = slot, afterItemList = myItemList }
    SendLog(unit, "Exchange_UnregItem", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end


--* 내 아이템 관리 : 판매된 아이템을 모두 정산합니다.
function gExchange:CalMyItem(unit, strSlots)
    if not (unit and strSlots and CheckUserSystemDelay(unit)) then return end

    local cItemList = dejson( strSlots )
    local strBeforeItemList = unit.GetStringVar( csvar.exchange_items )
    local myItemList = dejson( strBeforeItemList )

    local sellCount, sumGold, sumFee = 0, 0, 0
    for i = table.len(myItemList), 1, -1 do
        local slot = myItemList[i]
        local cslot = cItemList[i]

        if not (slot and cslot and cslot.item.id == slot.item.id and cslot.price == slot.price and cslot.selled == slot.selled) then
            ShowErrMsg(unit, "아이템의 판매 상태가 변경되었습니다.\n다시 시도해주세요.")
            gExchange:SendMyItemListData(unit, true)
            return
        end

        if slot and slot.selled then
            sellCount = sellCount + 1
            sumGold = sumGold + slot.price
            sumFee = sumFee + math.roundup( slot.price * self.db.fee / 100 )
            table.remove(myItemList, i)
        end
    end
    local targetGold = sumGold - sumFee

    if sellCount <= 0 then
        ShowErrMsg(unit, "판매된 아이템이 없습니다.")
        return
    end

    local strMyItemList = injson(myItemList)
    if not unit.SetStringVar( csvar.exchange_items, strMyItemList ) then return end

    AddGold(unit, targetGold)
    ShowMsg(unit, "<color=" .. cc.green .. ">정산 성공</color>\n수수료 제외 " .. math.comma(targetGold) .. " 골드 지급")
    PlaySE(unit, cse.shop)
    gExchange:SendMyItemListData(unit, true)

    local logMsg = sellCount .. " slot, sum " .. math.comma(sumGold) .. " gold (fee " ..  math.comma(sumFee) .. " gold)"
    local logData = { 
        sellCount = sellCount, sumGold = sumGold, sumFee = sumFee, targetGold = targetGold,
        beforeItemList = dejson(strBeforeItemList), afterItemList = myItemList,
    }
    SendLog(unit, "Exchange_Calculation", logMsg, injson(logData))
    SetUserSystemDelay(unit)

    Server.SetWorldVar(cwvar.exchange_fee, Server.GetWorldVar(cwvar.exchange_fee) + sumFee)
end


--* 거래소에서 아이템을 구입합니다.
function gExchange:BuyItem(unit, strSlot)
    if not (unit and strSlot and CheckUserSystemDelay(unit)) then return end
    if not CheckUserExchangeDelay(unit) then return end
    if unit.level < self.db.reqLevel.buy then ShowReqLevelMsg(unit, self.db.reqLevel.buy) return end
    if CheckBagFull(unit, true) then return end

    local cSlot = dejson(strSlot)
    local cItem = cSlot.item

    local targetUnit = GetPlayerUnit(cSlot.id)
    if not targetUnit then 
        ShowErrMsg(unit, "이 아이템은 이제 구입할 수 없습니다.")
        gExchange:SendItemListData(unit, true)
        return
    end

    local myLogList = dejson( unit.GetStringVar( csvar.exchange_logs ) )
    local targetLogList = dejson( targetUnit.GetStringVar( csvar.exchange_logs ) )
    local targetItemList = dejson( targetUnit.GetStringVar( csvar.exchange_items ) )
    local pos = nil
    for i, slot in pairs(targetItemList) do
        if slot.item.id == cSlot.item.id and slot.item.dataID == cSlot.item.dataID and slot.price == cSlot.price and slot.selled == cSlot.selled then
            pos = i
            break
        end
    end

    if not pos then 
        ShowErrMsg(unit, "이 아이템은 이제 구입할 수 없습니다.")
        gExchange:SendItemListData(unit, true)
        return
    end

    local slot = targetItemList[pos]
    local needGold = slot.price
    local haveGold = CountGold(unit)
    local itemName = GetItemName(slot.item)

    if needGold > haveGold then
        ShowErrMsg(unit, "구입에 필요한 골드가 부족합니다.")
        return
    end

    local ts = math.rounddown( GetTimeStamp() )
    slot.selled = ts

    local strTargetItemList = injson(targetItemList)
    if not targetUnit.SetStringVar( csvar.exchange_items, strTargetItemList ) then return end

    RemoveGold(unit, needGold)
    AddItemByTItem(unit, slot.item, true)

    PlaySE(unit, cse.shop)
    ShowMsg(unit, "구입 성공")
    Chat(targetUnit, "[#] 거래소에 등록된 " .. itemName .. " 아이템이 판매되었습니다.", cc.yellowLight)
    unit.FireEvent("Exchange_BuyUI_Destroy")
    
    local logMsg = "BUY ".. itemName .. " x" .. slot.item.count .. " (" .. math.comma(needGold) .." gold)"
    local logData = { slot = slot, needGold = needGold, haveGold = haveGold, }
    SendLog(unit, "Exchange_Buy", logMsg, injson(logData))

    local ulogMsg = "SELL ".. itemName .. " x" .. slot.item.count .. " (" .. math.comma(needGold) .. "gold)"
    local ulogData = { slot = slot, afterItemList = targetItemList }
    SendLog(targetUnit, "Exchange_Sell", ulogMsg, injson(ulogData))

    table.insert(myLogList, { type = 1, ts = ts, data = slot })
    if #myLogList > 50 then table.remove(myLogList, 1) end
    table.insert(targetLogList, { type = 2, ts = ts, data = slot })
    if #targetLogList > 50 then table.remove(targetLogList, 1) end
    local strMyLogList = injson(myLogList)
    local strTargetLogList = injson(targetLogList)
    unit.SetStringVar( csvar.exchange_logs, strMyLogList )
    targetUnit.SetStringVar( csvar.exchange_logs, strTargetLogList )

    for strI, sData in pairs(self.itemList) do
        if sData.item.id == slot.item.id and sData.item.dataID == slot.item.dataID and sData.price == slot.price then
            sData.selled = ts
            break
        end 
    end
    self.strItemList = injson(self.itemList)
    gExchange:SendItemListData(unit, true)

    SetUserSystemDelay(unit)
    SetUserExchangeDelay(unit)
end









