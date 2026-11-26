return function(resources)
    local m=dofile(resources..'Motion.lua')
    local function check(t,state,drag,over,inside,row,col)
        local r,c=m.frame(t,state,drag,over,inside)
        assert(r==row and (col==nil or c==col),string.format('t=%.3f expected %d/%s, got %d/%d',t,row,tostring(col),r,c))
    end
    for _,state in ipairs({0,7,6,5,8}) do
        m=dofile(resources..'Motion.lua')
        check(1,state,0,false,false,state)
        check(2,state,0,true,true,4,0)
        for pass=0,2 do
            for c=0,4 do check(2+pass*.84+c*.14+.001,state,0,true,true,4,c) end
        end
        check(4.521,state,0,true,true,0,0)
        check(4.6,state,0,false,false,state)
        check(5,state,0,true,true,4,0)
        check(5.1,state,0,false,false,state)
    end
    m=dofile(resources..'Motion.lua')
    m.play(3,0,true);check(.1,0,0,false,false,3)
    check(.2,0,0,true,true,4,0)
    check(.3,7,1,true,true,1);check(.6,7,2,true,true,2)
    check(.7,6,0,false,true,6);check(.8,6,0,true,true,6)
    check(.9,6,0,false,false,6);check(1,6,0,true,true,4,0)
    -- Occluded body and toolbar never hover. A fresh re-entry interrupts a wave.
    check(2,7,0,false,true,7);m.play(3,2);check(2.01,7,0,false,false,3)
    check(2.1,7,0,true,true,4);check(2.2,7,0,false,false,7)
    m.previewGaze(3)
    for i=0,15 do check(3+i*.18+.001,0,0,false,false,9+math.floor(i/8),i%8) end
    check(5.881,0,0,false,false,0)
    return 'PASS - hover timing, exact 5 frames and 3 cycles, interruption, active states, release, occlusion, 16 original gaze poses'
end
