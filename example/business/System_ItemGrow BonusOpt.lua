--------------------------------------------------------------------------------
-- Server Equipment Bonus Option
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- BonusOption_Change
--------------------------------------------------------------------------------

gBonusOption = {}
gBonusOption.db = GameData.option.bonusOption

Server.GetTopic("BonusOption_GetData").Add(function() gBonusOption:SendData(unit) end)
Server.GetTopic("BonusOption_Change").Add(function(...) gBonusOption:Change(unit, ...) end)


--* 아이템 수준에 따른 랜덤옵션을 추출하여 반환합니다.
local function __CreateBonusOption(itemLevel)
    local option = {}
    local db = gBonusOption.db
    local sumValueRatio = math.sum(db.ratioValuePer)

    local statID = 6
    do -- statID 결정
        local targetRatio = rand(1, math.sum(db.ratioStatID) + 1)
        local nowRatio = 0 
        for id, ratio in pairs(db.ratioStatID) do
            nowRatio = nowRatio + ratio
            if targetRatio <= nowRatio then
                statID = id
                break
            end
        end
    end

    local valuePer = 0
    do -- valuePer 결정
        local targetRatio = rand(1, sumValueRatio + 1)
        local nowRatio = 0 
        for vp, ratio in pairs(db.ratioValuePer) do
            nowRatio = nowRatio + ratio
            if targetRatio <= nowRatio then
                valuePer = rand( (vp-1)*10 + 1 , vp*10  +1)
                break
            end
        end
    end

    -- value 결정
    local w = GetW(itemLevel, statID)
    local baseValue = w / 20
    local value = math.round(baseValue*0.2 + baseValue*valuePer/100)
    value = math.max( value, 1 )

    local option = { type = 0, statID = statID, value = value }
    return option
end


--* 장비 아이템 획득 시 보너스 옵션 3줄을 부여합니다.
function gBonusOption.AddNewBonusOption(unit, item)
    if #item.options > 0 then return end
    local itemData = GetItemData(item)
    if not itemData.canBonusOption then return end
    local itemLevel = itemData.itemLevel
    for i=1, 3 do
        local option = __CreateBonusOption(itemLevel)
        Utility.AddItemOption(item, 0, option.statID, option.value)
    end
    unit.player.SendItemUpdated(item)
end
for dataID, data in pairs(GameData.item) do
    if data.canBonusOption then
        gAddItem.func[dataID] = gBonusOption.AddNewBonusOption
    end
end


--* 클라이언트로 보유재화 및 보너스옵션 변경가능 아이템을 전송합니다.
function gBonusOption:SendData(unit)
    local countBag = GetBagItemsByCount(unit)
    local items = {}
    for _, item in pairs(unit.player.GetItems()) do
        local itemData = GetItemData(item)
        if itemData and itemData.canBonusOption then
            local strID = tostring(item.id)
            items[strID] = ItemToTable(item)
            items[strID].isEquipped = unit.IsEquippedItem(item.id)
        end
    end
    unit.FireEvent("BonusOption_SendData", injson(countBag), injson(items))
end


--* 선택한 장비의 보너스 옵션을 교체합니다.
function gBonusOption:Change(unit, strTItem, useAssist)
    if (not (unit and strTItem)) or (not CheckUserSystemDelay(unit)) then
        return
    end

    local citem = dejson(strTItem)
    local item = unit.player.GetItem(citem.id)
    local itemData = GetItemData(item)
    local cdb = itemData.canBonusOption

    if not (item and cdb and item.dataID == citem.dataID and item.level == citem.level) then
        ShowWrongRequestMsg(unit)
        gBonusOption:SendData(unit)
        return
    end

    if useAssist and itemData.rarity < 5 then
        ShowErrMsg(unit, "전설등급 이상의 장비에만\n변경보조석을 함께 사용할 수 있습니다.")
        return
    end

    local w = useAssist and ( itemData.rarity == 5 and 0.3 or (itemData.rarity == 6 and 0.5 or 0) ) or 0

    local itemName = GetItemName(item)

    local needItemID = cdb.item[1] 
    local needItemCount = math.rounddown(cdb.item[2] * (1 - w))
    local needGold = math.rounddown(cdb.gold and (cdb.gold * (1 - w)) or 0)
    local haveItemCount, haveItemLog = CountItem(unit, needItemID, true)
    local haveGold = CountGold(unit)
    local needAssistDataID = {1617, 1618}
    local needAssistCount = useAssist and 1 or 0
    local haveAssistCount, haveAssistLog = CountItem(unit, needAssistDataID, true)

    if not (needItemCount <= haveItemCount and needGold <= haveGold and needAssistCount <= haveAssistCount) then
        ShowLackMsg(unit, "옵션 변경")
        return
    end

    RemoveGold(unit, needGold)
    local useItemLog = RemoveItem(unit, needItemID, needItemCount, true)
    local useAssistLog
    if useAssist then
        useAssistLog = RemoveItem(unit, needAssistDataID, needAssistCount, true)
    end

    local itemLevel = itemData.itemLevel or 0 
    local beforeOptions = {citem.options[1], citem.options[2], citem.options[3]}
    local afterOptions = {}
    local highOption = false
    for i=1, 3 do
        local o = __CreateBonusOption(itemLevel)
        afterOptions[i] = o
        item.options[i].statID = o.statID
        item.options[i].value = o.value
        local maxValue = math.max(1, math.round( GetW(itemLevel, o.statID) / 20 * 1.2 ))
        if highOption == false then
            highOption = (maxValue * 0.8) <= o.value and true or false
        end
    end
    unit.player.SendItemUpdated(item)

    local afterItem = ItemToTable(item)
    unit.FireEvent("BonusOption_UpdateItem", injson(GetBagItemsByCount(unit)), injson(ItemToTable(item)))

    PlaySE(unit, cse.signal)
    unit.StartGlobalEvent(highOption and cevent.optionChange_2 or cevent.optionChange_1 )

    ----------------------------------------------------------
    
    local logMsg = "[" .. itemName .. "] ("
    for i, o in pairs(beforeOptions) do
        logMsg = logMsg .. (i == 1 and "" or "/") .. common.statName[o.statID] .. "+" .. math.round(o.value, 2) 
    end
    logMsg = logMsg .. ") ▶ ("
    for i, o in pairs(afterOptions) do
        logMsg = logMsg .. (i == 1 and "" or "/") .. common.statName[o.statID] .. "+" .. math.round(o.value, 2) 
    end
    logMsg = logMsg .. ")" .. (useAssist and " ★" or "")

    local logData = { 
        beforeItem = citem, afterItem = afterItem,
        beforeOptions = beforeOptions, afterOptions = afterOptions, 
        needItemID = needItemID, needItemCount = needItemCount, needGold = needGold,
        haveItemCount = haveItemCount, haveGold = haveGold,
        haveItemLog = haveItemLog, useItemLog = useItemLog,
        haveAssistLog = haveAssistLog, useAssistLog = useAssistLog,
    }
    SendLog(unit, "BonusOption_Change", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end



