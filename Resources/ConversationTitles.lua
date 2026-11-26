-- Read public title, last activity, and run state from the local summary table.
-- No database connection, locks, journal changes, or writes. A missing title
-- falls back to the first user message in the transcript.
local cache, refreshed, indexed, previousPath, previousVersion = {}, 0, 0, '', nil
local function uint(s, p, n)
    local v = 0
    for i=p,p+n-1 do v = v*256 + string.byte(s,i) end
    return v
end
local function databaseVersion(path)
    local f=io.open(path,'rb')
    if not f then return '' end
    local header=f:read(100) or '';f:close()
    local wal=io.open(path..'-wal','rb')
    if not wal then return header end
    local prefix=wal:read(32) or ''
    local length=wal:seek('end') or 0
    local tail=''
    if #header>=18 and length>=56 then
        local pageBytes=uint(header,17,2);if pageBytes==1 then pageBytes=65536 end
        local count=math.floor((length-32)/(pageBytes+24))
        if count>0 then wal:seek('set',32+(count-1)*(pageBytes+24));tail=wal:read(24) or '' end
    end
    wal:close()
    local shm=io.open(path..'-shm','rb')
    local walIndex=''
    if shm then walIndex=shm:read(96) or '';shm:close() end
    return header..prefix..tostring(length)..tail..walIndex
end
local function varint(s, p)
    local v = 0
    for _=1,8 do
        local b = s:byte(p); p = p+1
        v = v*128 + b%128
        if b < 128 then return v,p end
    end
    return v*256+s:byte(p),p+1
end
local function fields(data, n)
    local h,p = varint(data,1)
    if h > #data or h < p-1 then return {} end
    local body, out = h+1, {}
    local sizes = {[0]=0,1,2,3,4,6,8,8,0,0}
    for i=1,n do
        if p > h then break end
        local serial; serial,p = varint(data,p)
        local len = sizes[serial] or math.floor((serial-12)/2)
        if len < 0 or body+len-1 > #data then break end
        if serial >= 13 and serial%2 == 1 then out[i] = data:sub(body,body+len-1)
        elseif serial >= 1 and serial <= 6 then out[i] = uint(data,body,len)
        elseif serial == 8 or serial == 9 then out[i] = serial-8 end
        body = body+len
    end
    return out
end
local function loadIndex(path)
    local db = io.open(path,'rb')
    if not db then return {} end
    local wal = io.open(path .. '-wal','rb')
    local function index()
        local header = db:read(100)
        if not header or header:sub(1,16) ~= 'SQLite format 3\0' then return {} end
        local bytes = uint(header,17,2); if bytes == 1 then bytes = 65536 end
        local usable = bytes-header:byte(21)
        if bytes < 512 or usable < 480 or uint(header,57,4) ~= 1 then return {} end
        local overlay = {}
        if wal then
            local head = wal:read(32)
            if head and #head==32 and (uint(head,1,4)==0x377f0682 or uint(head,1,4)==0x377f0683) and uint(head,9,4)==bytes then
                local salt,pending = head:sub(17,24),{}
                local filesize=wal:seek('end')
                for j=0,math.min(8191,math.floor((filesize-32)/(bytes+24))-1) do
                    local at=32+j*(bytes+24); wal:seek('set',at)
                    local frame=wal:read(24)
                    if not frame or frame:sub(9,16)~=salt then break end
                    pending[uint(frame,1,4)]=at+24
                    if uint(frame,5,4)>0 then
                        for page,pos in pairs(pending) do overlay[page]=pos end
                        pending={}
                    end
                end
            end
        end
        local visited={}
        local function walk(page, want, visitor, depth)
            if page<1 or depth>16 or visited[page] then return end
            visited[page]=true
            local source=overlay[page] and wal or db
            source:seek('set',overlay[page] or (page-1)*bytes)
            local data=source:read(bytes)
            if not data or #data~=bytes then return end
            local h=(page==1 and 101 or 1)
            local kind=data:byte(h); if kind~=5 and kind~=13 then return end
            local cells=uint(data,h+3,2)
            for i=0,cells-1 do
                local cell=1+uint(data,h+(kind==5 and 12 or 8)+2*i,2)
                if kind==5 then walk(uint(data,cell,4),want,visitor,depth+1)
                else
                    local size,p=varint(data,cell); local rowid; rowid,p=varint(data,p)
                    local localSize=size
                    if size>usable-35 then
                        local minSize=math.floor((usable-12)*32/255)-23
                        localSize=minSize+(size-minSize)%(usable-4)
                        if localSize>usable-35 then localSize=minSize end
                    end
                    visitor(fields(data:sub(p,p+localSize-1),want))
                end
            end
            if kind==5 then walk(uint(data,h+8,4),want,visitor,depth+1) end
        end
        local root, titles = nil,{}
        walk(1,4,function(r) if r[1]=='table' and r[2]=='conversation_summaries' then root=r[4] end end,0)
        if root then walk(root,16,function(r)
            if type(r[1])=='string' and #r[1]==36 then
                titles[r[1]]={title=r[2],modified=r[5],status=r[7],parent=r[11],busy=r[15]==1,killed=r[16]==1}
            end
        end,0) end
        return titles
    end
    local ok,result = pcall(index)
    db:close(); if wal then wal:close() end
    return ok and result or {}
end
return function(path,now)
    now=now or os.time()
    if path~=previousPath or now-refreshed>=2 or now<refreshed then
        local version=databaseVersion(path)
        if path~=previousPath or version~=previousVersion or now<refreshed or now-indexed>=12 then
            cache=loadIndex(path);previousVersion=version;indexed=now
        end
        refreshed=now;previousPath=path
    end
    return cache
end
