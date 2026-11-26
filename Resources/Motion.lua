-- Shared by the Windows and AppKit renderers. Durations are milliseconds.
local times = {
    [0]={1680,660,660,840,840,1920},
    {120,120,120,120,120,120,120,220}, {120,120,120,120,120,120,120,220},
    {140,140,140,280}, {140,140,140,140,280}, {140,140,140,140,140,140,140,240},
    {150,150,150,150,150,260}, {120,120,120,120,120,220}, {150,150,150,150,150,280}
}
local cycles={}
for row,frames in pairs(times) do
    local length=0
    for _,ms in ipairs(frames) do length=length+ms end
    cycles[row]=length
end
local motion={row=-1,start=0}
function motion.clear()
    motion.preview=nil
    motion.gazePreview=nil
    motion.row=-1
end
function motion.play(row,now,ambient)
    if not times[row] then return end
    motion.clear()
    motion.preview=row
    motion.ambient=ambient
    motion.untilTime=now+3*cycles[row]/1000
end
function motion.previewGaze(now)
    motion.clear()
    motion.gazePreview=now
end
function motion.frame(now,activity,run,hover,inside)
    if not inside then motion.ignoreHover=false end
    if not hover then motion.hoverStart=nil end
    local row=activity
    if run==1 or run==2 then
        motion.preview,motion.gazePreview,motion.hoverStart=nil,nil,nil
        motion.dragged=true
        motion.ignoreHover=true
        row=run
    else
        if motion.dragged then motion.ignoreHover=inside;motion.dragged=false end
        if hover and not motion.ignoreHover and not motion.hoverStart then
            motion.hoverStart=now
            motion.preview=nil
            motion.row=-1
        end
        if motion.gazePreview then
            -- The gaze preview in the original design chat holds each pose for 180 ms.
            local sector=math.floor((now-motion.gazePreview)/.18)
            if sector>=0 and sector<16 then return 9+math.floor(sector/8),sector%8 end
            motion.gazePreview=nil
        end
        local preview=motion.preview and now<motion.untilTime
        if preview and not motion.ambient then
            row=motion.preview
        elseif motion.hoverStart then
            -- Codex plays the five jump frames three times per entry, then slow idle.
            -- Leaving the body interrupts the gesture. A completed drag rearms on exit.
            row=now-motion.hoverStart<3*cycles[4]/1000 and 4 or 0
        elseif preview then
            row=motion.preview
        end
    end
    if motion.row~=row or now<motion.start then motion.row,motion.start=row,now end
    local elapsed=(math.floor((now-motion.start)*1000+.5))%cycles[row]
    for i,ms in ipairs(times[row]) do
        if elapsed<ms then return row,i-1 end
        elapsed=elapsed-ms
    end
end
return motion
