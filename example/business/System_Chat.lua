--------------------------------------------------------------------------------
-- Server Chat (SayCallback과 연계)
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Chat_AddBlock
-- Chat_RemoveBlock
-- Chat_ResetBlock
--------------------------------------------------------------------------------

gChat = {}

Server.GetTopic("Chat_AddBlock").Add(function(id, name) gChat:AddBlock(unit, id, name) end)
Server.GetTopic("Chat_RemoveBlock").Add(function(id, name) gChat:RemoveBlock(unit, id, name) end)
Server.GetTopic("Chat_ResetBlock").Add(function() gChat:ResetBlock(unit) end)


--* 근처·전체채팅 차단 목록을 추가합니다.
function gChat:AddBlock(unit, id, name)
    if not (id and name and CheckUserSystemDelay(unit)) then
        return
    end

    local strID = tostring(id)
    local fname = string.infilter(name)

    local strList = unit.GetStringVar(csvar.chat_blockList)
    local list = dejson(strList)

    if list[strID] then
        ShowErrMsg(unit, "이 플레이어는 이미 차단 목록에 있습니다.")
        return
    elseif table.len(list) >= GameData.chat.maxBlockCount then
        ShowErrMsg(unit, "더 이상 차단할 수 없습니다.")
        return
    end

    list[strID] = fname
    local afterStrList = injson(list)
    unit.SetStringVar(csvar.chat_blockList, afterStrList)
    
    ShowMsg(unit, "이제 " .. name .. "님의 전체/근처채팅을 무시합니다.") 
    PlaySE(unit, cse.signal)
    unit.FireEvent("Chat_UpdateBlockList", afterStrList)
    
    SendLog(unit, "Chat_AddBlock", id .. " " .. name, afterStrList)
    SetUserSystemDelay(unit)
end


--* 근처·전체채팅 차단 목록 중 하나를 삭제합니다.
function gChat:RemoveBlock(unit, id, name)
    if not (id and name and CheckUserSystemDelay(unit)) then
        return
    end

    local strID = tostring(id)
    local fname = string.infilter(name)

    local strList = unit.GetStringVar(csvar.chat_blockList)
    local list = dejson(strList)

    if not list[strID] then
        ShowErrMsg(unit, "이 플레이어는 이미 차단 목록에 없습니다.")
        return
    end

    list[strID] = nil
    local afterStrList = injson(list)
    unit.SetStringVar(csvar.chat_blockList, afterStrList)
    
    ShowMsg(unit, "이제 " .. name .. "님의 전체/근처채팅을 다시 확인합니다.") 
    PlaySE(unit, cse.signal)
    unit.FireEvent("Chat_UpdateBlockList", afterStrList)
    
    SendLog(unit, "Chat_RemoveBlock", id .. " " .. name, afterStrList)
    SetUserSystemDelay(unit)
end


--* 근처·전체채팅 차단 목록을 리셋합니다.
function gChat:ResetBlock(unit)
    if not CheckUserSystemDelay(unit) then
        return
    end

    local list = dejson(unit.GetStringVar(csvar.chat_blockList))
    if table.len(list) <= 0 then
        ShowErrMsg(unit, "차단된 플레이어가 없습니다.")
        return
    end
    
    local afterStrList = injson({})
    unit.SetStringVar(csvar.chat_blockList, afterStrList)

    ShowMsg(unit, "차단 목록이 모두 삭제되었습니다.") 
    PlaySE(unit, cse.signal)
    unit.FireEvent("Chat_UpdateBlockList", afterStrList)
    
    SendLog(unit, "Chat_ResetBlock", "")
    SetUserSystemDelay(unit)
end
















