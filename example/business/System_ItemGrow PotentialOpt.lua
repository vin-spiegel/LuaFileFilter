--------------------------------------------------------------------------------
-- Server Equipment Potential Option
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- PotentialOption_Appraise
-- PotentialOption_Sealing
-- PotentialOption_Give
--------------------------------------------------------------------------------

gPotentialOption = {}
gPotentialOption.db = GameData.option.potentialOption

Server.GetTopic("PotentialOption_GetData").Add(function() gPotentialOption:SendData(unit)  end)
Server.GetTopic("PotentialOption_Appraise").Add(function(...) gPotentialOption:Appraise(unit, ...)  end)
Server.GetTopic("PotentialOption_Sealing").Add(function(...) gPotentialOption:Sealing(unit, ...)  end)
Server.GetTopic("PotentialOption_Give").Add(function(...) gPotentialOption:Give(unit, ...)  end)


local pSumStatIDRatio = (function()
    local count = 0
    for statID, data in pairs(gPotentialOption.db.statID) do
        count = count + data.ratio
    end
    return count
end)()


--* 부여할 잠재옵션 개수를 반환합니다ㅏ.
local function __CreatePotentialOptionCount(magnifierID)
    local db = gPotentialOption.db
    local mdb = db.magnifier[magnifierID]
    local lineCount = 2
    local targetRatio = rand(1, math.sum(mdb.ratioLineCount) + 1)
    local nowRatio = 0 
    for count, ratio in pairs(mdb.ratioLineCount) do
        nowRatio = nowRatio + ratio
        if targetRatio <= nowRatio then
            lineCount = count
            break
        end
    end
    return lineCount
end


--* 잠재옵션 한줄을 추출하여 반환합니다.
local function __CreatePotentialOption(magnifierID)
    local db = gPotentialOption.db
    local mdb = db.magnifier[magnifierID]

    local statID = 6
    do -- statID 결정
        local targetRatio = rand(1, pSumStatIDRatio + 1)
        local nowRatio = 0 
        for id, data in pairs(db.statID) do
            nowRatio = nowRatio + data.ratio
            if targetRatio <= nowRatio then
                statID = id
                break
            end
        end
    end
    
    local valueStep = 1
    do -- valuePer 결정
        local targetRatio = rand(1, math.sum(mdb.ratioValuePer) + 1)
        local nowRatio = 0 
        for vp, ratio in pairs(mdb.ratioValuePer) do
            nowRatio = nowRatio + ratio
            if targetRatio <= nowRatio then
                valueStep = rand((vp-1)*8+1, vp*8+1)
                break
            end
        end
    end
    
    -- value 결정
    local sdb = db.statID[statID]
    local value = math.round(math.roundup(valueStep * sdb.max/80 / sdb.step) * sdb.step, 4)
    local option = { type = 0, statID = statID, value = value }
    return option
end


--* 클라이언트로 보유재화 및 잠재옵션 부여가능 아이템, 잠재옵션 봉인구슬을 전송합니다.
function gPotentialOption:SendData(unit)
    local countBag = GetBagItemsByCount(unit)
    local beads = {}
    local items = {}
    for _, item in pairs(unit.player.GetItems()) do
        local strID = tostring(item.id)
        local itemData = GetItemData(item)
        if itemData and itemData.canPotentialOption then
            items[strID] = ItemToTable(item)
            items[strID].isEquipped = unit.IsEquippedItem(item.id)
        end
        if self.db.beadItemID == item.dataID then
            beads[strID] = ItemToTable(item)
        end
    end
    unit.FireEvent("PotentialOption_SendData", injson(countBag), injson(items), injson(beads))
end


--* 선택한 장비에 잠재 옵션을 부여&교체합니다.
function gPotentialOption:Appraise(unit, strTargetItem, magnifierID)
    if (not (unit and strTargetItem and magnifierID)) or (not CheckUserSystemDelay(unit)) then return end

    local citem = dejson(strTargetItem)
    local item = unit.player.GetItem(citem.id)
    local itemData = GetItemData(item)
    local pdb = itemData.canPotentialOption 
    local mdb = self.db.magnifier[magnifierID]
    local titlePos = pdb and pdb.pos or 0

    if (not (item and pdb and mdb and item.dataID == citem.dataID and item.level == citem.level))
    or (item.options[titlePos] and item.options[titlePos].statID ~= self.db.nameStatID) 
    or (#item.options < (titlePos-1)) then
        ShowWrongRequestMsg(unit)
        gPotentialOption:SendData(unit)
        return
    end

    local itemName = GetItemName(item)
    local needItemID = magnifierID
    local needItemCount = 1
    local needGold = mdb.needGold or 0
    local haveItemCount = CountItem(unit, needItemID)
    local haveGold = CountGold(unit)

    if not (needItemCount <= haveItemCount and needGold <= haveGold) then
        ShowLackMsg(unit, "감정")
        return
    end

    RemoveGold(unit, needGold)
    RemoveItem(unit, needItemID, needItemCount)

    local beforeOptions = {}
    local c = 0
    for i = titlePos, titlePos+3 do
        c = c + 1
        if citem.options[i] then
            beforeOptions[c] = citem.options[i]
        end
    end

    local afterOptions = {}
    local highOption = false
    local lineCount = __CreatePotentialOptionCount(magnifierID)
    for i=1, lineCount do
        local o = __CreatePotentialOption(magnifierID)
        afterOptions[i] = o

        local maxValue = self.db.statID[o.statID].max
        if highOption == false then
            highOption = maxValue*0.8 <= o.value and true or false
        end
    end

    -- 옵션을 부여합니다. 
    local options = item.options
    if options[titlePos] then Utility.SetItemOption(options[titlePos], 0, self.db.nameStatID, 0)
    else Utility.AddItemOption(item, 0, self.db.nameStatID, 0)
    end
    for i=(titlePos+3), (titlePos+1), -1 do
        local o = options[i]
        local ro = afterOptions[i - titlePos]
        if o and ro then Utility.SetItemOption(options[i], 0, ro.statID, ro.value)
        elseif (not o) and ro then Utility.AddItemOption(item, 0, ro.statID, ro.value)
        elseif o and (not ro) then Utility.RemoveItemOption(item, i-1)
        end
    end
    unit.player.SendItemUpdated(item)

    local afterItem = ItemToTable(item)
    unit.FireEvent("PotentialOption_UpdateItem", injson(GetBagItemsByCount(unit)), injson(ItemToTable(item)))

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
    logMsg = logMsg .. ")"

    local logData = { 
        beforeItem = citem, afterItem = afterItem,
        beforeOptions = beforeOptions, afterOptions = afterOptions, 
        needItemID = needItemID, needItemCount = needItemCount, needGold = needGold,
        haveItemCount = haveItemCount, haveGold = haveGold,
    }
    SendLog(unit, "PotentialOption_Appraise", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end


--* 선택한 장비의 잠재 옵션을 구슬에 봉인합니다.
function gPotentialOption:Sealing(unit, strTargetItem)
    if (not (unit and strTargetItem)) or (not CheckUserSystemDelay(unit)) then return end

    local citem = dejson(strTargetItem)
    local item = unit.player.GetItem(citem.id)
    local itemData = GetItemData(item)
    local pos = itemData.canPotentialOption and itemData.canPotentialOption.pos or 0
    local nameStatID = self.db.nameStatID

    if (not (item and pos and item.dataID == citem.dataID and item.level == citem.level and (item.options[pos] and item.options[pos].statID == nameStatID))) then
        ShowWrongRequestMsg(unit)
        gPotentialOption:SendData(unit)
        return
    end

    local itemName = GetItemName(item)

    local sealingTime = 999
    local targetOptions = {}
    for i, o in pairs(item.options) do
        if i >= pos then 
            sealingTime = o.statID == nameStatID and o.value or sealingTime
            table.insert( targetOptions, { type = 0, statID = o.statID, value = (o.statID == nameStatID and (o.value + 1) or o.value) } )
        end
    end

    local needItemID = self.db.scrollItemID
    local needItemCount = 2^sealingTime
    local haveItemCount, haveItemLog = CountItem(unit, needItemID, true)

    if needItemCount > haveItemCount then
        ShowLackMsg(unit, "봉인")
        return
    end
    
    local beadItemID = self.db.beadItemID
    local bead = Server.CreateItem(beadItemID, 1)
    for i, o in pairs(targetOptions) do
        Utility.AddItemOption(bead, 0, o.statID, o.value)
    end
    local beadItem = ItemToTable(bead)

    for i=(pos+3), pos, -1 do
        if item.options[i] then
            Utility.RemoveItemOption(item, i - 1)
        end
    end
    unit.player.SendItemUpdated(item)
    unit.AddItemByTItem(bead, false)
    local useItemLog = RemoveItem(unit, needItemID, needItemCount, true)

    PlaySE(unit, cse.signal)
    unit.StartGlobalEvent(cevent.potentialOption)
    ShowMsg(unit, "잠재 옵션 봉인에 성공하였습니다.", cc.green)
    gPotentialOption:SendData(unit)


    local afterItem = ItemToTable(item)
    ShowItemPopupByTItem(unit, { afterItem, beadItem })

    ----------------------------------------------------------
    local logMsg = "[" .. itemName .. "] ("
    for i, o in pairs(targetOptions) do
        logMsg = logMsg .. (i == 1 and "" or "/") .. common.statName[o.statID] .. "+" .. math.round(o.value, 2) 
    end
    local logData = {
        beforeItem = citem, afterItem = afterItem, beadItem = beadItem,
        needItemID = needItemID, needItemCount = needItemCount, haveItemCount = haveItemCount,
        needItemLog = needItemLog, useItemLog = useItemLog,
    }
    SendLog(unit, "PotentialOption_Sealing", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end


--* 선택한 장비에 구슬의 잠재옵션을 전달합니다.
function gPotentialOption:Give(unit, strTargetItem, strBeadItem)
    if (not (unit and strTargetItem and strBeadItem)) or (not CheckUserSystemDelay(unit)) then
        return
    end

    local nameStatID = self.db.nameStatID
    local citem = dejson(strTargetItem)
    local item = unit.player.GetItem(citem.id)
    local itemData = GetItemData(item)
    local pos = itemData.canPotentialOption and itemData.canPotentialOption.pos or 0
    local cbead = dejson(strBeadItem)
    local bead = unit.player.GetItem(cbead.id)

    if (not (item and pos and item.dataID == citem.dataID and item.level == citem.level))
    or (item.options[pos] and item.options[pos].statID ~= nameStatID) 
    or (#item.options < (pos-1))
    or (not (bead.dataID == self.db.beadItemID and bead.options[1] and bead.options[1].statID == nameStatID)) then
        ShowWrongRequestMsg(unit)
        gPotentialOption:SendData(unit)
        return
    end

    local itemName = GetItemName(item)

    local beforeOptions = {}
    local c = 0
    for i = pos, pos+3 do
        c = c + 1
        if citem.options[i] then
            beforeOptions[c] = citem.options[i]
        end
    end

    local afterOptions = cbead.options
    unit.RemoveItemByID(bead.id, 1, false)

    for i=#item.options, 1, -1 do
        if i>=pos then
            Utility.RemoveItemOption(item, i-1)
        end
    end
    for _, o in pairs(bead.options) do
        Utility.AddItemOption(item, 0, o.statID, o.value)
    end
    unit.player.SendItemUpdated(item)

    PlaySE(unit, cse.signal)
    unit.StartGlobalEvent(cevent.potentialOption)
    ShowMsg(unit, "잠재 옵션 부여에 성공하였습니다.", cc.green)
    gPotentialOption:SendData(unit)

    local afterItem = ItemToTable(item)
    ShowItemPopupByTItem(unit, { afterItem })

    ----------------------------------------------------------
    
    local logMsg = "[" .. itemName .. "] ("
    for i, o in pairs(beforeOptions) do
        logMsg = logMsg .. (i == 1 and "" or "/") .. common.statName[o.statID] .. "+" .. math.round(o.value, 2) 
    end
    logMsg = logMsg .. ") ▶ ("
    for i, o in pairs(afterOptions) do
        logMsg = logMsg .. (i == 1 and "" or "/") .. common.statName[o.statID] .. "+" .. math.round(o.value, 2) 
    end
    logMsg = logMsg .. ")"

    local logData = {
        bead = cbead, beforeItem = citem, afterItem = afterItem,
        beforeOptions = beforeOptions, afterOptions = afterOptions, 
    }
    SendLog(unit, "PotentialOption_Give", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end


















