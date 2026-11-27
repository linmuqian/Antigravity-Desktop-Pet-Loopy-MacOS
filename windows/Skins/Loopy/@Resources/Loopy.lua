local panel='Loopy\\Activity'
local labels={[0]='待机',[7]='工作中',[6]='等你回复',[8]='本轮已回复',[5]='遇到错误'}
local measures,slots,options,visibility={},{},{},{}
local history,offset,selected,voiceUntil=false,0,nil,0
local activity={live={},recent={},state=0}
local resource,feed,base,motion,place
local panelX,panelY,panelShown,displayed,toolbar
local prevX,prevY,pivotX,facing,runUntil=nil,nil,nil,1,0
local dragging,waking=false,true
local nextPoll,wallSecond,wallStart=0,0,0
local ready,firstPaint=false,0
local skipTap=false
local nativeHover=false
local captured=false

function Initialize()
    resource=SKIN:GetVariable('@')
    feed=dofile(resource..'ActivityFeed.lua')(resource)
    motion=dofile(resource..'Motion.lua')
    place=dofile(resource..'Placement.lua')
    base=(os.getenv('USERPROFILE') or '')..'/.gemini/antigravity'
    for i=1,12 do
        measures[i]={path=SKIN:GetMeasure('LatestPath'..i),size=SKIN:GetMeasure('LatestSize'..i),date=SKIN:GetMeasure('LatestDate'..i)}
    end
    motion.play(3,os.clock(),true)
    firstPaint=os.clock()+.75
end
local function option(name,key,value)
    value=tostring(value)
    local id=name..'/'..key
    if options[id]~=value then
        options[id]=value
        SKIN:Bang('!SetOption',name,key,value,panel)
    end
end
local function label(name,value)
    value=(value or ''):gsub('#','＃'):gsub('%[','［'):gsub('%]','］'):gsub('%$','＄'):gsub('%%','％')
    option(name,'Text',value)
end
local function visible(name,on,isGroup)
    on=not not on
    if visibility[name]~=on then
        visibility[name]=on
        SKIN:Bang((on and '!ShowMeter' or '!HideMeter')..(isGroup and 'Group' or ''),name,panel)
    end
end
local function number(name,default) return tonumber(SKIN:GetVariable(name)) or default end
local function workArea(x,y)
    local cx,cy=x+78,y+88
    for i=1,math.max(1,number('NUMMONITORS',1)) do
        local suffix='@'..i
        local sx,sy=number('SCREENAREAX'..suffix,0),number('SCREENAREAY'..suffix,0)
        if cx>=sx and cy>=sy and cx<sx+number('SCREENAREAWIDTH'..suffix,0) and cy<sy+number('SCREENAREAHEIGHT'..suffix,0) then
            return number('WORKAREAX'..suffix,sx),number('WORKAREAY'..suffix,sy),number('WORKAREAWIDTH'..suffix,1920),number('WORKAREAHEIGHT'..suffix,1080)
        end
    end
    return number('WORKAREAX',0),number('WORKAREAY',0),number('WORKAREAWIDTH',1920),number('WORKAREAHEIGHT',1080)
end
local function paint()
    if not ready then return end
    local list=history and activity.recent or activity.live
    local detail
    if selected then
        for _,c in ipairs(list) do if c.id==selected then detail=c;break end end
        if not detail then selected=nil end
    end
    local hint=voiceUntil>os.time()
    local empty=history and #list==0
    local expanded=detail~=nil or hint or empty
    local x,y=number('CURRENTCONFIGX',0),number('CURRENTCONFIGY',0)
    local l,t,w,h=workArea(x,y)
    local px,py,height,count,cap=place(x,y,l,t,w,h,#list,expanded)
    offset=math.min(offset,math.max(0,#list-cap))
    if expanded then count=0 end
    visible('Detail',expanded,true)
    if expanded then
        label('DetailTitle',hint and '语音对话' or (detail and detail.title or '最近的对话'))
        label('DetailQ',hint and '在 Antigravity 中开始' or (detail and detail.question~='' and '你：'..detail.question or ''))
        label('DetailA',hint and '点空白输入框右侧的声波按钮即可开始。' or (detail and 'Gemini：'..detail.reply or '有新对话时，会显示在这里。'))
    end
    for i=1,6 do
        local c=i<=count and list[offset+count-i+1] or nil
        slots[i]=c
        visible('Card'..i,c~=nil,true)
        visible('Check'..i,c and c.done,false)
        if c then
            local top=(count-i)*64
            local tx=c.done and 53 or 34
            option('Bubble'..i,'Y',top)
            option('Title'..i,'X',tx);option('Title'..i,'Y',top+27);option('Title'..i,'W',332-tx)
            option('Status'..i,'Y',top+44);option('Check'..i,'Y',top+32);option('OpenCard'..i,'Y',top+18)
            label('Title'..i,c.title);label('Status'..i,c.sub)
        end
    end
    if height>0 and (px~=panelX or py~=panelY) then
        panelX,panelY=px,py
        SKIN:Bang('!Move',tostring(px),tostring(py),panel)
    end
    if panelShown~=(height>0) then
        panelShown=height>0
        SKIN:Bang(panelShown and '!Show' or '!Hide',panel)
    end
    if toolbar~=history then
        toolbar=history
        SKIN:Bang('!SetOption','ToolStrip','ImageName',resource..'UI\\'..(history and 'ToolbarOpen' or 'Toolbar')..'.png')
    end
end
function PanelReady()
    ready=true
    options,visibility={},{}
    panelX,panelY,panelShown=nil,nil,nil
    if place then paint() end
end
local function refresh()
    local now=os.time();local utc=os.date('!*t',now);utc.isdst=os.date('*t',now).isdst
    local delta=11644473600+os.difftime(now,os.time(utc))
    local sources={}
    for _,m in ipairs(measures) do
        if m.path and m.size and m.date then
            local path=m.path:GetStringValue() or ''
            local id=path:lower():match('\\%.gemini\\antigravity\\brain\\([%da-f%-]+)\\%.system_generated\\logs\\transcript%.jsonl$')
            if id then sources[#sources+1]={id=id,size=m.size:GetValue(),mtime=m.date:GetValue()-delta} end
        end
    end
    local old=activity.state
    activity=feed(base,sources,now)
    if activity.state~=old then
        SKIN:Bang('!SetVariable','Activity',labels[activity.state])
        if waking then motion.clear();waking=false end
    end
    paint()
end
function SelectCard(i) if slots[i] then selected=slots[i].id;voiceUntil=0;paint() end end
function Back() selected=nil;voiceUntil=0;paint() end
function Toggle() history=not history;offset=0;selected=nil;voiceUntil=0;paint() end
function Scroll(delta) offset=math.max(0,offset+delta);paint() end
function OpenApp()
    -- Delegate to LaunchAntigravity.ps1 so custom Antigravity.lnk wrappers are honored
    -- while avoiding the empty antigravity:// cold-start dual-window bug in Antigravity 2.35.2.
    SKIN:Bang('!CommandMeasure','LaunchAntigravity','Run')
end
function Voice() selected=nil;voiceUntil=os.time()+8;paint();OpenApp() end
function Play(row)
    if not dragging then waking=false;motion.play(row,os.clock()) end
end
function Hover(on) nativeHover=on==1 end
function PreviewGaze() if not dragging then waking=false;motion.previewGaze(os.clock()) end end
function Tap()
    if skipTap then skipTap=false else Play(3) end
end
function DoubleTap()
    skipTap=true
    Play(4)
end
local function pointer()
    local f=io.open(resource..'Pointer.state','rb')
    if not f then return end
    local line=f:read('*l') or '';f:close()
    local stamp,held,run,zone=line:match('^(%d+) ([01]) ([012]) ([012]) H')
    if stamp and math.abs(os.time()-tonumber(stamp))<=2 then return held=='1',tonumber(run),tonumber(zone) end
end
function Update()
    local now=os.clock()
    if not ready and now>=firstPaint then PanelReady() end
    local x,y=number('CURRENTCONFIGX',0),number('CURRENTCONFIGY',0)
    local held,pointerRun,zone=pointer()
    local moved=prevX and (x~=prevX or y~=prevY)
    if held then
        captured=captured or nativeHover or zone==1 or moved
    else captured=false end
    if moved and held~=false then
        if math.abs(x-pivotX)>=4 then facing=x>pivotX and 1 or 2;pivotX=x end
        runUntil=now+.18
    end
    local run=0
    if pointerRun and pointerRun>0 and captured then facing=pointerRun;run=facing
    elseif held~=false and (now<runUntil or (held and dragging)) then run=facing end
    if not prevX or held==false then pivotX=x end
    prevX,prevY=x,y
    if run>0 then waking=false;skipTap=false
    elseif dragging then motion.clear() end
    dragging=run>0
    if now>=nextPoll then refresh();nextPoll=now+.5
    elseif moved then paint() end
    local sec=os.time()
    if sec~=wallSecond then wallSecond,wallStart=sec,now end
    local clock=sec+math.min(.99,now-wallStart)
    for i,c in pairs(slots) do
        local a=255
        if not history and c.expiresAt then a=math.floor(255*math.min(1,math.max(0,(c.expiresAt-clock)/.26))) end
        option('Bubble'..i,'ImageAlpha',a);option('Check'..i,'ImageAlpha',a)
        option('Title'..i,'FontColor','31,33,37,'..a);option('Status'..i,'FontColor','111,113,118,'..a)
    end
    local hover,inside=nativeHover,nativeHover
    -- A layered Rainmeter window can own the native hover even when UI Automation
    -- returns the window beneath its pixels. Its own meter event is authoritative.
    if zone~=nil then inside=zone>0;hover=inside and (nativeHover or zone==1) end
    local row,col=motion.frame(now,activity.state,run,hover,inside)
    local key=row..'-'..col
    if key~=displayed then SKIN:Bang('!SetVariable','Frame',key);displayed=key end
    return activity.state
end
