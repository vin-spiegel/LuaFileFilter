--------------------------------------------------------------------------------
-- Server Rune
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Rune_Mix
-- Rune_SlotOpen
-- Rune_ChangePage
-- Rune_Equip
-- Rune_Unequip
-- Rune_ResetPage
--------------------------------------------------------------------------------

gRune = {}
gRune.db = GameData.rune

Server.GetTopic("Rune_GetData").Add(function() gRune:SendData(unit) end)
Server.GetTopic("Rune_ShowMixEffect").Add(function() gRune:ShowMixEffect(unit) end)
Server.GetTopic("Rune_Mix").Add(function(targetRarity, strMixList) gRune:Mix(unit, targetRarity, strMixList) end)
Server.GetTopic("Rune_SlotOpen").Add(function(slotNum) gRune:SlotOpen(unit, slotNum) end)
Server.GetTopic("Rune_ChangePage").Add(function(page) gRune:ChangePage(unit, page) end)
Server.GetTopic("Rune_Equip").Add(function(page, slotNum, dataID) gRune:Equip(unit, page, slotNum, dataID) end)
Server.GetTopic("Rune_Unequip").Add(function(page, slotNum) gRune:Unequip(unit, page, slotNum) end)
Server.GetTopic("Rune_ResetPage").Add(function(page) gRune:ResetPage(unit, page) end)


--* 모든 슬롯을 체크 후 반환합니다.
function GetRunePages(unit)
    local nowSlotCount = unit.GetVar( cvar.rune_slotCount )
    local strPages = unit.GetStringVar( csvar.rune_pages )
    local pages = dejson( strPages )
    for i = 1, 3 do
        local strI = tostring(i)
        if not pages[strI] then pages[strI] = {} end
        for j = 1, nowSlotCount do
            if not pages[strI][j] then pages[strI][j] = -1 end
        end
    end
    local afterStrPages = injson(pages)
    if afterStrPages ~= strPages then
        unit.SetStringVar( csvar.rune_pages, afterStrPages )
    end
    return pages
end


--* 현재 페이지 넘버를 반환합니다.
function GetRunePage(unit)
    local nowPage = unit.GetVar( cvar.rune_nowPage )
    local page = math.setrange(nowPage, 1, 3)
    if nowPage ~= page then
        unit.SetVar(cvar.rune_nowPage, page)
    end
    return page
end


--* 스탯을 계산합니다.
function gRune:CalStats(unit, stats)
    local nowPage = GetRunePage(unit)
    local pages = GetRunePages(unit)
    local page = pages[tostring(nowPage)]
    local kinds = {}
    for i, dataID in pairs(page) do
        if dataID and dataID ~= -1 then
            local data = GetItemData(dataID)
            if data.type == 6 then
                local kind = data.kind or 0
                kinds[kind] = kinds[kind] and (kinds[kind] + 1) or 1
            end
        end
    end
    for i, dataID in pairs(page) do
        if dataID ~= -1 then
            local data = GetItemData(dataID)
            local kind = data.kind or 0
            for _, o in pairs(data.stat) do
                local p = self.db.duplicatePenalty[kinds[kind]] or 100
                local value = math.round(o.value*p/100, 2)
                stats[o.statID] = stats[o.statID] and (stats[o.statID] + value) or value
            end
        end
    end
end


--* 클라이언트로 데이터를 전송합니다.
function gRune:SendData(unit, onlyUpdate)
    local nowPage = GetRunePage(unit)
    local nowSlotCount = unit.GetVar( cvar.rune_slotCount )
    local pages = GetRunePages(unit)
    local bag = {}
    for _, item in pairs(unit.player.GetItems()) do
        local data = GetItemData(item)
        if data and data.type == 6 then
            local strID = tostring(item.dataID)
            bag[strID] = bag[strID] and (bag[strID] + item.count) or item.count
        end
    end
    unit.FireEvent("Rune_SendData", onlyUpdate, nowPage, nowSlotCount, injson(pages), injson(bag))
end


--* 룬을 합성합니다.
function gRune:ShowMixEffect(unit)
    unit.StartGlobalEvent(cevent.flash_1)
    PlaySE(unit, cse.spawn)
end
function gRune:Mix(unit, targetRarity, strMixList)
    if (not (unit and targetRarity and strMixList)) or (not CheckUserSystemDelay(unit)) then return end

    local mdb = self.db.mix[targetRarity]
    local mixList = dejson(strMixList)
    local mixCount = 0 
    for strDataID, count in pairs(mixList) do
        local dataID = tonumber(strDataID)
        local data = GetItemData(dataID)
        if not ( data and data.type == 6 and data.rarity == targetRarity and CountItem(unit, dataID) >= count) then
            ShowWrongRequestMsg(unit)
            gRune:SendData(unit)
            return
        end
        mixCount = mixCount + count
    end
    mixCount = mixCount / mdb.needCount

    if not ( mixCount <= 40 and mixCount == math.rounddown(mixCount) ) then
        ShowWrongRequestMsg(unit)
        gRune:SendData(unit)
        return
    end

    local needGold = mdb.needGold * mixCount
    local haveGold = CountGold(unit)
    if not (needGold <= haveGold) then
        ShowLackMsg(unit, "합성")
        return
    end

    local result = {}
    local sCount = 0
    local srate = mdb.rate/100 * 10^10
    local sumKindRatio = math.sumk(self.db.kind, "ratio")
    for i=1, mixCount do
        local trarity = targetRarity
        local rnd = rand(1, 10^10+1)
        if rnd <= srate then
            sCount = sCount + 1
            trarity = trarity + 1
        end

        local tKind = 1
        local rnd = rand(1, sumKindRatio+1)
        local ratio = 0
        for kind, kdata in pairs(self.db.kind) do
            ratio = ratio + kdata.ratio
            if rnd <= ratio then
                tKind = kind
                break
            end
        end

        local tDataID = 1780 + (trarity-1)*40 + tKind
        local strID = tostring(tDataID)
        result[strID] = result[strID] and (result[strID]+1) or 1
    end

    for strDataID, count in pairs(mixList) do
        RemoveItem(unit, tonumber(strDataID), count)
    end
    RemoveGold(unit, needGold)

    for strDataID, count in pairs(result) do
        AddItem(unit, tonumber(strDataID), count)
    end

    ShowItemPopup(unit, result, "합성 " .. mixCount .. "회 결과 (등급 상승 " .. sCount .. "회)" )
    gRune:SendData(unit)

    ----------------------------------------------------------
    local logMsg = cm.rarityName[targetRarity] .. " x" .. mixCount .. " (S" .. sCount .. " F" .. (mixCount - sCount) .. ")"
    local logData = {
        targetRarity = targetRarity, mixCount = mixCount, success = sCount, 
        mixList = mixList, result = result,
        needGold = needGold, haveGold = haveGold, 
    }
    SendLog(unit, "Rune_Mix", logMsg, injson(logData))
    SetUserSystemDelay(unit)
    return true
end


--* 룬 슬롯을 오픈합니다.
function gRune:SlotOpen(unit, slotNum) 
    if (not (unit and slotNum)) or (not CheckUserSystemDelay(unit)) then
        return
    end
    ----------------------------------------------------------
    local nowCount = unit.GetVar( cvar.rune_slotCount )
    local targetCount = nowCount + 1
    local sdb = self.db.slot[ targetCount ]
    if not (sdb and slotNum == targetCount) then
        ShowErrMsg(unit, "이전 슬롯을 먼저 개방해주세요.")
        return
    end

    local reqLevel = sdb.reqLevel
    local nowLevel = unit.level
    if not (nowLevel >= reqLevel) then
        ShowReqLevelMsg(unit, reqLevel)
        return
    end

    local needGold = sdb.needGold
    local haveGold = CountGold(unit)
    if not (needGold <= haveGold) then
        ShowLackMsg(unit, "슬롯 개방")
        return
    end

    RemoveGold(unit, needGold)
    unit.SetVar( cvar.rune_slotCount, targetCount )
    PlaySE(unit, cse.signal)
    unit.StartGlobalEvent(common.event.flash)
    gRune:SendData(unit, true)
    ----------------------------------------------------------
    local logMsg = nowCount .. " ▶ " .. targetCount
    local logData = {
        nowCount = nowCount, targetCount = targetCount, 
        reqLevel = reqLevel, nowLevel = nowLevel, needGold = needGold, haveGold = haveGold, 
    }
    SendLog(unit, "Rune_SlotOpen", logMsg, injson(logData))
    SetUserSystemDelay(unit)
    return true
end


--* 룬을 페이지를 변경합니다.
function gRune:ChangePage(unit, page) 
    if (not (unit and page)) or (not CheckUserSystemDelay(unit)) then
        return
    end
    ----------------------------------------------------------
    local page = math.rounddown(math.setrange(page, 1, 3))
    local nowPage = GetRunePage(unit)
    if nowPage == page then
        ShowWrongRequestMsg(unit)
        gRune:SendData(unit)
        return
    end
    unit.SetVar( cvar.rune_nowPage, page )
    unit.RefreshStats()
    gRune:SendData(unit, true)
    ----------------------------------------------------------
    local logMsg = nowPage .. " ▶ " .. page
    local logData = {}
    SendLog(unit, "Rune_ChangePage", logMsg, injson(logData))
    SetUserSystemDelay(unit)
    return true
end


--* 룬을 장착합니다.
function gRune:Equip(unit, page, slotNum, dataID) 
    if (not (unit and page and slotNum and dataID)) or (not CheckUserSystemDelay(unit, nil, 0.1)) then
        return
    end
    ----------------------------------------------------------
    local nowPage = GetRunePage(unit)
    local nowSlotCount = unit.GetVar( cvar.rune_slotCount )
    local pages = GetRunePages(unit)
    local haveCount = CountItem(unit, dataID)
    local itemData = GetItemData(dataID)
    
    if not (nowSlotCount >= slotNum and nowPage == page and haveCount >= 1 and itemData.type == 6) then
        ShowWrongRequestMsg(unit)
        gRune:SendData(unit)
        return
    end

    local beforeRune = pages[tostring(page)][slotNum]
    pages[tostring(page)][slotNum] = dataID

    local afterSlots = injson(pages)
    unit.SetStringVar( csvar.rune_pages, afterSlots )
    if beforeRune ~= -1 then AddItem(unit, beforeRune, 1) end
    RemoveItem(unit, dataID, 1)
    
    PlaySE(unit, cse.runeEquip)

    unit.RefreshStats()
    gRune:SendData(unit, true)
    ----------------------------------------------------------
    local logMsg = (beforeRune ~= -1 and GetItemName(beforeRune) or "") .. GetItemName(dataID)
    local logData = { 
        page = page, slotNum = slotNum, dataID = dataID, haveCount = haveCount, beforeRune = beforeRune, pages = pages,
    }
    SendLog(unit, "Rune_Equip", logMsg, injson(logData))
    SetUserSystemDelay(unit)
    return true
end


--* 룬을 장착해제합니다.
function gRune:Unequip(unit, page, slotNum) 
    if (not (unit and page and slotNum)) or (not CheckUserSystemDelay(unit, nil, 0.1)) then
        return
    end
    ----------------------------------------------------------
    local nowPage = GetRunePage(unit)
    local nowSlotCount = unit.GetVar( cvar.rune_slotCount )
    local pages = GetRunePages(unit)
    if not (nowSlotCount >= slotNum and nowPage == page) then
        ShowWrongRequestMsg(unit)
        gRune:SendData(unit)
        return
    end

    local beforeRune = pages[tostring(page)][slotNum]
    if not (beforeRune and beforeRune ~= -1) then
        ShowWrongRequestMsg(unit)
        gRune:SendData(unit)
        return
    end

    pages[tostring(page)][slotNum] = -1
    local afterSlots = injson(pages)
    unit.SetStringVar( csvar.rune_pages, afterSlots )
    AddItem(unit, beforeRune, 1)

    PlaySE(unit, cse.runeUnequip)

    unit.RefreshStats()
    gRune:SendData(unit, true)
    ----------------------------------------------------------
    local logMsg = GetItemName(beforeRune)
    local logData = { page = page, slotNum = slotNum, dataID = beforeRune, pages = pages, }
    SendLog(unit, "Rune_Unequip", logMsg, injson(logData))
    SetUserSystemDelay(unit)
    return true
end


--* 룬을 페이지를 비웁니다.
function gRune:ResetPage(unit, page) 
    if (not (unit and page)) or (not CheckUserSystemDelay(unit)) then
        return
    end
    ----------------------------------------------------------
    local nowPage = GetRunePage(unit)
    local nowSlotCount = unit.GetVar( cvar.rune_slotCount )
    local pages = GetRunePages(unit)

    local result = {}
    for slotNum, dataID in pairs(pages[tostring(page)]) do
        if dataID ~= -1 then
            local strID = tostring(dataID)
            result[strID] = result[strID] and (result[strID] + 1) or 1
            pages[tostring(page)][slotNum] = -1
        end
    end

    if table.len(result) <= 0 then
        ShowErrMsg(unit, "장착된 룬이 없습니다.")
        return
    end

    local afterSlots = injson(pages)
    unit.SetStringVar( csvar.rune_pages, afterSlots )
    for strID, count in pairs(result) do
        AddItem(unit, tonumber(strID), count)
    end

    PlaySE(unit, cse.equip)
    unit.RefreshStats()
    gRune:SendData(unit, true)
    ----------------------------------------------------------
    local logMsg = page
    local logData = { page = page, result = result, pages = pages }
    SendLog(unit, "Rune_ResetPage", logMsg, injson(logData))
    SetUserSystemDelay(unit)
    return true
end






