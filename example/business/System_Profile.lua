--------------------------------------------------------------------------------
-- Server Profile
--------------------------------------------------------------------------------

gProfile = {}

Server.GetTopic("Profile_GetData").Add(function(targetID) gProfile:SendData(unit, targetID) end)
Server.GetTopic("Profile_Equip").Add(function(itemID) gProfile:EquipItem(unit, itemID) end)
Server.GetTopic("Profile_Unequip").Add(function(itemID) gProfile:UnequipItem(unit, itemID) end)


--* 클라이언트로 타겟 Unit의 정보를 전송합니다.
function gProfile:SendData(unit, targetID, onlyUpdate)
    local targetUnit = (not targetID) and unit or GetPlayerUnit(targetID)
    local data = gProfile:GetUnitData(targetUnit)
    if not data then
        ShowErrMsg(unit, "플레이어가 오프라인 상태입니다.")
        unit.FireEvent("Profile_Destroy")
        return
    end
    local bag = {}
    if targetUnit == unit then
        for i, item in pairs(unit.player.GetItems()) do
            local data = GetItemData(item)
            if data.type and data.type >= 100 then
                bag[tostring(item.id)] = ItemToTable(item)
                bag[tostring(item.id)].isEquipped = unit.IsEquippedItem(item.id)
            end
        end
    end
    unit.FireEvent("Profile_SendData", onlyUpdate, targetID, injson(data), injson(bag))
end


--* 지정된 유닛의 프로필 데이터들을 받아 반환합니다.
function gProfile:GetUnitData(unit)
    if not unit then return end
   
    local data = {}

    data.id = unit.player.id
    data.name = string.infilter(unit.player.name)
    data.level = unit.level
    data.cp = unit.GetVar(cvar.cp)
    data.clan = unit.player.clan and string.infilter(unit.player.clan.name) or ""

    data.avatar = unit.characterID
    data.aura = unit.GetStringVar( csvar.aura_equip )
    data.pet = unit.GetStringVar( csvar.pet_equip )

    data.arcana = dejson(unit.GetStringVar( csvar.equip_arcana ))

    data.artifact = {}
    for code, dt in pairs(GameData.artifact) do
        data.artifact[code] = unit.GetVar(dt.levelVar)
    end
   
    data.stat = {}
    for statID, name in pairs(common.statName) do
        if name ~= "???" then
            data.stat[tostring(statID)] = math.round(unit.GetStat(statID), 1)
        end
    end

    data.equip = {}
    for slotNum = 0, 9 do
        local equipItem = unit.GetEquipItem(slotNum)
        if equipItem then
            data.equip[tostring(slotNum)] = ItemToTable(equipItem)
        end
    end

    data.sequip = {}
    for slotNum, itemID in pairs(unit.customData.special_equipment) do
        local equipItem = unit.player.GetItem(itemID)
        if equipItem then
            data.sequip[tostring(slotNum)] = ItemToTable(equipItem)
        end
    end

    return data 
end


--* 프로필에서 아이템을 장착합니다.
function gProfile:EquipItem(unit, itemID)
    if (not ( unit and itemID and CheckUserSystemDelay(unit) )) then return end
    local itemID = tonumber(itemID)
    local item = unit.player.GetItem(itemID)
    local itemData = GetItemData(item)
    if not item then return end
    if itemData.reqLevel and itemData.reqLevel > unit.level then
        ShowReqLevelMsg(unit, itemData.reqLevel)
        return false
    end
    unit.EquipItem(itemID)
    gProfile:SendData(unit, nil, true)
    PlaySE(unit, cse.equip)
    SetUserSystemDelay(unit)
end


--* 프로필에서 아이템을 장착해제합니다.
function gProfile:UnequipItem(unit, itemID)
    if (not ( unit and itemID and CheckUserSystemDelay(unit) )) then return end
    local itemID = tonumber(itemID)
    local item = unit.player.GetItem(itemID)
    local itemData = GetItemData(item)
    if not item then return end
    unit.UnequipItem(itemID)
    gProfile:SendData(unit, nil, true)
    PlaySE(unit, cse.equip)
    SetUserSystemDelay(unit)
end

























