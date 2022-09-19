--------------------------------------------------------------------------
-- Server PVP
--------------------------------------------------------------------------

gPVP = {}


Server.GetTopic("PK_On").Add(function(isForce) gPVP:SetPK(unit, 1, isForce) end)
Server.GetTopic("PK_Off").Add(function(isForce) gPVP:SetPK(unit, 0, isForce) end)
Server.GetTopic("PVP_GetData").Add(function() gPVP:SendData(unit) end)


--* PK 를 On 하거나 Off 합니다.
function gPVP:SetPK(unit, kind, isForce)
    if not (unit and kind) then return end
    if (not isForce) and (not CheckUserSystemDelay(unit)) then return end 
    
    local fieldID = unit.field and unit.field.dataID or 3
    local mdb = GameData.field[fieldID]
    
    local mode = unit.GetVar(cvar.pvp_mode)
    local lastSet = unit.GetVar(cvar.pvp_delay)
    local nowTs = GetTimeStamp()

    local afterMode = 0
    if kind == 1 and mode == 0 then
        if not mdb.canPVP then
            ShowErrMsg(unit, "이 장소에서는 PK 설정이 불가합니다.")
            return
        end
        afterMode = 1
        unit.SetVar(cvar.pvp_delay, nowTs*100)
        PlaySE(unit, cse.pkOn) 
    elseif kind == 0 and mode == 1 then
        if mdb.mustPVP then
            ShowErrMsg(unit, "PK 해제가 불가한 장소입니다.")
            return
        end
        local delay = (lastSet/100 + 5) - nowTs
        if (not isForce) and mdb.canPVP and delay > 0 then
            ShowErrMsg(unit, "PK 설정 대기시간 중 입니다.\n<color=" .. cc.white .. "><size=14>(" .. math.roundup(delay).."초 후 가능)</size></color>")
            return
        end
        afterMode = 0
        if not isForce then PlaySE(unit, cse.click) end
    end

    unit.SetVar(cvar.pvp_mode, afterMode)
    unit.teamTag = afterMode == 0 and 1 or 0
    unit.FireEvent(afterMode == 0 and "PK_Off" or "PK_On")
    gRefreshStat:SetName(unit)
    SetUserSystemDelay(unit)
end


--* Loop: 주기적으로 PK 가능 장소인지 체크합니다.
function gPVP:Check(unit)
    local fieldID = unit.field and unit.field.dataID or 3
    local mdb = GameData.field[fieldID]
    local mode = unit.GetVar(cvar.pvp_mode)
    if mode == 1 and (not mdb.canPVP) then
        gPVP:SetPK(unit, 0, true)
    end 
end


--* 클라이언트로 PVP 기록 데이터를 전송합니다.
function gPVP:SendData(unit)
    unit.FireEvent("PVP_SendData", unit.GetStringVar(csvar.pvp_log))
end


--* 플레이어간 사망/처치시 기록을 저장합니다.
function gPVP:Logging(a, b)
    if not (a.type == 0 and b.type == 0) then return end
    local fieldName = a.field and string.infilter(a.field.name) or ""
    local time = os.time()
    local maxCount = 50

    -- 공격자 로깅
    do
        local var = dejson(a.GetStringVar(csvar.pvp_log))
        local data = { type = 1, name = string.infilter(b.player.name), field = fieldName, ts = time }
        table.insert(var, 1, data)
        var[maxCount + 1] = nil
        a.SetStringVar(csvar.pvp_log, injson(var))
    end

    -- 수비자 로깅
    do
        local var = dejson(b.GetStringVar(csvar.pvp_log))
        local data = { type = 2, name = string.infilter(a.player.name), field = fieldName, ts = time }
        table.insert(var, 1, data)
        var[maxCount + 1] = nil
        b.SetStringVar(csvar.pvp_log, injson(var))
    end

    local fdb = a.field and GameData.field[a.field.dataID] or {}
    
    if fdb and fdb.canPVP and (not fdb.forcedPVP) and (fdb.pvpLog ~= false) then
        local nameA, nameB, clanA, clanB = "", "", "", ""
        nameA = string.gsub(a.player.name, "/", "")
        clanA = a.player.clan and string.gsub(a.player.clan.name, "/", "") or ""
        nameB = string.gsub(b.player.name, "/", "")
        clanB = b.player.clan and string.gsub(b.player.clan.name, "/", "") or ""

        local msg = "<color=#2EFEF7>[#] "
        msg = msg .. "<size=10><color=#CEF6F5>" .. clanA .. "</color></size>" .. nameA .. "님이 "
        msg = msg .. "<size=10><color=#CEF6F5>" .. clanB .. "</color></size>" .. nameB .. "님을 "
        msg = msg .. "쓰러뜨렸습니다.</color>"

        Chat(Server, msg)
    end
end




