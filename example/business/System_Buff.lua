--------------------------------------------------------------------------------
-- Server Buff
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- UseItem_Buff
--------------------------------------------------------------------------------

gBuff = {}
gBuff.db = GameData.buff


--* 적용중인 버프를 체크합니다.
--* Loop에서 2초마다 실행합니다.
function gBuff:CheckBuff(unit)
    local now = GetTimeStamp()
    for code, data in pairs(self.db) do
        local var = unit.GetVar(data.var)
        local buff = unit.HasBuff(data.buffID)
        if var >= now and (not buff) then
            unit.AddBuff(data.buffID)
        elseif var < now and buff then
            unit.RemoveBuff(data.buffID)
        end
    end
end


--* 유닛의 버프 정보를 반환합니다.
function gBuff:GetBuffData(unit)
    local t = {}
    local ts = math.rounddown( GetTimeStamp() )
    for code, data in pairs(self.db) do
        local endTime = unit.GetVar(data.var)
        local haveTime = math.max(0, endTime - ts)
        if haveTime > 0 then t[code] = haveTime end
    end
    return t
end


--* 버프 스탯을 계산합니다.
function gBuff:CatStats(unit, stats)
    -- 자동
    for code, data in pairs(self.db) do
        if unit.HasBuff(data.buffID) and data.stat then
            for _, o in pairs(data.stat) do
                stats[o[1]] = stats[o[1]] and (stats[o[1]] + o[2]) or o[2]
            end
        end
    end
    -- 수동
end


--* 버프 아이템을 사용합니다.
function gBuff:UseItem(unit, dataID, useCount)
    if not (unit and dataID and useCount and CheckUserSystemDelay(unit)) then return end

    local itemName = GetItemName(dataID)
    local itemData = GetItemData(dataID)
    local itemBuffData = itemData.buff
    if not itemBuffData then return end
    local data = self.db[itemBuffData.code]
    local addTime = itemBuffData.addTime * useCount
    local nowTs = math.rounddown( GetTimeStamp() )
    local nowVar = unit.GetVar(data.var)
    local targetVar = math.floor( nowVar > nowTs and (nowVar + addTime) or (nowTs + addTime) )

    unit.SetVar(data.var, targetVar)
    RemoveItem(unit, dataID, useCount)
    ShowRemoveItemMsg(unit, dataID, useCount)
    gBuff:CheckBuff(unit)
    PlaySE(unit, cse.drink)
    OpenBag(unit)

    local logMsg = "[" .. dataID .. "] " .. itemName .. " x" .. useCount
    local logData = gBuff:GetBuffData(unit)
    SendLog(unit, "UseItem_Buff", logMsg, logData)
    SetUserSystemDelay(unit)
end






















