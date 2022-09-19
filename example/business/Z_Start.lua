print("서버 시작")


do -- 박스형 아이템 정상 확률 체크
    for dataID, data in pairs(GameData.item) do
        local box = data.box
        if box and (box.type == 3 or box.type == 5) then
            local r = 0
            for _, d in pairs(box.list) do r = r + d[1] end
            r = math.round(r, 5)
            if r ~= 100 then
                print("확률합계 오류감지 : [" .. dataID .. "] " .. GetItemName(dataID) .. " : " .. r)
            end
        end
    end 
end

