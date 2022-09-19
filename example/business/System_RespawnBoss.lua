--------------------------------------------------------------------------------
-- Server Respawn Boss
--------------------------------------------------------------------------------
-- 정확한 시간에 필드 보스 리젠을 위한 루프 스크립트입니다.
--------------------------------------------------------------------------------
-- < 기록 로그 > 
-- Boss_Respawn
-- Boss_Dead
--------------------------------------------------------------------------------


gRespawn = {}
gRespawn.list = {}
gRespawn.group = {
    ["dragonking"] = { name = "용왕의 영역", time = 3600*6, monster = {} },
    ["jin_dragonking"] = { name = "진'용왕의 영역", time = 3600*6, monster = {} },
    ["guk_dragonking"] = { name = "극'용왕의 영역", time = 3600*6, monster = {} },
    ["pvp_dragonking"] = { name = "PVP 용왕의 영역", time = 3600*6, monster = {} },
    ["pvp_jin_dragonking"] = { name = "PVP 진'용왕의 영역", time = 3600*6, monster = {} },
    ["pvp_guk_dragonking"] = { name = "PVP 극'용왕의 영역", time = 3600*6, monster = {} },
    ["aglyhouse"] = { name = "흉흉한 흉가", time = 3600*5, monster = {} },
    ["more_aglyhouse"] = { name = "더 흉흉한 흉가", time = 3600*5, monster = {} },
    ["pvp_aglyhouse"] = { name = "PVP 흉흉한 흉가", time = 3600*5, monster = {} },
    ["pvp_more_aglyhouse"] = { name = "PVP 더 흉흉한 흉가", time = 3600*5, monster = {} },
}

for monID, data in pairs(GameData.monster) do
    local rdb = data.respawn
    if rdb and rdb.group then
        local db = gRespawn.group[rdb.group]
        table.insert(db.monster, monID)
    end
end

-- [[ 커스텀 리젠 설정 ]] --

-- 용왕 / 용왕★
do
    local nowDt = os.date("*t", GetTimeStamp() + 3600*9)
    local ts = os.time( {year=nowDt.year, month=nowDt.month, day=nowDt.day, hour=20, min=30} ) - 3600*9
    gRespawn.list["561_0"] = { monID = 561, ts = ts - 3600*48, fieldName = string.infilter("용왕의방"), isRespawn = false, first = true, category = "용왕의영역" }
    gRespawn.list["562_0"] = { monID = 562, ts = ts - 3600*48, fieldName = string.infilter("위험한 용왕의방"), isRespawn = false, first = true, category = "용왕의영역" }
end

gRespawn.strList = injson(gRespawn.list)

----------------------------


Server.GetTopic("Respawn_GetData").Add(function() gRespawn:SendData(unit) end)


--* 리스폰 데이터를 전송합니다.
function gRespawn:SendData(unit)
    unit.FireEvent("Respawn_SendData", self.strList)
end



--* (onUnitDead처리) 재생성&로깅 대상인지 판별 후 추가합니다.
function gRespawn:Logging(a, b)
    if b.type ~= 2 then return end
    local monsterID = b.monsterID
    local mdb = GameData.monster[monsterID]
    if not (mdb and mdb.respawn) then return end
    if mdb.respawn.isVisibleLog == false then return end
    local field = a.field or b.field or {}
    local group = mdb.respawn.group or false
    gRespawn:Add(monsterID, field.name or "", field.channelID or 0, mdb.respawn.category or nil, group)
    if group and gRespawn:CheckGroupDead(group) then
        gRespawn:SetGroupData(group)
    end
    local monsterName = Server.GetMonster(monsterID).name
    SendServerLog("Boss_Dead", "[" .. monsterID .."] " .. monsterName)
end



--* 재생성 리스트에 새롭게 추가합니다.
function gRespawn:Add(monID, fieldName, channel, category, isGroup)
    local ts = math.rounddown(GetTimeStamp())
    local code = tostring(monID .. "_" .. (channel or 0))
    if self.list[code] then
        self.list[code].ts = isGroup and -1 or ts
        self.list[code].isRespawn = false
        self.list[code].first = nil
        self.list[code].category = category or nil
        self.list[code].rndTime = rand(0, 15+1)
    else
        self.list[code] = {
            monID = monID,
            ts = isGroup and -1 or ts,
            fieldName = string.infilter(fieldName),
            isRespawn = false,
            category = category or nil,
            rndTime = rand(0, 15+1)
        }
    end
    self.strList = injson(self.list)
    Server.FireEvent("Respawn_SendData", self.strList)
end


--* 같은 그룹의 몬스터가 모두 잡혔는지 확인합니다.
function gRespawn:CheckGroupDead(groupCode)
    local db = self.group[groupCode]
    for i, monID in pairs(db.monster) do
        local code = tostring(monID .. "_0")
        local rdb = self.list[code]
        if not (rdb and rdb.isRespawn == false and rdb.ts == -1) then
            return false
        end
    end
    return true
end


--* 같은 그룹의 모든 몬스터의 리스폰시간을 결정합니다.
function gRespawn:SetGroupData(groupCode)
    local db = self.group[groupCode]
    local ts = math.rounddown(GetTimeStamp())
    local rndTime = rand(0, 15+1)
    for i, monID in pairs(db.monster) do
        local code = tostring(monID .. "_0")
        local rdb = self.list[code]
        if rdb then
            rdb.ts = ts
            rdb.isRespawn = false
            rdb.first = nil
            rdb.rndTime = rndTime
        end
    end
    self.strList = injson(self.list)
    Server.FireEvent("Respawn_SendData", self.strList)
end


--* 재생성 시간이 되었는지 판단 후 소환합니다.
function gRespawn:Loop()
    local ts = math.rounddown(GetTimeStamp())
    for code, data in pairs(self.list) do
        local monsterID = data.monID
        local mdb = GameData.monster[ monsterID ]
        local rdb = mdb.respawn
        if (not data.isRespawn) and data.ts ~= -1 and (rdb.time + data.ts + (data.rndTime or 0)) <= ts then
            local mapID = rdb.map[1]
            local field = Server.GetField(mapID)
            if field and #field.playerUnits >= 1 then
                local x = type(rdb.map[2]) == "table" and rand(rdb.map[2][1], rdb.map[2][2] + 1) or rdb.map[2]
                local y = type(rdb.map[3]) == "table" and rand(rdb.map[3][1], rdb.map[3][2] + 1) or rdb.map[3]
                local monsterName = Server.GetMonster(monsterID).name
                local strData = injson(data)
                field.SpawnEnemy(monsterID, x*32, y*-32)
                data.isRespawn = true
                self.strList = injson(self.list)
                SendServerLog("Boss_Respawn", "[" .. monsterID .."] " .. monsterName, strData)
            end
        end
    end

end
ontick.Add(function() gRespawn:Loop() end, 1)











