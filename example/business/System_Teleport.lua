-----------------------------------------------------------------------------------------------
-- Server Teleport
-----------------------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Teleport, Move
-----------------------------------------------------------------------------------------------

gTeleport = {}
gTeleport.delay = 1.5
gTeleport.db = GameData.teleport


Server.GetTopic("Teleport_GetData").Add(function() gTeleport:SendData(unit, true) end)
Server.GetTopic("Teleport_AddBookmark").Add(function(targetCode) gTeleport:AddBookmark(unit, targetCode) end)
Server.GetTopic("Teleport_RemoveBookmark").Add(function(targetCode) gTeleport:RemoveBookmark(unit, targetCode) end)
Server.GetTopic("Teleport_ResetBookmark").Add(function() gTeleport:ResetBookmark(unit) end)
Server.GetTopic("Teleport_Go").Add(function(code, channel) gTeleport:Go(unit, code, channel) end)
Server.GetTopic("ChangeChannel").Add(function(mapID, channel) ChangeChannel(unit, mapID, channel) end)

--* 맵 이동 딜레이를 가져옵니다.
function GetTeleportDelay(unit) return unit.GetVar(cvar.teleport_delay) end
--* 맵 이동 딜레이를 추가합니다.
function SetTeleportDelay(unit) unit.SetVar(cvar.teleport_delay, GetTimeStamp() * 100) end
--* 맵 이동 가능 여부를 반환합니다.
function CheckTeleportDelay(unit, notify, count)
    local notify = notify ~= false and true or false
    local lastTime = GetTeleportDelay(unit)/100 + (count or gTeleport.delay)
    local nowTime = GetTimeStamp()
    local pass = lastTime < nowTime and true or false
    if (not pass) and notify then ShowErrMsg(unit, "너무 빠르게 이동하기 힘듭니다.") end
    return pass
end


--* 이동합니다.
function gTeleport:Go(unit, code, channel)
    if not (unit and code and CheckTeleportDelay(unit)) then return end
    -------------------------------------------------------
    local data = self.db.list[code]
    if not data then return end

    local nowMapdb = GameData.field[unit.field.dataID] or {}
    local mapID = data.map[1]
    local x = type(data.map[2]) == "table" and rand(data.map[2][1], data.map[2][2] + 1) or data.map[2]
    local y = type(data.map[3]) == "table" and rand(data.map[3][1], data.map[3][2] + 1) or data.map[3]

    local mapData = GameData.field[mapID] or {}
    local channel = mapData.channel and ( math.max(1, math.min(channel, mapData.channel)) ) or 0

    if nowMapdb.canTeleport == false then
        ShowErrMsg(unit, "이곳에선 이동할 수 없습니다.")
        return
    end

    if nowMapdb.code == "tutorial_end" and data.name ~= "마을" then
        ShowMsg("튜토리얼 진행 중에는\n<color=" .. cc.yellowLight .. ">[안전지대-마을]</color>만 이동이 가능합니다.")
        return
    end

    if data.reqLevel and data.reqLevel > unit.level then
        ShowErrMsg(unit, "레벨 " .. data.reqLevel .." 이상 입장 가능한 지역입니다.")
        return
    end

    if data.time and unit.GetVar(data.time.var) <= 0 then
        ShowErrMsg(unit, "이용 가능한 시간이 없습니다.")
        return
    end

    if data.var then unit.SetVar(data.var[1], data.var[2]) end

    unit.FireEvent("Teleport_Destroy")
    PlaySE(unit, cse.teleport)
    unit.ShowAnimation(1)
    Server.RunLater(function()
        if not unit then return end
        gOrcRace:ResetByID(unit.player.id) -- 오크레이스 정보 초기화
        unit.SpawnAtFieldID(4, 28*32+10, 26*-32-10, channel)
        unit.SpawnAtFieldID(mapID, x*32+10, y*-32-10, channel)
        unit.customData.lastTeleport = code
        if mapData.canPVP then
            ShowMsg(unit, "<color=" .. cc.redLight .. ">PVP 가능 지역에 입장하셨습니다.</color><size=13>\n우측 하단 <color=" .. cc.yellowLight .. ">PVP버튼을 활성화</color>하여 타인을 공격할 수 있습니다.</size>")
        end
        Server.RunLater(function()
            if unit and unit.party and mapData.channel then ShowMsg(unit, "파티 상태에서는\n파티원이 속한 채널로 이동됩니다.") end
        end, 1)        
    end, 1.5)
    -------------------------------------------------------
    SendLog(unit, "Teleport", "[" .. code .. "] " .. data.name, "")

    gOrcRace:ResetByID(unit.player.id) -- 오크레이스 정보 초기화
    unit.customData.event_bomb = nil -- 참가정보 리셋
    unit.customData.event_firstAttack = nil --  참가정보 리셋
    unit.customData.event_luckyRace = nil --  참가정보 리셋

    SetTeleportDelay(unit)
end


-- 클라이언트로 즐겨찾기 목록을 전송합니다.
function gTeleport:SendData(unit, isFirst)
    unit.FireEvent("Teleport_SendData", unit.GetStringVar(csvar.teleport_bookmark), isFirst)
end


-- 새롭게 즐겨찾기를 등록합니다.
function gTeleport:AddBookmark(unit, targetCode)
    if not (unit and targetCode and CheckUserSystemDelay(unit)) then return end
    local db = self.db.list[targetCode]
    if not db then return end
    
    local var = dejson(unit.GetStringVar(csvar.teleport_bookmark))
    if #var >= 20 then
        ShowErrMsg(unit, "즐겨찾기는 최대 20개까지만 등록이 가능합니다.")
        return
    end

    for i, code in pairs(var) do
        if code == targetCode then
            ShowErrMsg(unit, "이미 즐겨찾기에 추가된 항목입니다.")
            return
        end
    end

    table.insert(var, targetCode)
    unit.SetStringVar(csvar.teleport_bookmark, injson(var))
    ShowMsg(unit, "<" .. db.name .. "> 즐겨찾기 등록")
    gTeleport:SendData(unit)

    SetUserSystemDelay(unit)
end


-- 즐겨찾기를 등록해제합니다.
function gTeleport:RemoveBookmark(unit, targetCode)
    if not (unit and targetCode and CheckUserSystemDelay(unit)) then return end
    local db = self.db.list[targetCode]
    if not db then return end
    
    local var = dejson(unit.GetStringVar(csvar.teleport_bookmark))

    local pos = -1
    for i, code in pairs(var) do
        if code == targetCode then
            pos = i
        end
    end

    if pos == -1 then
        ShowWrongRequestMsg(unit)
        return
    end

    table.remove(var, pos)
    unit.SetStringVar(csvar.teleport_bookmark, injson(var))
    ShowMsg(unit, "<" .. db.name .. "> 즐겨찾기 등록해제")
    gTeleport:SendData(unit)

    SetUserSystemDelay(unit)
end


-- 즐겨찾기를 초기화합니다.
function gTeleport:ResetBookmark(unit)
    if not (unit and CheckUserSystemDelay(unit)) then return end
    unit.SetStringVar(csvar.teleport_bookmark, injson({}))
    ShowMsg(unit, "모든 즐겨찾기가 초기화되었습니다.")
    gTeleport:SendData(unit)
    SetUserSystemDelay(unit)
end


-- 포탈 Join시 발생하는 이벤트입니다.
-- 이벤트-스크립트(서버)-JoinPortal(unit, keword)
function JoinPortal(unit, keword)
    if not (unit and keword and CheckTeleportDelay(unit)) then return end

    local field = unit.field
    local fieldID = field and field.dataID or nil
    local data = fieldID and GameData.field[fieldID] or nil
    if not data then return end

    local kdata = data.portal and data.portal[keword] or nil
    if not kdata then return end

    local map = kdata.map
    local mapID = map[1]
    local x = type(map[2]) == "table" and rand(map[2][1], map[2][2] + 1) or map[2]
    local y = type(map[3]) == "table" and rand(map[3][1], map[3][2] + 1) or map[3]
    local nowChannel = field.channelID
    local targetChannel = data.channel and math.max(1, math.min(data.channel, nowChannel)) or 0

    if unit.party and data.channel then ShowMsg(unit, "파티 상태에서는\n파티원이 속한 채널로 이동됩니다.") end
    unit.SpawnAtFieldID(mapID, x*32+16, y*-32-16, targetChannel)
    SendLog(unit, "Move", field.name .. " CH" .. targetChannel)

    gOrcRace:ResetByID(unit.player.id) -- 오크레이스 정보 초기화
    unit.customData.event_bomb = nil -- 폭탄피하기 참가정보 리셋
    unit.customData.event_firstAttack = nil --  참가정보 리셋
    unit.customData.event_luckyRace = nil --  참가정보 리셋

    SetTeleportDelay(unit)
end


-- 채널을 변경합니다.
function ChangeChannel(unit, mapID, targetNum)
    if not (unit and mapID and targetNum and CheckTeleportDelay(unit, nil, 3)) then return end

    local field = unit.field
    local fieldID = field and field.dataID or nil
    local nowChannel = field and field.channelID or nil
    local data = fieldID and GameData.field[fieldID] or nil
    if not data then return end
    if data.channel == nil or data.canChannelChange == false then ShowErrMsg(unit, "채널을 변경할 수 없는 장소입니다.") return end
    if not (mapID == fieldID) then ShowErrMsg(unit, "현재 위치가 변경되었습니다.") return end
    local targetChannel = data.channel and math.max(1, math.min(targetNum, data.channel)) or 0
    if nowChannel == targetChannel then ShowErrMsg(unit, "현재 채널과 동일합니다.") return end

    PlaySE(unit, cse.teleport)
    unit.ShowAnimation(1)
    Server.RunLater(function()
        if not unit then return end
        if unit.party then ShowMsg(unit, "파티 상태에서는\n파티원이 속한 채널로 이동됩니다.") end
        local x, y = unit.x, unit.y
        unit.SpawnAtFieldID(4, 28*32+10, 26*-32-10, targetChannel)
        unit.SpawnAtFieldID(fieldID, x, y, targetChannel)
    end, 1.5)
    -------------------------------------------------------
    SendLog(unit, "Move", field.name .. " CH" .. targetChannel)
    SetTeleportDelay(unit)
end

-----------------------------------------------------------------------------------------------

-- 용왕의방 입장
function TeleportDragonKingField(unit)
    if not (unit and CheckTeleportDelay(unit)) then return end

    -- 재료 확인
    local needs = { 
        { dataID = 727 },
    }
    local sumNeedLog, sumHaveLog = {}, {}
    for i, need in pairs(needs) do
        local needCount = need.count or 1
        local haveCount, haveLog = CountItem(unit, need.dataID, true)
        if haveCount < needCount then
            ShowLackMsg(unit, "입장")
            return
        end
        sumNeedLog[tostring(i)] = { dataID = need.dataID, needCount = needCount, haveCount = haveCount }
        sumHaveLog[tostring(i)] = haveLog
    end

    -- 재료 소모
    local sumUseLog = {}
    for strI, need in pairs(sumNeedLog) do
        sumUseLog[strI] = RemoveItem(unit, need.dataID, need.needCount, true)
    end

    ShowMsg(unit, "용왕의 방에 입장합니다..")
    unit.SpawnAtFieldID(4, 28*32+10, 26*-32-10, channel)
    unit.SpawnAtFieldID(182, 34*32+10, 38*-32-10, channel)

    local logData = {
        sumNeedLog = sumNeedLog,
        sumHaveLog = sumHaveLog,
        sumUseLog = sumUseLog,
    }
    SendLog(unit, "Teleport_Dragon", "용왕의방", injson(logData))

    SetTeleportDelay(unit)
    return true
end




