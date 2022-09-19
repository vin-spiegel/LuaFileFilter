--------------------------------------------------------------------------------
-- Server Decompostion
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Decomp
--------------------------------------------------------------------------------

gDecomp = {}


Server.GetTopic("Decomp_GetData").Add(function() gDecomp:SendData(unit) end)
Server.GetTopic("Decomp_Go").Add(function(strList) gDecomp:Go(unit, strList) end)
Server.GetTopic("Decomp_GetAutoDecompData").Add(function() gDecomp:SendAutoDecompData(unit) end)
Server.GetTopic("Decomp_AutoSetting").Add(function(id, var) gDecomp:SettingAuto(unit, id, var) end)


--* 클라이언트로 분해가 가능한 보유 아이템 정보를 전송합니다.
function gDecomp:SendData(unit)
    local data = {}
    for _, item in pairs(unit.player.GetItems()) do
        local itemData = GetItemData(item)
        if itemData and itemData.decomp and (not unit.IsEquippedItem(item.id)) then
            data[ tostring(item.id) ] = ItemToTable(item)
        end
    end
    unit.FireEvent("Decomp_SendData", injson(data))
end


--* 클라이언트에서 선택된 아이템들을 분해합니다.
function gDecomp:Go(unit, strList)
    if not (unit and strList and CheckUserSystemDelay(unit)) then return end

    -- 분해 대상 아이템 검증, 분해 결과 계산
    local decompList = dejson(strList)
    local resultList = {}
    for _, titem in pairs(decompList) do
        local item = unit.player.GetItem(titem.id)
        local itemData = GetItemData(item or -1)
        local decompData = type(itemData) == "table" and itemData.decomp or nil
        if (not item) or (not decompData) or item.count < titem.decompCount or titem.decompCount < 1 then
            ShowErrMsg(unit, "선택된 아이템의 정보가 변경되었습니다.\n창을 완전히 닫고 다시 시도해주세요.")
            return
        end
        local resultData = decompData.result
        for _, r in pairs( type(resultData[1]) == "number" and { resultData } or resultData ) do
            local strDataID, cnt = tostring(r[1]), r[2]
            local minCount = (type(cnt) == "table" and cnt[1] or cnt) * titem.decompCount
            local maxCount = (type(cnt) == "table" and cnt[2] or cnt) * titem.decompCount
            local targetCount = minCount ~= maxCount and rand(minCount, maxCount + 1) or minCount
            resultList[strDataID] = resultList[strDataID] and (resultList[strDataID] + targetCount) or targetCount
        end
    end

    -- 아이템 회수, 보상지급
    local decompItemCount = 0
    for _, titem in pairs(decompList) do
        decompItemCount = decompItemCount + 1
        unit.RemoveItemByID(titem.id, titem.decompCount, false)
    end
    for strDataID, count in pairs(resultList) do
        AddItem(unit, tonumber(strDataID), count) 
    end

    ShowMsg(unit, decompItemCount .. " 종류의 아이템이 모두 분해되었습니다.")
    PlaySE(unit, cse.decom)
    unit.StartGlobalEvent(cevent.quake)
    ShowItemPopup(unit, resultList)
    unit.FireEvent("Decomp_End", strList)

    local logData = { result = resultList, target = decompList }
    SendLog(unit, "Decomp_Go", "Decomp " .. decompItemCount .. " Items", injson(logData))
    SetUserSystemDelay(unit)
end


--* 자동분해용, 아이템id와 count를 받아 분해결과를 반환합니다.
function gDecomp:GetResult(dataID, count)
    local resultList = {}
    local itemData = GetItemData(dataID or -1)
    local decompData = type(itemData) == "table" and itemData.decomp or nil
    if not decompData then return resultList end
    local resultData = decompData.result
    for _, r in pairs( type(resultData[1]) == "number" and { resultData } or resultData ) do
        local strDataID, cnt = tostring(r[1]), r[2]
        local minCount = (type(cnt) == "table" and cnt[1] or cnt) * count
        local maxCount = (type(cnt) == "table" and cnt[2] or cnt) * count
        local targetCount = minCount ~= maxCount and rand(minCount, maxCount + 1) or minCount
        resultList[strDataID] = resultList[strDataID] and (resultList[strDataID] + targetCount) or targetCount
    end
    return resultList
end


--* 자동분해관련 데이터를 전송합니다.
function gDecomp:SendAutoDecompData(unit)
    local list = {}
    for id, data in pairs(GameData.decomp.auto) do
        list[tostring(id)] = unit.GetVar(data.var)
    end
    unit.FireEvent("Decomp_SendAutoDecompData", injson(list))
end


--* 자동분해 관련 셋팅
function gDecomp:SettingAuto(unit, id, var)
    if not (unit and id and var and CheckUserSystemDelay(unit)) then return end
    local id = id == "arcana" and id or tonumber(id)
    local data = GameData.decomp.auto[id]
    if not data then ShowWrongRequestMsg(unit) return end
    local var = math.setrange(var, 0, 4)
    unit.SetVar(data.var, var)
    gDecomp:SendAutoDecompData(unit)
    SendLog(unit, "Decomp_AutoSetting", id .. " " .. var)
    SetUserSystemDelay(unit)
end












