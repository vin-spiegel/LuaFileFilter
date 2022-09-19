--------------------------------------------------------------------------------
-- Server Pet
--------------------------------------------------------------------------------
-- [참고사항] 
-- onJoinPlayer 에서 접속 시 장착된 펫 소환 처리
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Pet_Mix
-- Pet_FailBonus
-- Pet_Confirm
-- Pet_ConfirmAll
-- Pet_Change
-- Pet_Collection
-- Pet_Spawn
--------------------------------------------------------------------------------

gPet = {}
gPet.db = GameData.pet

Server.GetTopic("Pet_GetData").Add(function() gPet:SendData(unit) end)
Server.GetTopic("Pet_Equip").Add(function(code) gPet:Equip(unit, code) end)
Server.GetTopic("Pet_Unequip").Add(function() gPet:Unequip(unit) end)
Server.GetTopic("Pet_Mix").Add(function(rarity, strMixList) gPet:Mix(unit, rarity, strMixList) end)
Server.GetTopic("Pet_GetFailBonus").Add(function(rarity) gPet:GetFailBonus(unit, rarity) end)
Server.GetTopic("Pet_Change").Add(function(useType, num, code) gPet:Change(unit, useType, num, code) end)
Server.GetTopic("Pet_Confirm").Add(function(num, code) gPet:Confirm(unit, num, code) end)
Server.GetTopic("Pet_ConfirmAll").Add(function(rarity) gPet:ConfirmAll(unit, rarity) end)
Server.GetTopic("Pet_Collection_Complete").Add(function(ccode) gPet:CollectionComplete(unit, ccode) end)


--* 펫 장착 옵션을 계산합니다.
function gPet:CalStatsEquipped(unit, stats)
    local nowPet = unit.GetStringVar( csvar.pet_equip )
    local data = self.db.list[nowPet]
    if not data then return end
    for _, o in pairs(data.stat) do
        local statID, value = o[1], o[2]
        stats[statID] = stats[statID] and (stats[statID] + value) or value
    end
end


--* 펫 컬렉션 옵션을 계산합니다.
function gPet:CalStatsCollection(unit, stats)
    local collections = dejson( unit.GetStringVar( csvar.pet_collections ) )
    for _, code in pairs(collections) do
        local data = self.db.collection[code]
        if data then
            local statID, value = data.stat[1], data.stat[2]
            stats[statID] = stats[statID] and (stats[statID] + value) or value
        end
    end
end


--* 클라이언트로 데이터를 전송합니다.
function gPet:SendData(unit, onlyUpdate)
    local equip = unit.GetStringVar( csvar.pet_equip )
    local lists = unit.GetStringVar( csvar.pet_lists )
    local mix = unit.GetStringVar( csvar.pet_failCounts )
    local confirms = unit.GetStringVar( csvar.pet_confirms )
    local collections = unit.GetStringVar( csvar.pet_collections )
    unit.FireEvent( "Pet_SendData", onlyUpdate, equip, lists, mix, confirms, collections )
end


--* 펫을 장착하고 Unit을 소환합니다.
function gPet:Equip(unit, code)
    if not (unit and code and CheckUserSystemDelay(unit)) then return end
    local lists = dejson(unit.GetStringVar( csvar.pet_lists ))
    local data = self.db.list[code]
    if not (data and lists[code]) then
        ShowWrongRequestMsg(unit)
        return
    end
    unit.SetStringVar( csvar.pet_equip, code )
    unit.RefreshStats()
    gPet:SendData(unit, true)
    ShowMsg(unit, "<color=" .. cm.rarityColor[data.rarity] .. ">".. data.name .. "</color> 장착", cc.green)
    PlaySE(unit, cse.equip)
    gPet:SpawnEquippedPet(unit)
    SetUserSystemDelay(unit)
end


--* 펫을 장착해제 합니다..
function gPet:Unequip(unit)
    if not (unit and CheckUserSystemDelay(unit)) then return end
    local nowPet = unit.GetStringVar( csvar.pet_equip )
    local data = self.db.list[nowPet]
    if not data then return end
    unit.SetStringVar( csvar.pet_equip )
    unit.RefreshStats()
    gPet:SendData(unit, true)
    ShowMsg(unit, "<color=" .. cm.rarityColor[data.rarity] .. ">".. data.name .. "</color> 장착 해제", cc.gray)
    PlaySE(unit, cse.equip)
    gPet:SpawnEquippedPet(unit)
    SetUserSystemDelay(unit)
end


--* 펫을 합성합니다.
function gPet:Mix(unit, rarity, strMixList)
    if not (unit and rarity and strMixList and CheckUserSystemDelay(unit)) then return end
    ----------------------------------------------------------

    local strLists = unit.GetStringVar( csvar.pet_lists )
    local strConfirms = unit.GetStringVar( csvar.pet_confirms )
    local strFailCounts = unit.GetStringVar( csvar.pet_failCounts )
    local lists = dejson(strLists)
    local confirms = dejson(strConfirms)
    local failCounts = dejson(strFailCounts)
    local mixList = dejson(strMixList)
    local mdb = self.db.mix[rarity]
    local minConfirmRarity = table.firstkey(self.db.change)

    local mixCount = 0
    for code, count in pairs(mixList) do
        local data = self.db.list[code]
        if not (data and data.rarity == rarity and lists[code] and lists[code].count >= count) then
            ShowWrongRequestMsg(unit)
            return
        end
        mixCount = mixCount + count
    end
    mixCount = mixCount / mdb.needCount

    if not (mdb and mixCount <= 12 and mixCount == math.rounddown(mixCount)) then
        ShowWrongRequestMsg(unit)
        return
    end

    local result = {}
    local sCount = 0
    local srate = mdb.rate/100 * 10^10
    for code, count in pairs(mixList) do
        lists[code].count = lists[code].count - count
    end
    for i = 1, mixCount do
        local rnd = rand(1, 10^10+1)
        local trarity = rarity
        if rnd <= srate then
            sCount = sCount + 1
            trarity = trarity + 1
        else
            local strRarity = tostring(rarity)
            failCounts[strRarity] = failCounts[strRarity] and (failCounts[strRarity] + 1) or 1
        end
        local tdb = self.db.rList[trarity]
        local code = tdb[ rand(1, #tdb + 1) ]
        table.insert(result, code)
        if minConfirmRarity <= trarity then
            table.insert(confirms, { code = code, count = 0, ts = math.rounddown(GetTimeStamp()) } )
        else
            if lists[code] then lists[code].count = lists[code].count and (lists[code].count + 1) or 1
            else lists[code] = { count = 0 }
            end
        end
    end

    local afterStrLists = injson(lists)
    local afterStrConfirms = injson(confirms)
    local afterStrfailCounts = injson(failCounts)
    local strResult = injson(result)
    unit.SetStringVar(csvar.pet_lists, afterStrLists)
    unit.SetStringVar(csvar.pet_confirms, afterStrConfirms)
    unit.SetStringVar(csvar.pet_failCounts, afterStrfailCounts)
    unit.FireEvent( "Pet_Spawn", 3, strResult )
    gPet:SendData(unit)

    ----------------------------------------------------------
    local logMsg = cm.rarityName[rarity] .. " x" .. mixCount .. " (S" .. sCount .. " F" .. (mixCount - sCount) .. ")"
    local logData = {
        rarity = rarity, mixCount = mixCount, mixList = mixList, success = sCount, result = result,
        beforeList = dejson(strLists), afterList = lists,
        beforeConfirms = dejson(strConfirms), afterConfirms = confirms,
        beforeFailCounts = dejson(strFailCounts), afterConfirms = failCounts,
    }
    SendLog(unit, "Pet_Mix", logMsg, injson(logData))

    SetUserSystemDelay(unit)
end


--* 실패 보너스를 획득합니다.
function gPet:GetFailBonus(unit, rarity)
    if not (unit and rarity and CheckUserSystemDelay(unit)) then return end
    ----------------------------------------------------------

    local strLists = unit.GetStringVar( csvar.pet_lists )
    local strConfirms = unit.GetStringVar( csvar.pet_confirms )
    local strFailCounts = unit.GetStringVar( csvar.pet_failCounts )
    local lists = dejson(strLists)
    local confirms = dejson(strConfirms)
    local failCounts = dejson(strFailCounts)
    local mdb = self.db.mix[rarity]
    local minConfirmRarity = table.firstkey(self.db.change)
    local strRarity = tostring(rarity)

    if not (mdb and mdb.failBonus) then
        ShowWrongRequestMsg(unit)
        return
    end

    local targetCount = math.min( 12, math.rounddown( (failCounts[strRarity] or 0) / mdb.failBonus) )
    if targetCount < 1 then
        ShowWrongRequestMsg(unit)
        return
    end

    failCounts[strRarity] = failCounts[strRarity] - mdb.failBonus * targetCount

    local result = {}
    for i = 1, targetCount do
        local trarity = rarity + 1
        local tdb = self.db.rList[trarity]
        local code = tdb[ rand(1, #tdb + 1) ]
        table.insert(result, code)
        if minConfirmRarity <= trarity then
            table.insert(confirms, { code = code, count = 0, ts = math.rounddown(GetTimeStamp()) } )
        else
            if lists[code] then lists[code].count = lists[code].count and (lists[code].count + 1) or 1
            else lists[code] = { count = 0 }
            end
        end
    end

    local afterStrLists = injson(lists)
    local afterStrConfirms = injson(confirms)
    local afterStrfailCounts = injson(failCounts)
    local strResult = injson(result)
    unit.SetStringVar(csvar.pet_lists, afterStrLists)
    unit.SetStringVar(csvar.pet_confirms, afterStrConfirms)
    unit.SetStringVar(csvar.pet_failCounts, afterStrfailCounts)
    unit.FireEvent( "Pet_Spawn", 3, strResult )
    gPet:SendData(unit)

    ----------------------------------------------------------
    local logMsg = cm.rarityName[rarity] .. " x" .. targetCount
    local logData = { 
        rarity = rarity, targetCount = targetCount, result = result, 
        beforeList = dejson(strLists), afterList = lists,
        beforeConfirms = dejson(strConfirms), afterConfirms = confirms,
        beforeFailCounts = dejson(strFailCounts), afterConfirms = failCounts,
    }
    SendLog(unit, "Pet_FailBonus", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end


--* 확정 대기 중인 펫을 확정합니다.
function gPet:Confirm(unit, num, code)
    if not (unit and num and code and CheckUserSystemDelay(unit)) then return end
    ----------------------------------------------------------

    local strLists = unit.GetStringVar( csvar.pet_lists )
    local strConfirms = unit.GetStringVar( csvar.pet_confirms )
    local lists = dejson(strLists)
    local confirms = dejson(strConfirms)
    local data = self.db.list[code]

    if not (data and confirms[num] and confirms[num].code == code) then
        ShowWrongRequestMsg(unit)
        gPet:SendData(unit)
        return
    end

    table.remove(confirms, num)
    if lists[code] then lists[code].count = lists[code].count and (lists[code].count + 1) or 1
    else lists[code] = { count = 0 }
    end

    local afterStrLists = injson(lists)
    local afterStrConfirms = injson(confirms)
    unit.SetStringVar(csvar.pet_lists, afterStrLists)
    unit.SetStringVar(csvar.pet_confirms, afterStrConfirms)
    gPet:SendData(unit)

    PlaySE(unit, cse.signal)
    ShowMsg(unit, "<color=" .. cm.rarityColor[data.rarity] .. ">" .. data.name .. "</color> 펫이 확정되었습니다.")
    
    ----------------------------------------------------------
    local logMsg = "[" .. common.rarityName[data.rarity] .. "] " .. data.name .. " Confirm"
    local logData = {
        num = num, code = code, 
        beforeList = dejson(strLists), afterList = lists,
        beforeConfirms = dejson(strConfirms), afterConfirms = confirms,
    }
    SendLog(unit, "Pet_Confirm", logMsg, injson(logData))

    ----------------------------------------------------------
    if self.db.minServerSayRarity <= data.rarity then
        local msg = "[#] " .. unit.player.name .. "님께서 "
        msg = msg .."<color=" .. cm.rarityColor[data.rarity] .. ">[" .. cm.rarityName[data.rarity] .. "]" .. data.name .. "</color> 펫을 획득하셨습니다."
        Chat(Server, msg, cc.yellow)
    end
    SetUserSystemDelay(unit)
end


--* 확정 대기 중인 펫을 모두 확정합니다.
function gPet:ConfirmAll(unit, rarity)
    if not (unit and rarity and CheckUserSystemDelay(unit)) then return end
    SetUserSystemDelay(unit)
    ----------------------------------------------------------

    local strLists = unit.GetStringVar( csvar.pet_lists )
    local strConfirms = unit.GetStringVar( csvar.pet_confirms )
    local lists = dejson(strLists)
    local confirms = dejson(strConfirms)

    local sumCount = 0
    local newConfirms = {}
    local msg = ""
    for i, conf in pairs(confirms) do
        local code = conf.code
        local data = self.db.list[code]
        if data and data.rarity == rarity then
            sumCount = sumCount + 1
            if lists[code] then lists[code].count = lists[code].count and (lists[code].count + 1) or 1
            else lists[code] = { count = 0 }
            end
            if self.db.minServerSayRarity <= rarity then
                msg = msg .. (msg == "" and "" or "\n") .. "[#] " .. unit.player.name .. "님께서 "
                msg = msg .."<color=" .. cm.rarityColor[data.rarity] .. ">[" .. cm.rarityName[data.rarity] .. "]" .. data.name .. "</color> 펫을 획득하셨습니다."
            end
        else
            table.insert(newConfirms, conf)
        end
    end

    if sumCount <= 0 then
        ShowWrongRequestMsg(unit)
        gPet:SendData(unit)
        return
    end

    local afterStrLists = injson(lists)
    local afterStrConfirms = injson(newConfirms)
    unit.SetStringVar(csvar.pet_lists, afterStrLists)
    unit.SetStringVar(csvar.pet_confirms, afterStrConfirms)
    gPet:SendData(unit)

    PlaySE(unit, cse.signal)
    ShowMsg(unit, "<color=" .. cm.rarityColor[rarity] .. ">" .. cm.rarityName[rarity] .. "등급 펫</color> " .. sumCount .. "개가 모두 확정되었습니다.")
    
    ----------------------------------------------------------
    local logMsg = common.rarityName[rarity] .. " " .. sumCount .. " Confirm"
    local logData = {
        rarity = rarity, sumCount = sumCount, 
        beforeList = dejson(strLists), afterList = lists,
        beforeConfirms = dejson(strConfirms), afterConfirms = newConfirms,
    }
    SendLog(unit, "Pet_ConfirmAll", logMsg, injson(logData))

    ----------------------------------------------------------
    if self.db.minServerSayRarity <= rarity then
        Chat(Server, msg, cc.yellow)
    end
end


--* 확정 대기 중인 펫을 변경합니다.
function gPet:Change(unit, useType, num, code)
    if not (unit and useType and num and code and CheckUserSystemDelay(unit)) then return end
    ----------------------------------------------------------

    local strConfirms = unit.GetStringVar( csvar.pet_confirms )
    local confirms = dejson(strConfirms)
    local data = self.db.list[code]
    local ndb = self.db.change[data.rarity]

    if not (data and confirms[num] and confirms[num].code == code) then
        ShowWrongRequestMsg(unit)
        gPet:SendData(unit)
        return
    end

    local conf = confirms[num]
    local needGemID = useType == 1 and 2 or 3
    local needGem = ndb.needGem[ conf.count + 1 ]
    local haveGem = CountItem(unit, needGemID)
    if not needGem then
        ShowErrMsg(unit, "더 이상 변경할 수 없습니다.")
        return
    end
    if not (needGem <= haveGem) then
        ShowLackMsg(unit, "변경")
        return
    end

    local beforeStrConf = injson(conf)
    local tdb = self.db.rList[data.rarity]
    local tList = {}
    for i, c in pairs(tdb) do
        if c ~= code then
            table.insert(tList, c)
        end
    end
    local afterCode = tList[rand(1, #tList + 1)]
    conf.code = afterCode
    conf.count = conf.count + 1

    local beforeName = data.name
    local afterName = self.db.list[afterCode].name

    RemoveItem(unit, needGemID, needGem)
    local afterStrConfirms = injson(confirms)
    unit.SetStringVar(csvar.pet_confirms, afterStrConfirms)
    gPet:SendData(unit)
    unit.FireEvent( "Pet_Spawn", 3, injson({ afterCode }) )
    
    ----------------------------------------------------------
    local logMsg = "[" .. cm.rarityName[data.rarity] .. "] " .. beforeName .. " ▶ " .. afterName .. " (Count " .. conf.count ..")"
    local logData = {
        rarity = data.rarity, useType = useType, num = num, code = code,
        needGemID = needGemID, needGem = needGem, haveGem = haveGem,
        beforeConf = dejson(beforeStrConf), afterConf = conf,
        beforeConfirms = dejson(strConfirms), afterConfirms = confirms,
    }
    SendLog(unit, "Pet_Change", logMsg, injson(logData))
    SetUserSystemDelay(unit)
end


--* 컬렉션을 완료합니다.
function gPet:CollectionComplete(unit, ccode)
    if not (unit and ccode and CheckUserSystemDelay(unit)) then return end
    SetUserSystemDelay(unit)
    ----------------------------------------------------------

    local strLists = unit.GetStringVar( csvar.pet_lists )
    local strCollections = unit.GetStringVar( csvar.pet_collections )
    local lists = dejson(strLists)
    local collections = dejson(strCollections)

    local collection = self.db.collection[ccode]

    local isComp = false
    for _, cc in pairs(collections) do
        if cc == ccode then
            isComp = true 
            break
        end
    end

    local ishaveAll = true
    for _, pc in pairs(collection.list) do
        if not lists[pc] then
            ishaveAll = false
            break
        end
    end

    if (not collection) or isComp or (not ishaveAll) then
        ShowWrongRequestMsg(unit)
        gPet:SendData(unit)
        return
    end

    local cName = collection.name
    local cStat = collection.stat

    table.insert(collections, ccode)
    local afterStrCollections = injson(collections)
    unit.SetStringVar(csvar.pet_collections, afterStrCollections)
    gPet:SendData(unit)

    ShowMsg(unit, "<color=" .. cc.green .. ">".. cName .. " 완성!</color>\n" .. cm.statName[cStat[1]] .. " +" .. cStat[2] )
    PlaySE(unit, cse.success)
    unit.StartGlobalEvent(common.event.collection)
    unit.RefreshStats()

    ----------------------------------------------------------
    local logMsg = cName .. " Complete " .. (cm.statName[cStat[1]] .. " +" .. cStat[2])
    local logData = { 
        collection = collection,
        beforeCollections = dejson(strCollections), afterCollections = collections,
    }
    SendLog(unit, "Pet_Collection", logMsg, injson(logData))
end



--* 펫을 소환하고 결과를 저장하고, 클라이언트로 전송합니다.
--* useItem 아이템사용처리필요시 true / 상점에서 이미 결제된 경우 false 또는 nil
function gPet:Spawn(unit, itemID, count, useItem)
    if (not (unit and itemID)) or (not CheckUserSystemDelay(unit)) then return end
    ----------------------------------------------------------

    local count = count or 1
    local useItem = useItem and true or false
    local gType = useItem and 1 or 2

    local strLists = unit.GetStringVar( csvar.pet_lists )
    local lists = dejson(strLists)
    local strConfirms = unit.GetStringVar( csvar.pet_confirms )
    local confirms = dejson(strConfirms)
     
    local sdb = self.db.spawn[itemID]
    local haveItemCount = CountItem(unit, itemID)
    local itemName = GetItemName(itemID)
    local minConfirmRarity = table.firstkey(self.db.change)

    if not (sdb and (gType == 2 or haveItemCount >= count)) then
        ShowWrongRequestMsg(unit)
        return
    end

    local result = {}
    local sumRatio = math.sum(sdb)
    for i=1, count do
        local rnd = rand(1, sumRatio + 1)
        local ratio = 0
        for rarity, rt in pairs(sdb) do
            ratio = ratio + rt
            if rnd <= ratio then
                local tdb = self.db.rList[rarity]
                local code = tdb[ rand(1, #tdb + 1) ]
                table.insert(result, code)
                if minConfirmRarity <= rarity then
                    table.insert(confirms, { code = code, count = 0, ts = math.rounddown(GetTimeStamp()) } )
                else
                    if lists[code] then lists[code].count = lists[code].count and (lists[code].count + 1) or 1
                    else lists[code] = { count = 0 }
                    end
                end
                break 
            end
        end
    end

    if useItem then RemoveItem(unit, itemID, count) end
    local afterStrLists = injson(lists)
    local afterStrConfirms = injson(confirms)
    local strResult = injson(result)
    unit.SetStringVar(csvar.pet_lists, afterStrLists)
    unit.SetStringVar(csvar.pet_confirms, afterStrConfirms)
    unit.FireEvent( "Pet_Spawn", gType, strResult )

    ----------------------------------------------------------
    local logMsg = itemName .. " x" .. count .. " (" .. (gType == 1 and "Use Item" or "Shop") .. ")"
    local logData = {
        itemID = itemID, haveItemCount = haveItemCount, spawnCount = count, gType = gType, useItem = useItem, result = result,
        beforeList = dejson(strLists), afterList = lists,
        beforeConfirms = dejson(strConfirms), afterConfirms = confirms,
    }
    SendLog(unit, "Pet_Spawn", logMsg, injson(logData))
    SetUserSystemDelay(unit)

    return true
end


--* 장착된 펫을 소환합니다.
function gPet:SpawnEquippedPet(unit)
    unit.UnregisterPet(0)
    local nowPet = unit.GetStringVar( csvar.pet_equip )
    local data = self.db.list[nowPet]
    if not data then return end
    unit.SpawnPet(0, unit.x, unit.y, data.id, 0)
end


--* 펫 Ai
function gPet.AI(pet, ai, event)
    if event == AI_INIT then
        pet.name = ""
        pet.SendUpdated()
        ai.SetFollowMaster(true, 100, 400)
    end
    if event == AI_UPDATE then
        local master = ai.GetMasterUnit()
        pet.customData.characterID = pet.customData.characterID or pet.characterID
        pet.moveSpeed = master.moveSpeed + 50
        pet.SendUpdated()
    end
end
for code, data in pairs(GameData.pet.list) do
    Server.SetPetAI(data.id, gPet.AI)
end