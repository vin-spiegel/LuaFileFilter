--------------------------------------------------------------------------------
-- Server Storage
--------------------------------------------------------------------------------

gStorage = {}


Server.GetTopic("Storage_Open").Add(function(n) gStorage:Oepn(unit, n) end)

function gStorage:Oepn(unit, n)
    local n = math.setrange(n, 1, 3)
    unit.StartGlobalEvent(30 + n)
    SendLog(unit, "Storage_Open", tostring(n))
end
