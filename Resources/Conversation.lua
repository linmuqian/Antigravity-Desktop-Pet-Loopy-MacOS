return function(resourceDir)
    local json = dofile(resourceDir .. '/json.lua')
    local cache = {}
    local lastSeen = {}
    -- Convert ISO timestamps to UTC independently of the computer's timezone and DST.
    local function epoch(s)
        if type(s)~='string' then return nil end
        local y,m,d,h,mi,ss=s:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)[ T](%d%d):(%d%d):(%d%d)')
        if not y then return nil end
        y,m,d=tonumber(y),tonumber(m),tonumber(d)
        if m<=2 then y=y-1;m=m+9 else m=m-3 end
        local era=math.floor(y/400);local yr=y-era*400
        local days=era*146097+yr*365+math.floor(yr/4)-math.floor(yr/100)+math.floor((153*m+2)/5)+d-1-719468
        local sign,oh,om=s:match('([%+%-])(%d%d):?(%d%d)$')
        local zone=sign and (tonumber(oh)*3600+tonumber(om)*60)*(sign=='-' and -1 or 1) or 0
        return days*86400+h*3600+mi*60+ss-zone
    end
    local function clip(s,n)
        if type(s)~='string' then return '' end
        s=s:gsub('[%c%s]+',' '):gsub('^%s+',''):gsub('%s+$','')
        local seen=0
        for p in s:gmatch('()[%z\1-\127\194-\244]') do
            seen=seen+1; if seen>n then return s:sub(1,p-1)..'…' end
        end
        return s
    end
    local function question(s)
        if type(s)~='string' then return '' end
        local marked=s:match('<USER_REQUEST>(.-)</USER_REQUEST>') or s:match('<USER_REQUEST>(.*)')
        if not marked and s:match('^%s*<') then return '' end
        return clip((marked or s):gsub('<ADDITIONAL_METADATA>.*',''),240)
    end
    local function records(data)
        local out={}
        for line in data:gmatch('[^\r\n]+') do
            if not line:find('"CHECKPOINT"',1,true) and not line:match('^%s*$') then
                local ok,obj=pcall(json.decode,line)
                if ok and type(obj)=='table' and obj.type~='SYSTEM_MESSAGE' and obj.type~='CHECKPOINT' then out[#out+1]=obj end
            end
        end
        return out
    end
    local active={
        run_command='正在运行命令',read_file='正在读取文件',list_dir='正在查看目录',
        edit_file='正在编辑文件',write_file='正在写入文件',search_web='正在搜索网页',
        webview_browser='正在查看网页',invoke_subagent='正在处理子任务',ask_question='等你回复',
        grep_search='正在搜索文件',find_by_name='正在查找文件',update_steps='正在整理步骤',
        manage_task='正在更新任务',manage_subagents='正在处理子任务',send_message='正在发送消息',
        update_focus='正在更新进度',schedule='正在安排任务'
    }
    local function inspect(path,size,mtime)
        local f=io.open(path,'rb'); if not f then return nil end
        local head=f:read(98304) or ''
        local offset=math.max(0,size-262144)
        f:seek('set',offset); local tail=f:read(262144) or ''; f:close()
        if offset>0 then tail=tail:match('^[^\n]*\n(.*)$') or '' end
        local first=''
        for _,obj in ipairs(records(head)) do
            if obj.type=='USER_INPUT' then first=question(obj.content); if first~='' then break end end
        end
        local q,reply,action,row='', '', '',0
        local eventTime,eventKey
        local edited,pending={},{}
        local function confirm()
            for name in pairs(pending) do edited[name]=true end
            pending={}
        end
        for _,obj in ipairs(records(tail)) do
            local meaningful=true
            if obj.status=='CANCELLED' or obj.status=='CANCELED' or obj.status=='ABORTED' then
                row,action,pending=0,'已停止',{}
            elseif obj.type=='USER_INPUT' then
                local text=question(obj.content)
                if text~='' then q=text end
                reply,action,row,edited,pending='','正在思考',7,{},{}
            elseif obj.status=='ERROR' or obj.status=='FAILED' then
                row,action,pending=5,'遇到错误',{}
            elseif obj.status=='WAITING_FOR_INPUT' or obj.status=='WAITING_FOR_USER' then row,action=6,'等你回复'
            elseif obj.type=='PLANNER_RESPONSE' then
                confirm()
                local calls=obj.tool_calls
                if type(calls)=='table' and #calls>0 then
                    row,action=7,'正在使用工具'
                    for _,tool in ipairs(calls) do
                        local name=tool.name
                        if row~=6 then action=active[name] or '正在使用工具' end
                        if name=='ask_question' then row,action=6,'等你回复' end
                        if (name=='edit_file' or name=='write_file') and type(tool.args)=='table' and type(tool.args.Path)=='string' then
                            pending[tool.args.Path]=true
                        end
                    end
                elseif obj.status=='DONE' and type(obj.content)=='string' and obj.content:match('%S') then
                    row,action=8,'已回复'
                    local text=clip(obj.content,360)
                    if text~='' then reply=text end
                elseif obj.status=='DONE' then meaningful=false
                else row,action=7,'正在思考' end
            elseif obj.type=='GENERIC' and obj.status=='DONE' then confirm();meaningful=false
            elseif obj.status=='RUNNING' then row,action=7,'正在处理'
            else meaningful=false end
            if meaningful then
                eventTime=epoch(obj.created_at)
                eventKey=table.concat({obj.type or '',obj.status or '',obj.step_index or '',obj.created_at or '',row},'/')
            end
        end
        local n=0;for _ in pairs(edited) do n=n+1 end
        if row==8 and n>0 then action='已编辑 '..n..' 个文件' end
        return {mtime=mtime,size=size,first=first,q=q~='' and q or first,reply=reply,action=action,row=row,
            time=eventTime,key=eventKey}
    end
    return function(path,size,mtime,meta,now)
        if type(path)~='string' or path=='' then return nil end
        local normal=path:gsub('\\','/')
        local id=normal:match('/brain/([%da-fA-F%-]+)/%.system_generated/logs/transcript%.jsonl$')
        if not id or #id~=36 then return nil end
        now=now or os.time(); meta=meta or {}
        local catalogTime=epoch(meta.modified)
        mtime=mtime or catalogTime or 0
        if not size then
            local f=io.open(path,'rb');if not f then return nil end
            size=f:seek('end');f:close();if not size then return nil end
        end
        local data=cache[path]
        if not data or data.mtime~=mtime or data.size~=size then
            local nextData=inspect(path,size,mtime)
            if nextData and not nextData.key and data and size>=data.size then
                data.mtime=mtime;data.size=size
            else data=nextData end
            cache[path]=data
        end
        if not data then return nil end
        local title=clip((meta.title~='' and meta.title) or (data.first~='' and data.first) or data.q,96)
        if title=='' then title='Antigravity 对话' end
        local row,sub=data.row,data.action
        local stamp=data.time or mtime
        local last=lastSeen[path]
        -- An indexed idle status can lag a newly appended user request.
        local current=catalogTime and catalogTime>=stamp
        if meta.killed and current then row,sub=0,'已停止'
        elseif current and (meta.busy or (type(meta.status)=='string' and meta.status:match('_RUNNING$'))) then
            if row==0 or row==8 then row,sub=7,'正在回复' end
        elseif row==7 and current and catalogTime>stamp and meta.status=='CASCADE_RUN_STATUS_IDLE' and now-stamp>=3 then
            row,sub=0,'已结束'
        end
        local terminal=row==8 or row==5
        local ended
        if terminal then
            if last and last.key==data.key and last.row==row then ended=last.ended
            elseif last and (last.row==7 or last.row==6) and now>=last.observed and now-last.observed<=4 then ended=now
            else ended=math.min(stamp,now) end
        end
        lastSeen[path]={key=data.key,row=row,ended=ended,observed=now}
        local visible=row==7 or row==6 or (terminal and now-ended<10)
        local detail=data.reply~='' and data.reply or sub
        return {title=title,sub=sub,question=data.q,reply=detail,row=row,id=id,visible=visible,
            done=row==8,stamp=ended or stamp,expiresAt=ended and ended+10 or nil}
    end
end
