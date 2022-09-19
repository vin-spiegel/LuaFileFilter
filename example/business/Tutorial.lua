---------------------------------------------------------------------------
-- Server Tutorial
---------------------------------------------------------------------------
-- <기록로그>
-- Tutorial_Clear
---------------------------------------------------------------------------

gTutorial = {}
gTutorial.db = {
    check = {

    },
    reward = {
        [1] = { memo = "NPC말걸기", var = 2, exp = 1, gold = 500 },
        [4] = { memo = "장비구입 및 착용", var = 5, exp = 1, gold = 1000 },
        [6] = { memo = "스킬구입 및 장착", var = 7, exp = 2, gold = 600 },
        [8] = { memo = "물약구입 및 사용설정", var = 9, exp = 3, gold = 1000 },
        [11] = { memo = "보스몬스터 처치", var = 12, exp = 3, gold = 1000 },
        [12] = { memo = "튜토리얼 끝", var = 13, exp = 0, gold = 0, item = {502, 1135, 1137, 1139, 1141}, },
    }
}

function gTutorial:Clear(unit, num)
    if not (unit and num) then return end
    local step = unit.GetVar(cvar.tutorial)
    if step ~= num then ShowWrongRequestMsg(unit) return end
    local sdb = self.db.reward[step]
    if not sdb then ShowWrongRequestMsg(unit) return end
    if sdb.exp then AddEXP(unit, sdb.exp) end
    if sdb.gold then AddGold(unit, sdb.gold) end
    if sdb.item then 
        if type(sdb.item) == "table" then
            for i, itemID in pairs(sdb.item) do
                AddItem(unit, itemID)
            end
        else
            AddItem(unit, sdb.item)
        end
    end
    unit.SetVar(cvar.tutorial, sdb.var)
    SendLog(unit, "Tutorial_Clear", "[" .. num .."] " .. sdb.memo)
end


function gTutorial:Check(unit, num, ...)
    if not (unit and num) then return end
    local step = unit.GetVar(cvar.tutorial)
    if step ~= num then ShowWrongRequestMsg(unit) return end
    local func = gTutorial.db.check[num]
    if not func then ShowWrongRequestMsg(unit) return end
    return func(unit, ...)
end


-- 장비 장착 여부 확인
gTutorial.db.check[4] = function(unit)
    if unit.CountItem(1501) <= 0 or unit.CountItem(1503) <= 0 then
        ShowErrMsg(unit, "무기와 갑옷을 모두 구입하여야합니다.")
        return false
    end
    if not (unit.IsEquippedItemByDataID(1501) and unit.IsEquippedItemByDataID(1503)) then
        ShowErrMsg(unit, "가방에서 무기와 갑옷을 모두 장착하여야합니다.")
        return false 
    end
    return true
end


-- 스킬 퀵슬롯 장착 여부 확인
gTutorial.db.check[6] = function(unit)
    local set = GetEquipSkills(unit, GetSkillSetNumber(unit))
    local findSkill = false
    for i=1, 4 do
        if set.active[i] == "slash" or set.active[i] == "fireball" then
            findSkill = true
            break
        end
    end
    if findSkill == false then        
        ShowErrMsg(unit, "스킬을 구입 후 가방에서 배우고,\n스킬UI를 통해 퀵슬롯에 장착하여야합니다.")
        return false
    end
    return findSkill
end


-- 포션 구입 및 조절 여부 확인
gTutorial.db.check[8] = function(unit)
    local _, limitHP = gNPCShop:CheckResetLimit(unit, "tuto_hp_potion")
    local _, limitMP = gNPCShop:CheckResetLimit(unit, "tuto_mp_potion")
    if not (limitHP and limitHP.count >= 300 and limitMP and limitMP.count >= 300) then
        ShowErrMsg(unit, "체력물약과 마력물약을 300개씩 구입하여야 합니다.")
        return false
    end
    -- local hpUsePer = unit.GetVar(cvar.potion_hpUsePer)
    -- local mpUsePer = unit.GetVar(cvar.potion_mpUsePer)
    -- local isPotion = (hpUsePer ~= 0 and hpUsePer ~= 70 and mpUsePer ~= 0 and mpUsePer ~= 70) and true or false
    -- if not isPotion then
    --     ShowErrMsg(unit, "물약 설정(▲) 버튼을 터치하여\n체력물약과 마력물약의 사용 설정(%)를 변경해야 합니다.")
    --     return false
    -- end
    return true
end



--* 튜토리얼 몬스터 AI
function AI_Tutorial(enemy, ai, event, data)
    if event == AI_INIT then
        local level = GetMonsterLevel(enemy.maxMP)
        enemy.name = "<size=11><color=#F3F781>LV " .. level .. "</color></size>\n" .. enemy.name
        enemy.SendUpdated()
    end
    if event == AI_UPDATE then
    end
    if event == AI_ATTACKED then
        local target = ai.GetTargetUnit() 
        local attacker = ai.GetAttackedUnit() 
        if (target == nil and attacker)
        or (target and attacker and target ~= attacker and rand(1, 101) <= 1) then
            ai.SetTargetUnit(attacker)
            ai.SetFollowTarget(true)
        end
    end
    if event == AI_DEAD then
        local field = enemy.field
        if enemy.monsterID == 11 then
            field.SetFieldVar(1, field.GetFieldVar(1) + 1)
            field.SetFieldVar(11, field.GetFieldVar(11) - 1)
        else
            field.SetFieldVar(2, field.GetFieldVar(2) + 1)
            field.SetFieldVar(12, field.GetFieldVar(12) - 1)
        end
    end
end
Server.SetMonsterAI(11, AI_Tutorial)
Server.SetMonsterAI(12, AI_Tutorial)


function gTutorial:Reset3Step(unit)
    if not (unit) then return end
    unit.SpawnAtFieldID(86, 35*32+10, 20*-32-10)
    unit.SpawnAtFieldID(87, 34*32+10, 39*-32-10)
    ShowMsg(unit, "튜토리얼 3단계가 초기화되었습니다.\n다시 NPC에게 말을걸어 진행해주세요.")
end
