--------------------------------------------------------------------------------
-- Server Ranking
--------------------------------------------------------------------------------

gRanking = {}
gRanking.joinList = {}
gRanking.allList = { level = {}, cp = {} }
gRanking.strJoinList = injson(joinList)
gRanking.strAllList = injson(allList)

Server.GetTopic("Ranking_GetData").Add(function() gRanking:SendData(unit) end)


--* 클라이언트로 랭킹 데이터를 전송합니다.
function gRanking:SendData(unit)
    unit.FireEvent("Ranking_SendData", self.strJoinList, self.strAllList)
end


--* 5초마다 서버의 랭킹 정보를 갱신합니다.
function gRanking:Update()
    local allList = { level = {}, cp = {} }
    local joinList = {  }
    local isJoinPlayer = {}

    local allLevelRanks = Server.GetRankings(1, false, true)
    local allCPRanks = Server.GetRankings(2, false, true)

    for i, player in pairs(Server.players) do
        local unit = player.unit
        joinList[i] = { id = player.id, name = string.infilter(player.name), cp = unit.GetVar(cvar.cp), level = unit.level, clan = (player.clan and string.infilter(player.clan.name) or "") }
        isJoinPlayer[tostring(player.id)] = true
    end

    for i, data in pairs(allLevelRanks) do
        allList.level[i] = { id = data.id, name = string.infilter(data.name), value = data.score, join = (isJoinPlayer[tostring(data.id)] and true or false) }
    end
    for i, data in pairs(allCPRanks) do
        allList.cp[i] = { id = data.id, name = string.infilter(data.name), value = data.score, join = (isJoinPlayer[tostring(data.id)] and true or false) }
    end

    self.joinList = joinList
    self.allList = allList
    self.strJoinList = injson(joinList)
    self.strAllList = injson(allList)
end
ontick.Add(function() gRanking:Update() end, 5, 3)

