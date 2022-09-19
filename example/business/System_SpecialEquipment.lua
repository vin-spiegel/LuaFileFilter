--------------------------------------------------------------------------------
-- Special Equipment
--------------------------------------------------------------------------------
-- (1) 허리띠 (2) 귀걸이 (3) 팔찌 (4) 견장 (5) 망토
--------------------------------------------------------------------------------

gSpecialEquipment = {}



----* 특수장비를 장착/장착해제합니다.
function gSpecialEquipment.Equip(unit, item)
    local item = type(item) == "number" and unit.player.GetItem(item) or item
    local itemData = GetItemData(item)
    local sedb = itemData.specialEquipment
    if not (sedb and sedb[2] == false) then return end
    local slotID = sedb[1]
    unit.customData.special_equipment = unit.customData.special_equipment or {}
    local t = unit.customData.special_equipment
    if t[slotID] then gSpecialEquipment.UnEquip(unit, t[slotID]) end
    t[slotID] = item.id
    item.dataID = item.dataID + 1
    unit.player.SendItemUpdated(item)
    PlaySE(unit, cse.equip)
    unit.RefreshStats()
end
function gSpecialEquipment.UnEquip(unit, item)
    local item = type(item) == "number" and unit.player.GetItem(item) or item
    local itemData = GetItemData(item)
    local sedb = itemData.specialEquipment
    if not (sedb and sedb[2] == true) then return end
    local slotID = sedb[1]
    unit.customData.special_equipment = unit.customData.special_equipment or {}
    unit.customData.special_equipment[slotID] = nil
    item.dataID = item.dataID - 1
    unit.player.SendItemUpdated(item)
    PlaySE(unit, cse.equip)
    unit.RefreshStats()
end

for dataID, data in pairs(GameData.item) do
    if data.specialEquipment then 
        if data.specialEquipment[2] then
            gUseItem.func[dataID] = gSpecialEquipment.UnEquip
        else
            gUseItem.func[dataID] = gSpecialEquipment.Equip
        end
    end
end


----* 장착중인 특수부위 장비를 커스텀데이터에 저장합니다.
function gSpecialEquipment:SaveData(unit)
    unit.customData.special_equipment = unit.customData.special_equipment or {}
    local t = unit.customData.special_equipment
    for i, item in pairs(unit.player.GetItems()) do
        local itemData = GetItemData(item)
        local sedb = itemData.specialEquipment
        if sedb and sedb[2] then
            t[sedb[1]] = item.id
        end
    end
    return t 
end


----* 장착중인 특수부위 장비의 스탯을 계산합니다.
function gSpecialEquipment:CalStats(unit, stats)
    local equips = unit.customData.special_equipment or gSpecialEquipment:SaveData(unit) or {}
    local notFindItem = false
    for slotNum, id in pairs(equips) do
        local item = unit.player.GetItem(id)
        if item then
            local itemData = GetItemData(item.dataID)
            if itemData and itemData.stat then
                for _, o in pairs(itemData.stat) do
                    stats[o.statID] = stats[o.statID] + o.value
                end
            end
            if item.options and #item.options >= 1 then
                for _, o in pairs(item.options) do
                    stats[o.statID] = stats[o.statID] + o.value
                end
            end
        else
            notFindItem = true
        end
    end
    if notFindItem then
        gSpecialEquipment:SaveData(unit)
    end
    return stats
end













