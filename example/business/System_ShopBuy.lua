--------------------------------------------------------------------------------
-- Server Buy Shop
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- BuyShop_Sell
--------------------------------------------------------------------------------

gBuyShop = {}

Server.GetTopic("BuyShop_GetData").Add(function() gBuyShop:SendData(unit) end)
Server.GetTopic("BuyShop_Sell").Add(function(...) gBuyShop:Sell(unit, ...) end)


--* 클라이언트로 판매가 가능한 아이템 데이터를 전송합니다.
function gBuyShop:SendData(unit)
    local data = {}
    for _, item in pairs(unit.player.GetItems()) do
        local itemData = GetItemData(item)
        if itemData.sellPrice and (not unit.IsEquippedItem(item.id)) then
            data[tostring(item.id)] = ItemToTable(item)
        end
    end
    unit.FireEvent("BuyShop_SendData", injson(data))
end


--* 아이템을 판매합니다.
function gBuyShop:Sell(unit, itemID, sellCount)
    if not (unit and itemID and sellCount and CheckUserSystemDelay(unit)) then return  end
    local item = unit.player.GetItem(tonumber(itemID))
    local itemData = GetItemData(item)
    local sellCount = math.rounddown(sellCount)
    if not (item and itemData and itemData.sellPrice) then return end

    if item.count < sellCount or sellCount <= 0 then
        ShowWrongRequestMsg(unit)
        gBuyShop:SendData(unit)
        return 
    end

    local titem = ItemToTable(item)
    local itemName = GetItemName(item)
    local price = itemData.sellPrice
    local sumPrice = price * sellCount

    unit.RemoveItemByID(item.id, sellCount, false)
    ShowSellItemMsg(unit, titem.dataID, sellCount)
    AddGold(unit, sumPrice)
    PlaySE(unit, cse.coin)

    unit.FireEvent("BuyShop_SellUIDestroy")
    unit.FireEvent("BuyShop_SellItem", itemID, sellCount)

    local logTitle = "BuyShop_Sell"
    local logMsg = itemName .. " x" .. sellCount .. " Sell ( Gain " .. math.comma(sumPrice) .. " Gold )"
    local logData = {
        item = titem,
        price = price,
        sumPrice = sumPrice,
        afterGold = CountGold(unit), 
    }
    SendLog(unit, logTitle, logMsg, logData)

    SetUserSystemDelay(unit)
end


