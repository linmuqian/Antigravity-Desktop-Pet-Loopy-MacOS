-- The UI has a transient activity stack and a separate, explicitly opened history.
return function(resources)
    local readCard=dofile(resources..'/Conversation.lua')(resources)
    local readIndex=dofile(resources..'/ConversationTitles.lua')
    local known,checked={},{}
    return function(base,sources,now)
        now=now or os.time()
        local catalog=readIndex(base..'/conversation_summaries.db',now)
        local scan={}
        for _,s in ipairs(sources) do scan[s.id]=s end
        for id,meta in pairs(catalog) do
            local version=table.concat({meta.modified or '',meta.status or '',tostring(meta.busy),tostring(meta.killed),meta.title or ''},'/')
            if checked[id]~=version then
                scan[id]=scan[id] or {}
                checked[id]=version
            end
        end
        for id,c in pairs(known) do
            if c.visible then scan[id]=scan[id] or {} end
        end
        for id,s in pairs(scan) do
            if type(id)=='string' and #id==36 and id:match('^[%da-fA-F%-]+$') then
                local path=base..'/brain/'..id..'/.system_generated/logs/transcript.jsonl'
                local c=readCard(path,s.size,s.mtime,catalog[id],now)
                known[id]=c
            end
        end
        local live,recent={},{}
        for _,c in pairs(known) do
            if c.visible then live[#live+1]=c end
            if c.sub~='' then recent[#recent+1]=c end
        end
        local function newest(a,b)
            if a.stamp~=b.stamp then return a.stamp>b.stamp end
            return a.id<b.id
        end
        table.sort(recent,newest)
        table.sort(live,function(a,b)
            local aActive=a.row==7 or a.row==6
            local bActive=b.row==7 or b.row==6
            if aActive~=bActive then return aActive end
            return newest(a,b)
        end)
        local priority={[0]=0,[7]=1,[8]=2,[5]=3,[6]=4}
        local state=0
        for _,c in ipairs(live) do
            if priority[c.row]>priority[state] then state=c.row end
        end
        return {live=live,recent=recent,state=state}
    end
end
