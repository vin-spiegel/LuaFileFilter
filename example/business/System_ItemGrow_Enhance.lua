--------------------------------------------------------------------------------
-- Server Enhance
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Enhance_Try, Enhance_AutoTry, Enhance_Transfer, Enhance_Give
--------------------------------------------------------------------------------

gEnhance = {}
gEnhance.db = GameData.enhance

Server.GetTopic("Enhance_GetData").Add(function() gEnhance:SendData(unit) end)
Server.GetTopic("Enhance_Try").Add(function(...) gEnhance:Try(unit, ...) end)
Server.GetTopic("Enhance_AutoTry").Add(function(...) gEnhance:AutoTry(unit, ...) end)
Server.GetTopic("Enhance_Transfer").Add(function(...) gEnhance:Transfer(unit, ...) end)
Server.GetTopic("Enhance_Give").Add(function(...) gEnhance:Give(unit, ...) end)



--* 강화 관련 재료 아이템 개수를 테이블로 반환합니다.
enhance_materials = { "goldID", "stoneID", "assistID", "tstoneID", "scrollID" }
function gEnhance:CountMaterial(unit)
    local bag = {}
    for _, name in pairs(enhance_materials) do
        local items = self.db[name]
        for _, id in pairs( type(items) == "table" and items or {items} ) do
            bag[tostring(id)] = CountItem(unit, id)
        end
    end
    return bag
end


--* 클라이언트로 보유재화 및 강화가능 아이템을 전송합니다.
function gEnhance:SendData(unit)
    local countBag = gEnhance:CountMaterial(unit)
    local canEnhanceItems = {}
    for _, item in pairs(unit.player.GetItems()) do
        local itemData = GetItemData(item)
        if itemData and itemData.canEnhance then
            local strID = tostring(item.id)
            canEnhanceItems[strID] = ItemToTable(item)
            canEnhanceItems[strID].isEquipped = unit.IsEquippedItem(item.id)
        end
    end
    unit.FireEvent("Enhance_SendData", injson(countBag), injson(canEnhanceItems))
end


--* 특정 아이템의 갱신 정보 및 변동 재료를 전송합니다.
function gEnhance:UpdateItem(unit, item, strLogData, nowEnhanceCount)
    local titem = ItemToTable(item)
    local countBag = gEnhance:CountMaterial(unit)
    unit.FireEvent("Enhance_UpdateItem", injson(titem), injson(countBag), strLogData, nowEnhanceCount)
end





--* 강화 확률을 계산해 성공/실패 및 하락 여부를 반환합니다.
function __Enhance_CalSuccess(level, useAssist)
    local db = gEnhance.db
    local edb = db.level[level].enhance
    local success, down, reset = false, false, false
    local successRate = math.roundup(edb.successRate * (1 + (useAssist and db.assistEffect.rateUp/100 or 0)), 4) * 10^10
    local sRand = rand(1, 10^10 + 1)
    success = sRand <= successRate and true or false
    if not success then
        down = (level >= 1 and level < 10) and ( (not useAssist) and true or (rand(1, 101) > db.assistEffect.shield and true or false) ) or false
        reset = (level >= 10) and ( (not useAssist) and true or (rand(1, 101) > db.assistEffect.shield and true or false) ) or false
    end
    local afterLevel = success and (level + 1) or (down and (level - 1) or (reset and 0 or level))
    return afterLevel, success, down, reset
end
--* 강화 필요 재료를 반환합니다.
function __Enhance_CalNeeds(level, useAssist)
    local db = gEnhance.db
    local edb = db.level[level].enhance
    local needStoneCount = math.rounddown(edb.needStoneCount * (1 - (useAssist and db.assistEffect.countDown/100 or 0)))
    local needGold = math.rounddown(edb.needGold * (1 - (useAssist and db.assistEffect.countDown/100 or 0)))
    local needAssistCount = (not useAssist) and 0 or edb.needAssistCount
    return needStoneCount, needGold, needAssistCount
end
--* 강화 보유 재료를 반환합니다.
function __Enhance_CalHaves(unit)
    local db = gEnhance.db
    local haveStoneCount, haveStoneLog = CountItem(unit, db.stoneID, true)
    local haveGold = CountGold(unit)
    local haveAssistCount, haveAssistLog = CountItem(unit, db.assistID, true)
    return haveStoneCount, haveGold, haveStoneCount, haveStoneLog, haveAssistCount, haveAssistLog
end
--* 강화에 필요한 재료들을 소모합니다.
function __Enhance_RemoveNeeds(needStoneCount, needGold, needAssistCount)
    local db = gEnhance.db
    RemoveGold(unit, needGold)
    local useStoneLog = RemoveItem(unit, db.stoneID, needStoneCount, true)
    local useAssistLog
    if needAssistCount > 0 then
        useAssistLog = RemoveItem(unit, db.assistID, needAssistCount, true)
    end
    return useStoneLog, useAssistLog
end


--* 강화를 시도합니다.
function gEnhance:Try(unit, strTItem, useAssist)
    if (not (unit and strTItem)) or (not CheckUserSystemDelay(unit)) then
        return
    end

    local titem = dejson(strTItem)
    local item = unit.player.GetItem(titem.id)
    local itemData = GetItemData(titem)

    if not ( item and itemData.canEnhance and item.dataID == titem.dataID and item.level == titem.level and item.level < self.db.maxLevel ) then
        ShowWrongRequestMsg(unit)
        gEnhance:SendData(unit)
        return
    end

    if unit.IsEquippedItem(item.id) then
        ShowErrMsg("장착된 아이템은 강화할 수 없습니다.")
        return
    end

    local itemName = GetItemName(item)
    local itemLevel = item.level

    local needStoneCount, needGold, needAssistCount = __Enhance_CalNeeds(itemLevel, useAssist)
    local haveStoneCount, haveGold, haveStoneCount, haveStoneLog, haveAssistCount, haveAssistLog = __Enhance_CalHaves(unit)
    if not (needStoneCount <= haveStoneCount and needGold <= haveGold and needAssistCount <= haveAssistCount) then
        ShowLackMsg(unit, "강화")
        return
    end
    local useStoneLog, useAssistLog = __Enhance_RemoveNeeds(needStoneCount, needGold, needAssistCount)
    local afterLevel, success, down, reset = __Enhance_CalSuccess(itemLevel, useAssist)
    item.level = afterLevel
    unit.player.SendItemUpdated(item)

    local msgText = "강화 " .. (success and "성공" or "실패.." )
    msgText = msgText .. (success and "" or ("\n<size=16>- 강화 수치 " .. (down and "하락" or "") .. (reset and "초기화" or "") .. (afterLevel == itemLevel and "유지" or "") .. " -</size>" ))
    ShowMsg(unit, msgText, success and cc.green or (reset and cc.red or cc.gray))
    PlaySE(unit, success and cse.success or cse.fail)
    unit.StartGlobalEvent(cevent[ "enhance_" .. (success and "success" or (reset and "reset" or "fail")) ])
    gEnhance:UpdateItem(unit, item)

    ----------------------------------------------------------
    
    local logMsg = "[" .. itemName .. "→" .. (itemLevel + 1) .. " (" .. afterLevel .. ")] "
    logMsg = logMsg .. (success and "Success" or "Fail(" .. (down and "Down" or (reset and "Reset" or "Keep")) .. ")") .. (useAssist and " ★" or "")
    local logData = { 
        targetItem = titem, 
        beforeLevel = itemLevel, afterLevel = afterLevel,
        success = success, down = down, reset = reset,
        needStoneCount = needStoneCount, needGold = needGold, needAssistCount = needAssistCount,
        haveStoneCount = haveStoneCount, haveGold = haveGold, haveAssistCount = haveAssistCount,
        haveStoneLog = haveStoneLog, haveAssistLog = haveAssistLog,
        useStoneLog = useStoneLog, useAssistLog = useAssistLog,
    }
    SendLog(unit, "Enhance_Try", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end


--* 자동 강화(5회)를 시도합니다.
function gEnhance:AutoTry(unit, strTItem, targetLevel, useAssistLevel, nowEnhanceCount)
    if (not (unit and strTItem and targetLevel and useAssistLevel)) or (not CheckUserSystemDelay(unit)) then
        return
    end
    local titem = dejson(strTItem)
    local item = unit.player.GetItem(titem.id)
    local itemData = GetItemData(titem)

    local nowEnhanceCount = math.rounddown(nowEnhanceCount)
    if not ( item and itemData.canEnhance and item.dataID == titem.dataID and item.level == titem.level and item.level < self.db.maxLevel ) then
        ShowWrongRequestMsg(unit)
        gEnhance:SendData(unit)
        unit.FireEvent("Enhance_AutoStop", "잘못된 요청입니다." .. et_2 .. "자동 강화가 중지됩니다.")
        return
    end

    if unit.IsEquippedItem(item.id) then
        ShowErrMsg("장착된 아이템은 강화할 수 없습니다.")
        unit.FireEvent("Enhance_AutoStop", "장착된 아이템은 강화할 수 없습니다." .. et_2 .. "자동 강화가 중지됩니다.")
        return
    end

    local itemName = GetItemName(item)
    local beforeItemLevel = item.level

    local logData = { targetItem = titem, startLevel = beforeItemLevel, targetLevel = targetLevel, useAssistLevel = useAssistLevel, }
    for i = 1, 5 do
        local itemLevel = item.level
        if itemLevel >= targetLevel then
            unit.FireEvent("Enhance_AutoStop", "목표 수치에 도달하였습니다!" .. et_2 .. "자동 강화가 중지됩니다.")
            break
        end
        local useAssist = useAssistLevel <= item.level and true or false
        local needStoneCount, needGold, needAssistCount = __Enhance_CalNeeds(itemLevel, useAssist)
        
        local haveStoneCount, haveGold, haveStoneCount, haveStoneLog, haveAssistCount, haveAssistLog = __Enhance_CalHaves(unit)
        if not (needStoneCount <= haveStoneCount and needGold <= haveGold and needAssistCount <= haveAssistCount) then
            unit.FireEvent("Enhance_AutoStop", "강화에 필요한 재료가 부족합니다." .. et_2 .. "자동 강화가 중지됩니다.")
            break
        end
        nowEnhanceCount = nowEnhanceCount + 1
        local useStoneLog, useAssistLog = __Enhance_RemoveNeeds(needStoneCount, needGold, needAssistCount)
        local afterLevel, success, down, reset = __Enhance_CalSuccess(itemLevel, useAssist)
        item.level = afterLevel
        logData[tostring(nowEnhanceCount)] = {
            beforeLevel = itemLevel, afterLevel = afterLevel,
            success = success, down = down, reset = reset,
            needStoneCount = needStoneCount, needGold = needGold, needAssistCount = needAssistCount,
            haveStoneCount = haveStoneCount, haveGold = haveGold, haveStoneCount = haveStoneCount, haveAssistCount = haveAssistCount,
            haveStoneLog = haveStoneLog, haveAssistLog = haveAssistLog,
            useStoneLog = useStoneLog, useAssistLog = useAssistLog,
        }
    end

    unit.player.SendItemUpdated(item)
    PlaySE(unit, cse.signal)
    unit.StartGlobalEvent(cevent.enhance_auto)

    ----------------------------------------------------------
    
    local logMsg = "[" .. itemName .. "→" .. targetLevel .. " (" .. item.level .. ")] UseAssist " .. (useAssistLevel == 15 and "X" or (useAssistLevel .. "▲"))
    local strLogData = injson(logData)
    SendLog(unit, "Enhance_AutoTry", logMsg, strLogData)
    gEnhance:UpdateItem(unit, item, strLogData, nowEnhanceCount)
    SetUserSystemDelay(unit)
end


--* 강화를 전수합니다.
function gEnhance:Transfer(unit, strTargetItem, strMaterialItem, useTransferStone)
    if (not (unit and strTargetItem and strMaterialItem)) or (not CheckUserSystemDelay(unit)) then
        return
    end

    local cTargetItem = dejson(strTargetItem)
    local cMaterialItem = dejson(strMaterialItem)
    local targetItemName = GetItemName(cTargetItem)
    local meterialItemName = GetItemName(cMaterialItem)
    local targetItem = unit.player.GetItem(cTargetItem.id)
    local materialItem = unit.player.GetItem(cMaterialItem.id)
    local targetItemData = GetItemData(cTargetItem)
    local materialItemData = GetItemData(cMaterialItem)
    local targetLevel = cMaterialItem.level - (useTransferStone and 0 or 1)
    local tdb = self.db.level[cMaterialItem.level] and self.db.level[cMaterialItem.level].transfer or nil

    if (not (tdb and targetItem and materialItem and targetItemData.canEnhance and materialItemData.canEnhance))
    or (not (targetItem.dataID == cTargetItem.dataID and targetItem.level == cTargetItem.level))
    or (not (materialItem.dataID == cMaterialItem.dataID and materialItem.level == cMaterialItem.level))
    or (not (targetItem.level < targetLevel)) then
        ShowWrongRequestMsg(unit)
        gEnhance:SendData(unit)
        return
    end

    if unit.IsEquippedItem(targetItem.id) or unit.IsEquippedItem(materialItem.id) then
        ShowErrMsg("장착된 아이템이 선택되어 있습니다.")
        return
    end

    local needTstoneCount = useTransferStone and tdb.needTstoneCount or 0
    local needGold = tdb.needGold
    local haveTransferStoneCount, haveTransferStoneLog = CountItem(unit, self.db.tstoneID, true)
    local haveGold = CountGold(unit)

    if not (needTstoneCount <= haveTransferStoneCount and needGold <= haveGold) then
        ShowLackMsg(unit, "강화 전수")
        return
    end
    
    local useTransferStoneLog = RemoveItem(unit, self.db.tstoneID, needTstoneCount, true)
    RemoveGold(unit, needGold)

    materialItem.level = 0
    targetItem.level = targetLevel
    unit.player.SendItemUpdated(materialItem)
    unit.player.SendItemUpdated(targetItem)

    PlaySE(unit, cse.signal)
    unit.StartGlobalEvent(cevent.enhance_transfer)
    ShowMsg(unit, "강화 전수에 성공하였습니다.", cc.green)
    
    local resultItem = {dataID = cTargetItem.dataID, level = targetLevel, options = cTargetItem.options}
    local afmitem = {dataID = cMaterialItem.dataID, level = 0, options = cMaterialItem.options}
    ShowItemPopupByTItem(unit, { resultItem, afmitem })
    gEnhance:SendData(unit)

    ----------------------------------------------------------
    local logMsg = "[" .. targetItemName .. "] ＋ [" .. meterialItemName .. "] = [" .. GetItemName(resultItem) .. "]" 
    local logData = {
        useTransferStone = useTransferStone, targetLevel = targetLevel,
        target = cTargetItem, material = cMaterialItem , result = resultItem, afterMaterial = afmitem,
        needTstoneCount = needTstoneCount, haveTransferStoneCount = haveTransferStoneCount,
        needGold = needGold, haveGold = haveGold,
        haveTransferStoneLog = haveTransferStoneLog, useTransferStoneLog = useTransferStoneLog,
    }
    SendLog(unit, "Enhance_Transfer", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end


--* 강화를 부여합니다.
function gEnhance:Give(unit, strTargetItem, scrollItemID)
    if (not (unit and strTargetItem and scrollItemID)) or (not CheckUserSystemDelay(unit)) then
        return
    end

    local cTargetItem = dejson(strTargetItem)
    local targetItemName = GetItemName(cTargetItem)
    local targetItem = unit.player.GetItem(cTargetItem.id)
    local targetItemData = GetItemData(cTargetItem)

    local scrollItemID = tonumber(scrollItemID)
    local scrollItemName = GetItemName(scrollItemID)
    local targetLevel = self.db.scrollData[scrollItemID]

    if (not (targetItem and targetLevel and targetItemData.canEnhance))
    or (not (targetItem.dataID == cTargetItem.dataID and targetItem.level == cTargetItem.level))
    or (not (targetItem.level < targetLevel)) then
        ShowWrongRequestMsg(unit)
        gEnhance:SendData(unit)
        return
    end

    if unit.IsEquippedItem(targetItem.id) then
        ShowErrMsg("장착된 아이템이 선택되어 있습니다.")
        return
    end

    local needScrollCount = 1
    local haveScrollCount = CountItem(unit, scrollItemID)

    if not (needScrollCount <= haveScrollCount) then
        ShowLackMsg(unit, "강화 부여")
        return
    end
    
    RemoveItem(unit, scrollItemID, needScrollCount, true)
    targetItem.level = targetLevel
    unit.player.SendItemUpdated(targetItem)

    PlaySE(unit, cse.signal)
    unit.StartGlobalEvent(cevent.enhance_transfer)
    ShowMsg(unit, "강화 부여에 성공하였습니다.", cc.green)
    
    local resultItem = {dataID = cTargetItem.dataID, level = targetLevel, options = cTargetItem.options}
    ShowItemPopupByTItem(unit, { resultItem })
    gEnhance:SendData(unit)

    ----------------------------------------------------------
    local logMsg = "[" .. scrollItemName .. "] ▶ [" .. targetItemName .. "] = [" .. GetItemName(resultItem) .. "]" 
    local logData = { targetLevel = targetLevel, scroll = scrollItemID , target = cTargetItem,  result = resultItem }
    SendLog(unit, "Enhance_Give", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end

















