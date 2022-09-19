--------------------------------------------------------------------------------
-- Server Skill
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Skill_Learn
--------------------------------------------------------------------------------

gSkill = {}
gSkill.db = GameData.skill

Server.GetTopic("Skill_GetData").Add(function() gSkill:SendData(unit) end)
Server.GetTopic("Skill_ResetNekoSkills").Add(function() ResetNekoSkills(unit) end)
Server.GetTopic("Skill_ResetQuickSlot").Add(function() ResetNekoSkills(unit) ResetQuickSlots(unit) end)
Server.GetTopic("Skill_EquipSkill").Add(function(...) EquipSkill(unit, ...) end)
Server.GetTopic("Skill_UnequipSkill").Add(function(...) UnequipSkill(unit, ...) end)
Server.GetTopic("Skill_ChangeSet").Add(function(...) ChangeSkillSet(unit, ...) end)


--------------------------------------------------------------------------------
-- Skill 관련 Utility
--------------------------------------------------------------------------------

--* 스킬관련 변경이 가능한 장소인지 판단합니다.
function CanChangeSkill(unit, notify)
    local mdb = GameData.field[unit.field and unit.field.dataID or -1]
    local canChange = (not (mdb and mdb.customSkillSlot)) and true or false
    if (not canChange) and notify then
        ShowErrMsg(unit, "현재 장소에서 사용할 수 없습니다.")
    end
    return canChange, (mdb and mdb.customSkillSlot or nil)
end


--* 현재 스킬 셋 번호를 가져옵니다.
function GetSkillSetNumber(unit)
    return math.setrange(unit.GetVar( cvar.skill_set ), 1, 6)
end


--* 보유 스킬 리스트를 반환합니다.
function GetHaveSkills(unit)
    return dejson( unit.GetStringVar( csvar.skill_haveList ))
end


--* 장착 스킬 리스트를 반환합니다.
function GetEquipSkills(unit, setNum)
    local setNum = setNum and math.setrange(setNum, 1, 6) or nil
    local equipSkills = dejson( unit.GetStringVar( csvar.skill_equipList ) )

    local changed = false 
    for i=1, 6 do
        if not equipSkills[i] then
            equipSkills[i] = { active = {-1, -1, -1, -1, -1, -1, -1, -1}, passive = {-1, -1, -1, -1}, }
            changed = true
        end
    end

    if changed then
        unit.SetStringVar(csvar.skill_equipList, injson(equipSkills))
    end
    
    return setNum and equipSkills[setNum] or equipSkills
end


--* 네코랜드 스킬을 초기화합니다. (초기화 후 현재 스킬셋 번호대로 스킬 지급)
function ResetNekoSkills(unit)
    local setNum = GetSkillSetNumber(unit)
    local equipSkills = GetEquipSkills(unit, setNum)
    unit.RemoveAllSkills()
    unit.AddSkill( 0, 1, false )
    for i = 1, 2 do
        for slotNum, code in pairs(equipSkills[i == 1 and "active" or "passive"]) do
            local data = GetSkillData(code)
            if data then
                unit.AddSkill( data.skillID, 1, false )
            end
        end
    end

    -- 선타스킬 
    unit.AddSkill( 491, 1, false )
    unit.AddSkill( 492, 1, false )
    unit.AddSkill( 493, 1, false )
    unit.AddSkill( 494, 1, false )
end


--* 네코랜드 퀵슬롯을 초기화합니다.
function ResetQuickSlots(unit)
    local isCustomSkill, customSkill = CanChangeSkill(unit)
    if (not isCustomSkill) and customSkill then
        for i=0, 7 do
            local skillID = customSkill[i+1] or -1
            skillID = skillID ~= -1 and skillID or nil
            unit.SetQuickSlot( skillID and 2 or 0, i, skillID )
        end
        return
    end

    local setNum = GetSkillSetNumber(unit)
    local equipSkills = GetEquipSkills(unit, setNum)
    local canUseSlotData = GameData.skill.slotLevel[ unit.GetVar( cvar.class ) ]
    local canUseSlotCount = canUseSlotData and canUseSlotData.active or 4
    for i = 0, 7 do
        local skillCode = equipSkills.active[ i + 1 ] or nil
        local skillData = skillCode and GetSkillData(skillCode) or nil
        local skillID = skillData and skillData.skillID or nil
        if (i + 1) > canUseSlotCount then
            unit.SetQuickSlot( 2, i, 0 )
        else
            unit.SetQuickSlot( skillID and 2 or 0, i, skillID )
        end        
    end
end


--* 스킬을 장착합니다. 
function EquipSkill(unit, skillType, slotNum, skillCode)
    if not CanChangeSkill(unit, true) then return end

    local skillData = GetSkillData(skillCode)
    if skillType ~= skillData.type then return end

    local skillTypeName = skillType == 1 and "active" or "passive"
    local setNum = GetSkillSetNumber(unit)
    local slotNum = math.setrange(slotNum, 1, skillType == 1 and 8 or 4)
    local haveSkills = GetHaveSkills(unit)
    local canUseSlotCount = GameData.skill.slotLevel[unit.GetVar(cvar.class)]

    if (not haveSkills[skillCode]) or (canUseSlotCount[skillTypeName] < slotNum) then
        ShowWrongRequestMsg(unit)
        return
    end
    
    local allEquipSkills = GetEquipSkills(unit)
    local unique = skillData.unique
    if unique then
        for i, code in pairs(allEquipSkills[setNum][skillTypeName]) do
            local data = GetSkillData(code)
            if data and data.unique and data.unique == unique and code ~= skillCode and slotNum ~= i then
                ShowErrMsg(unit, '고유장착명이 <color=' .. cc.yellow .. '>"' .. unique .. '"</color>인 스킬은\n하나만 장착 가능합니다.' )
                return false
            end
        end
    end

    allEquipSkills[setNum][skillTypeName][slotNum] = skillCode
    for i, code in pairs(allEquipSkills[setNum][skillTypeName]) do -- 중복착용 제외
        if i ~= slotNum and code == skillCode then
            allEquipSkills[setNum][skillTypeName][i] = -1
        end
    end

    unit.SetStringVar(csvar.skill_equipList, injson(allEquipSkills))
    ResetNekoSkills(unit)
    ResetQuickSlots(unit)
    gSkill:SendData(unit, false)

    if skillType == 2 then
        unit.RefreshStats()
    end
    if skillCode == "tiny_margin" then
        unit.customData.tiny_margin_count = nil -- 구사일생 카운트 초기화
    end
end


--* 스킬을 해제합니다.
function UnequipSkill(unit, skillType, slotNum)
    if not CanChangeSkill(unit, true) then return end

    local skillTypeName = skillType == 1 and "active" or "passive"
    local setNum = GetSkillSetNumber(unit)
    local slotNum = math.setrange(slotNum, 1, skillType == 1 and 8 or 4)
    local allEquipSkills = GetEquipSkills(unit)
    local skillCode = allEquipSkills[setNum][skillTypeName][slotNum]
    allEquipSkills[setNum][skillTypeName][slotNum] = -1
    unit.SetStringVar(csvar.skill_equipList, injson(allEquipSkills))
    ResetNekoSkills(unit)
    ResetQuickSlots(unit)
    gSkill:SendData(unit, false)
    
    if skillType == 2 then
        unit.RefreshStats()
    end
    if skillCode == "tiny_margin" then
        unit.customData.tiny_margin_count = nil -- 구사일생 카운트 초기화
    end
end


--* 스킬셋을 변경합니다.
function ChangeSkillSet(unit, set)
    if not CanChangeSkill(unit, true) then return end
    local setNum = math.setrange(set, 1, 6)
    unit.SetVar( cvar.skill_set, setNum )
    ResetNekoSkills(unit)
    ResetQuickSlots(unit)
    gSkill:SendData(unit, false)
    unit.RefreshStats()

    unit.customData.tiny_margin_count = nil -- 구사일생 카운트 초기화
end



--------------------------------------------------------------------------------



--* 클라이언트로 보유스킬, 장착스킬, 현재스킬셋번호를 전송합니다.
function gSkill:SendData(unit, reset)
    local reset = (not (reset == false)) and true or false
    unit.FireEvent("Skill_SendData", reset, injson(GetHaveSkills(unit)), injson(GetEquipSkills(unit)), GetSkillSetNumber(unit), unit.GetVar(cvar.class) )
end


--* 특정 Skill을 배웁니다.
function gSkill:LearnSkill(unit, skillCode, notify, openUI)
    local notify = (not (notify == false)) and true or false
    local openUI = (not (openUI == false)) and true or false
    
    local db = self.db.list[ skillCode ]
    if not db then
        ShowWrongRequestMsg(unit)
        return false
    end
    
    local var = dejson(unit.GetStringVar( csvar.skill_haveList ))
    if var[skillCode] then
        ShowErrMsg(unit, "이미 보유한 스킬입니다.")
        return false
    end
    
    var[skillCode] = {}
    local afterStrVar = injson(var)
    unit.SetStringVar(csvar.skill_haveList, afterStrVar)

    if notify then
        ShowMsg(unit, '"' .. db.name .. '"스킬을 습득했습니다!!', cc.green)
        PlaySE(unit, cse.signal)
    end

    if openUI then
        unit.FireEvent("Skill_OpenUI", skillCode)
    end

    SendLog(unit, "Skill_Learn", skillCode, afterStrVar)
    return var
end


--* 스킬 사용 시 발생하는 이벤트입니다.
function gSkill:UsedSkill(unit, skillID)
    local data = GetSkillData(skillID) or self.db.equipList[skillID]

    if unit.HasSkill(44) then -- 마력 폭주
        local chp = data.consumeHP or 0
        local cmp = data.consumeMP or 0
        if chp > 0 then unit.AddHP( -1 * chp * 2) end 
        if cmp > 0 then unit.AddMP( -1 * cmp * 2) end 
    end

    if unit.HasSkill(67) and rand(1, 101) <= 7 then -- 넘쳐나는금화
        local useGold = rand(100, 999+1)
        RemoveGold(unit, useGold)
        local damage = useGold / 10 / 100 * 150
        unit.customData.overflowing_gold = damage
        unit.FireEvent("UseSkill", 498, nil, nil, true)
        SendPush(unit, "[넘쳐나는금화] " .. useGold .. "소모 (피해량 " .. damage .."%)")
    end

    if skillID == 90 then Server.RunLater(function() unit.FireEvent("UseSkill", 496) end, 0.3) end
    if skillID == 87 then unit.FireEvent("UseSkill_poison_zone") end

    if unit.customData.equipSkills then
        for slotNum, dt in pairs(unit.customData.equipSkills) do
            if dt.code == "dragon" then
                local rate = dt.rateW * (data.cooldown or 0) / 100 * 10000
                local rnd = rand(1, 10001)
                if rnd <= rate then
                    unit.FireEvent("UseSkill", dt.skillID)
                end
            end
        end
    end
    
    if not data.useFunc then return end
    data.useFunc(unit)
end


--* 회복술, 명상술
-- a = function() local c = math.min(2500, unit.mp * 0.2) local r = math.rounddown(1000 + c*2) unit.AddMP(c * -1) unit.AddHP(r) SendPush(unit,  "체력 " .. math.comma(r) .. " 회복") end
-- a = function() local c = math.min(5000, unit.hp * 0.1) local r = math.rounddown(500 + c/2) unit.AddHP(c * -1) unit.AddMP(r) SendPush(unit,  "마력 " .. math.comma(r) .. " 회복") end
-- a = function() local c = math.min(7500, unit.mp * 0.2) local r = math.rounddown(3000 + c*2) unit.AddMP(c * -1) unit.AddHP(r) SendPush(unit,  "체력 " .. math.comma(r) .. " 회복") end
-- a = function() local c = math.min(15000, unit.hp * 0.1) local r = math.rounddown(1500 + c/2) unit.AddHP(c * -1) unit.AddMP(r) SendPush(unit,  "마력 " .. math.comma(r) .. " 회복") end









