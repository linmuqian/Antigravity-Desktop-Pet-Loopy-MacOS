"""Render the transparent desktop controls at 2x for both native hosts."""
from PIL import Image, ImageDraw, ImageFilter

S = 4
PAD = 18
INK = (33, 35, 40, 255)


def surface(width, height, radius):
    size = ((width + PAD*2)*S, (height + PAD*2)*S)
    def rounded(offset=0):
        mask = Image.new('L', size)
        ImageDraw.Draw(mask).rounded_rectangle(
            (PAD*S,(PAD+offset)*S,(PAD+width)*S-1,(PAD+height+offset)*S-1),
            radius*S, fill=255)
        return mask
    sh = rounded(3).filter(ImageFilter.GaussianBlur(7.4*S)).point(lambda a: round(a*.198))
    out = Image.new('RGBA',size); out.putalpha(sh)
    white = Image.new('RGBA',size,'white');white.putalpha(rounded())
    return Image.alpha_composite(out,white)


def assets(folder):
    folder.mkdir(parents=True,exist_ok=True)
    def save(image,name):
        image.resize((image.width//2,image.height//2),Image.Resampling.LANCZOS).save(folder/(name+'.png'),optimize=True)
    save(surface(330,56,28),'Bubble')
    save(surface(330,120,23),'Detail')
    def stroke(draw,points,width=1.45,color=INK):
        p=[(round(x*S),round(y*S)) for x,y in points]
        thick=max(1,round(width*S));draw.line(p,fill=color,width=thick,joint='curve')
        r=thick/2
        for x,y in p:
            draw.ellipse((round(x-r),round(y-r),round(x+r),round(y+r)),fill=color)
    for opened in (False,True):
        im=surface(120,40,20); d=ImageDraw.Draw(im)
        def line(points,width=1.35,color=INK):
            stroke(d,[(PAD+x,PAD+y) for x,y in points],width,color)
        for x in (40,80): line([(x,11),(x,29)],.8,(234,235,237,255))
        # Open square and pencil, waveform, and disclosure chevron.
        line([(20.2,13),(16,13),(14.2,13.6),(13.5,15.3),(13.5,24.4),(14.1,26),(15.8,26.7),
              (25,26.7),(26.3,26),(27,24.3),(27,21.2)])
        line([(18,22.1),(18.6,19.3),(24.7,13.1),(26.1,12.8),(27,13.8),(27,15),(20.7,21.3),(18,22.1)])
        for x,h in ((54.5,4),(58,8),(61.5,12),(65,6)): line([(x,20-h/2),(x,20+h/2)],1.35)
        line([(95.6,18.2 if opened else 21.7),(100,22.5 if opened else 17.4),(104.4,18.2 if opened else 21.7)],1.55)
        save(im,'ToolbarOpen' if opened else 'Toolbar')
    chk=Image.new('RGBA',(14*S,14*S));stroke(ImageDraw.Draw(chk),[(2.2,7.3),(5.3,10.3),(11.8,3.8)],1.8,(35,151,73,255))
    save(chk,'Check')
