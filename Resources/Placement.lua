-- Screen coordinates increase downwards. Keep conversation cards inside this work area.
return function(x,y,left,top,width,height,total,detail)
    local above=math.max(0,y-top-1)
    local below=math.max(0,top+height-y-165)
    local wanted=math.min(6,total)
    local h=detail and 156 or (wanted>0 and 28+64*wanted or 0)
    local up=above>=h or (below<h and above>=below)
    local capacity=math.max(1,math.min(6,math.floor(((up and above or below)-28)/64)))
    local count=math.min(wanted,capacity)
    h=detail and 156 or (count>0 and 28+64*count or 0)
    local px=math.max(left,math.min(x-157,left+width-366))
    local py=math.max(top,math.min(up and y-1-h or y+165,top+height-h))
    return px,py,h,count,capacity
end
