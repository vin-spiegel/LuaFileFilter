-----------------------------------------------------------------------------------------------
-- Server CS
-----------------------------------------------------------------------------------------------
-- < 기록 로그 > 
-- CS_RegEmail
-- CS_DestroyItem
-----------------------------------------------------------------------------------------------

gCS = {}

Server.GetTopic("CS_RegEmail").Add(function(email) gCS:RegEmail(unit, email) end)
Server.GetTopic("CS_DestroyItem").Add(function(targetID, targetCount) gCS:DestroyItem(unit, targetID, targetCount) end)
Server.GetTopic("CS_DestroyItemGetData").Add(function() gCS:DestroyItemSendData(unit) end)



--* 이메일 출력
function gCS:ShowMyEmail(unit)
    local email = unit.GetStringVar(csvar.email)
    unit.FireEvent("ShowAlert", (email and email ~= "") and ("등록된 이메일: " .. email) or "등록된 이메일이 없습니다.")
end


--* 이메일 등록
function gCS:RegEmail(unit, email)
    if not (unit and email and email ~= "" and CheckUserSystemDelay(unit)) then return end

    local email = string.infilter(email)
    unit.SetStringVar(csvar.email, email) 
    PlaySE(unit, cse.signal)
    ShowMsg(unit, "이메일이 정상적으로 등록되었습니다.", cc.green)
    SendLog(unit, "CS_RegEmail", email, email)
    gCS:ShowMyEmail(unit)

    SetUserSystemDelay(unit)
end


--* 클라이언트로 파괴가 가능한 아이템 데이터를 전송합니다.
function gCS:DestroyItemSendData(unit)
    local data = {}
    for _, item in pairs(unit.player.GetItems()) do
        if not unit.IsEquippedItem(item.id) then
            data[tostring(item.id)] = ItemToTable(item)
        end
    end
    unit.FireEvent("CS_DestroyItemSendData", injson(data))
end


--* 아이템파괴
function gCS:DestroyItem(unit, targetID, targetCount)
    if not (unit and targetID and targetCount and CheckUserSystemDelay(unit)) then return end

    local targetID = tonumber(targetID)
    local item = unit.player.GetItem(targetID)
    local targetCount = math.rounddown(targetCount)
    
    if (not item) or targetCount < 1 then
        ShowWrongRequestMsg(unit)
        return
    end

    if unit.IsEquippedItem(item.id) then
        ShowErrMsg(unit, "장착된 아이템은 파괴할 수 없습니다.")
        return
    end

    local haveCount = item.count
    if haveCount < targetCount then
        ShowErrMsg(unit, "보유한 아이템 개수가 부족합니다.")
        return
    end

    local titem = ItemToTable(item)
    local itemName = GetItemName(item)

    unit.RemoveItemByID( targetID, targetCount )
    PlaySE(unit, cse.decom)
    ShowMsg(unit, "아이템이 파괴되었습니다.", cc.orange)

    local logMsg = itemName .. " x" .. targetCount
    local logData = {
        titem = titem,
        itemName = itemName, 
        haveCount = haveCount,
        useCount = targetCount,
    }

    SendLog(unit, "CS_DestroyItem", logMsg, injson(logData))
    SetUserSystemDelay(unit)
    
    unit.FireEvent("CS_DestroyItem", targetID, targetCount)
    unit.FireEvent("CS_DestroyItemUIDestroy")
end
