--------------------------------------------------------------------------------
-- Server Party
--------------------------------------------------------------------------------
-- < 기록 로그 > 
--------------------------------------------------------------------------------

gParty = {}

gParty.list = {}
gParty.strList = injson({})

Server.GetTopic("Party_GetData").Add(function(...) gParty:SendData(unit, ...) end)
Server.GetTopic("Party_Create").Add(function(...) gParty:Create(unit, ...) end)
Server.GetTopic("Party_Join").Add(function(...) gParty:TryJoin(unit, ...) end)
Server.GetTopic("Party_Leave").Add(function(...) gParty:Leave(unit, ...) end)
Server.GetTopic("Party_Destroy").Add(function(...) gParty:Destroy(unit, ...) end)
Server.GetTopic("Party_Kick").Add(function(...) gParty:Kick(unit, ...) end)
Server.GetTopic("Party_SetPassword").Add(function(...) gParty:SetPassword(unit, ...) end)



-- 파티 입장 시 파티원 전원을 업데이트합니다.
Server.playerJoinPartyCallback = function(player, party)
    if not (player and party) then return end
    
    local unit = player.unit

    -- 해당 파티원들이 모두 가입 가능 장소에 있는지 확인
    for i, p in pairs(party.players) do
        local fieldID = p.unit.field.dataID
        local fdb = GameData.field[fieldID]
        if fdb and fdb.canParty == false then
            ShowErrMsg(unit, "대상 파티가 가입할 수 없는 장소에 있습니다.")
            return false
        end
    end

    -- 내가 가입 가능한 장소인지 확인
    local fieldID = unit.field.dataID
    local fdb = GameData.field[fieldID]
    if fdb and fdb.canParty == false then
        ShowErrMsg(unit, "현재 위치에서는 파티에 가입할 수 없습니다.")
        return false
    end

    -- 가입 처리
    Server.RunLater(function()
        if party then
            gParty:Update(party.id)
            for i, p in pairs(party.players) do
                if p and p.unit then gParty:SendData(p.unit) end
            end
        end
    end, 0.1)

    PlaySE(unit, cse.signal)

    return true
end


-- 파티 탈퇴 시 파티원 전원을 업데이트합니다.
Server.playerLeavePartyCallback = function(player, party)
    if not (player and party) then return end
    
    local unit = player.unit
    local fieldID = unit.field.dataID
    local fdb = GameData.field[fieldID]
    if fdb and fdb.partyLeaveEvent then
        fdb.partyLeaveEvent(player, party)
    end

    Server.RunLater(function()
        if party then
            gParty:Update(party.id)
            if player and player.unit then gParty:SendData(player.unit) end
            for i, p in pairs(party.players) do
                if p and p.unit then gParty:SendData(p.unit) end
            end
        end
    end, 0.1)
end


--* 파티를 업데이트합니다.
function gParty:Update(targetID)
    for strID, data in pairs(self.list) do
        if (not targetID) or strID == tostring(targetID) then
            if not data.party then 
                self.list[strID] = nil
            else 
                data.player = {}
                local playerCount = 0
                for i, p in pairs(data.party.players) do
                    playerCount = playerCount + 1
                    data.player[i] = string.infilter(p.name)
                end
                if playerCount <= 0 then
                    data.party.Destroy()
                    data.party.SendUpdated()
                    self.list[strID] = nil
                end
            end            
        end
    end
    self.strList = injson(self.list)
end
ontick.Add(function() gParty:Update() end, 10, 8)


--* 내 파티의 데이터를 정리하여 반환합니다.
function GetMyPartyData(unit)
    if not unit.party then return end
    local party = unit.party
    local data = gParty.list[ tostring(party.id) ]
    local t = {
        title = string.infilter(party.name),
        reqLevel = party.customData.reqLevel,
        password = string.infilter(party.customData.password or ""),
        masterID = party.masterPlayerID,
        maxPlayerCount = party.maxPlayer,
        player = {},
    }
    for i, p in pairs(party.players) do
        local u = p.unit
        t.player[i] = {
            id = p.id, 
            name = string.infilter(p.name),
            level = u.level, 
            cp = u.GetVar(cvar.cp),
            avatar = u.characterID,
        }
    end
    return t
end


--* 클라이언트로 파티 데이터를 전송합니다.
function gParty:SendData(unit)
    local partyID = unit.party and unit.party.id or -1
    local strPartys = self.strList
    local myParty = GetMyPartyData(unit)
    local strMyParty = myParty and injson(myParty) or nil
    unit.FireEvent("Party_SendData", partyID, strPartys, strMyParty)
end


--* 파티를 파괴합니다.
function gParty:SetPassword(unit, password)
    if not (unit and CheckUserSystemDelay(unit)) then return end
    local party = unit.party
    if not party then
        ShowErrMsg(unit, "가입된 파티가 없습니다.")
        return
    end
    if party.masterPlayerID ~= unit.player.id then
        ShowErrMsg(unit, "파티장만 가능합니다.")
        return
    end

    party.customData.password = password ~= "" and password or nil
    self.list[tostring(party.id)].lock = true

    for _, p in pairs(party.players) do
        local u = p.unit
        ShowMsg(u, "파티 비밀번호 설정이 변경되었습니다.")
        gParty:SendData(u)
    end
    SetUserSystemDelay(unit)
end



--* 새로운 파티를 창설합니다.
function gParty:Create(unit, title, maxPlayerCount, password, reqLevel)
    if not (unit and title and maxPlayerCount and CheckUserSystemDelay(unit)) then return end

    if unit.party then
        ShowErrMsg(unit, "이미 참여중인 파티가 있습니다.")
        return
    end
    if reqLevel and (not (0 <= reqLevel and reqLevel <= unit.level)) then
        ShowWrongRequestMsg(unit)
        return
    end

    local party = Server.CreateParty(string.sub(title, 1, 20), math.setrange(maxPlayerCount, 1, 4))
    if password then party.customData.password = string.sub(password, 1, 12) end
    if reqLevel then party.customData.reqLevel = reqLevel end
    party.JoinParty(unit.player)
    self.list[tostring(party.id)] = {
        id = party.id,
        title = string.infilter(title),
        masterName = string.infilter(unit.player.name),
        maxPlayerCount = math.setrange(maxPlayerCount, 1, 4),
        players = {},
        lock = (password and true or false),
        reqLevel = reqLevel or 0,
        party = party
    }
    gParty:Update(party.id)
    gParty:SendData(unit)
    SetUserSystemDelay(unit)
end


--* 파티에 가입을 시도합니다.
function gParty:TryJoin(unit, partyID, inputPassword)
    if not (unit and partyID and CheckUserSystemDelay(unit)) then return end
    local data = self.list[ tostring(partyID) ]
    if not data then
        ShowErrMsg(unit, "사라진 파티입니다.")
        gParty:SendData(unit)
        return
    end

    local party = data.party
    local password = party.customData.password
    local reqLevel = party.customData.reqLevel or 0

    if unit.party then
        ShowErrMsg(unit, "이미 참여중인 파티가 있습니다.")
        gParty:SendData(unit)
        return
    end
    if unit.level < reqLevel then
        ShowErrMsg(unit, "이 파티는 레벨 " .. reqLevel .. " 이상 참여가 가능합니다.")
        return
    end
    if data.lock and (not inputPassword) then
        ShowErrMsg(unit, "파티에 비밀번호가 설정되었습니다.\n파티를 새로고침해주세요.")
        return
    elseif data.lock and (password ~= inputPassword) then
        ShowErrMsg(unit, "잘못된 비밀번호입니다.")
        return
    end
    if #party.players >= party.maxPlayer then
        ShowErrMsg(unit, "파티가 가득찼습니다.")
        return
    end
    party.JoinParty(unit.player)
    SetUserSystemDelay(unit)
end


--* 파티에서 떠납니다.
function gParty:Leave(unit)
    if not (unit and CheckUserSystemDelay(unit)) then return end
    if not unit.party then
        ShowErrMsg(unit, "가입된 파티가 없습니다.")
        return
    end
    unit.party.LeaveParty(unit.player)
    SetUserSystemDelay(unit)
end


--* 파티를 파괴합니다.
function gParty:Destroy(unit)
    if not (unit and CheckUserSystemDelay(unit)) then return end
    local party = unit.party
    if not party then
        ShowErrMsg(unit, "가입된 파티가 없습니다.")
        return
    end
    if party.masterPlayerID ~= unit.player.id then
        ShowErrMsg(unit, "파티장만 가능합니다.")
        return
    end
    for _, p in pairs(party.players) do
        local u = p.unit
        party.LeaveParty(p)
        ShowMsg(u, "파티가 해체되었습니다...")
        Chat(u, "[#] 파티가 해체되었습니다.", cc.green)
    end
    SetUserSystemDelay(unit)
end


--* 특정 유저를 파티에서 추방합니다.
function gParty:Kick(unit, targetID)
    if not (unit and targetID and CheckUserSystemDelay(unit)) then return end

    local party = unit.party
    if not party then
        ShowErrMsg(unit, "가입된 파티가 없습니다.")
        return
    end
    if party.masterPlayerID ~= unit.player.id then
        ShowErrMsg(unit, "파티장만 가능합니다.")
        return
    end
    local targetPlayer = nil
    for _, p in pairs(party.players) do
        if p.id == targetID then
            targetPlayer = p
            break 
        end
    end
    if not targetPlayer then
        ShowErrMsg(unit, "선택한 파티원은 이미 파티에서 사라졌습니다.")
        return
    end
    if targetPlayer == unit.player then
        ShowErrMsg(unit, "자기 자신을 추방할 수 없습니다.")
        return
    end

    unit.party.KickParty(targetPlayer)
    SetUserSystemDelay(unit)
end













