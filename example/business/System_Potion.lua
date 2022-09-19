--------------------------------------------------------------------------------
-- Server Potion
--------------------------------------------------------------------------------

gPotion = {}

Server.GetTopic("Potion_SaveSetting").Add(function(...) gPotion:SaveSetting(...) end)


--* 물약 자동 사용 설정을 저장합니다.
function gPotion:SaveSetting(rtype, potionID, usePer)
    unit.SetVar(rtype == 1 and cvar.potion_hpEquip or cvar.potion_mpEquip, potionID)
    unit.SetVar(rtype == 1 and cvar.potion_hpUsePer or cvar.potion_mpUsePer, usePer)
    unit.FireEvent("update_potion", injson( GetPotionSetting(unit) ))
end


-- 포션 장착, 사용설정, 보유 데이터를 반환합니다. (Loop 에서 처리)
function GetPotionSetting(unit)
    local data = {
        equip = { hp = unit.GetVar(cvar.potion_hpEquip), mp = unit.GetVar(cvar.potion_mpEquip), },
        usePer = { hp = unit.GetVar(cvar.potion_hpUsePer), mp = unit.GetVar(cvar.potion_mpUsePer), },
        have = {},
    }
    for dataID = 1401, 1440 do
        data.have[tostring(dataID)] = unit.CountItem(dataID) or nil
    end
    data.equip.hp = data.equip.hp == 0 and 1401 or data.equip.hp
    data.equip.mp = data.equip.mp == 0 and 1402 or data.equip.mp
    data.usePer.hp = data.usePer.hp == 0 and 70 or data.usePer.hp
    data.usePer.mp = data.usePer.mp == 0 and 70 or data.usePer.mp
    return data
end
















