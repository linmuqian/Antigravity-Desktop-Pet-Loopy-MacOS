/* A manually launched AppKit companion. It reads only local transcript metadata. */
#include <dirent.h>
#include <dlfcn.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

typedef void *Obj;
typedef void *Sel;
typedef struct { double x, y; } Point;
typedef struct { double w, h; } Size;
typedef struct { Point origin; Size size; } Rect;
static void *msg;
#ifdef __x86_64__
static void *send_large;
#endif
static Obj (*objclass)(const char *);
static Sel (*selector)(const char *);
static Obj (*makeclass)(Obj, const char *, size_t);
static void (*regclass)(Obj);
static signed char (*addmethod)(Obj, Sel, void (*)(void), const char *);
#define CALL(ret,...) ((ret (*)(Obj,Sel,##__VA_ARGS__))msg)
#define SEL(s) selector(s)
static Obj o0(Obj obj, const char *s) { return CALL(Obj)(obj,SEL(s)); }
static void v0(Obj obj, const char *s) { CALL(void)(obj,SEL(s)); }
static void item(Obj obj,const char *s,Obj a) { CALL(void,Obj)(obj,SEL(s),a); }
static void integer(Obj obj,const char *s,long n) { CALL(void,long)(obj,SEL(s),n); }
static void flag(Obj obj,const char *s,int b) { CALL(void,signed char)(obj,SEL(s),(signed char)b); }
static Obj string(const char *s) { return CALL(Obj,const char *)(objclass("NSString"),SEL("stringWithUTF8String:"),s); }
static int is_type(Obj obj,const char *class_name) {
    return obj && CALL(signed char,Obj)(obj,SEL("isKindOfClass:"),objclass(class_name));
}
static const char *cs(Obj text) {
    if (!is_type(text,"NSString")) return "";
    const char *p=CALL(const char *)(text,SEL("UTF8String"));
    return p?p:"";
}
static Rect rect(Obj obj,const char *s) {
#ifdef __x86_64__
    Rect r; ((void (*)(Rect*,Obj,Sel))send_large)(&r,obj,SEL(s));return r;
#else
    return CALL(Rect)(obj,SEL(s));
#endif
}
static double monotime(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);
    return t.tv_sec+t.tv_nsec/1000000000.0;
}
enum State { IDLE,WORK,WAIT,READY,FAIL };
static const char *labels[]={"待机","工作中","等你回复","本轮已回复","遇到错误"};
static const int counts[]={6,8,8,4,5,8,6,6,6,8,8};
static Obj app,window,card_window,view,controller,menu,caption,images[11][8];
static int state=IDLE,prev_state=-1,dragging=0,facing=1,waking=1;
static double next_poll=0,heading_x;
static Point mouse_down,window_at;
static char brain[4096];

static Rect screen_at(Point p){
    Obj screens=o0(o0(objclass("NSScreen"),"screens"),"objectEnumerator"),s;
    while((s=o0(screens,"nextObject"))){
        Rect r=rect(s,"frame");
        if(p.x>=r.origin.x && p.x<r.origin.x+r.size.w && p.y>=r.origin.y && p.y<r.origin.y+r.size.h)
            return rect(s,"visibleFrame");
    }
    return rect(o0(objclass("NSScreen"),"mainScreen"),"visibleFrame");
}
static Obj panel(Rect bounds){
    Obj p=CALL(Obj,Rect,unsigned long,unsigned long,signed char)(o0(objclass("NSPanel"),"alloc"),
        SEL("initWithContentRect:styleMask:backing:defer:"),bounds,128,2,0);
    flag(p,"setOpaque:",0);flag(p,"setHasShadow:",0);flag(p,"setHidesOnDeactivate:",0);
    flag(p,"setReleasedWhenClosed:",0);integer(p,"setLevel:",3);integer(p,"setCollectionBehavior:",257);
    item(p,"setBackgroundColor:",o0(objclass("NSColor"),"clearColor"));return p;
}
#include "LoopyCards.h"
static Point cursor(void){return CALL(Point)(objclass("NSEvent"),SEL("mouseLocation"));}
static void start_motion(const char *name){
    lua_rawgeti(lua,LUA_REGISTRYINDEX,motion_ref);lua_getfield(lua,-1,name);lua_remove(lua,-2);
}
static void clear_motion(void){start_motion("clear");if(lua_pcall(lua,0,0,0))lua_pop(lua,1);}
static void play(int r,int ambient){start_motion("play");lua_pushinteger(lua,r);lua_pushnumber(lua,monotime());lua_pushboolean(lua,ambient);if(lua_pcall(lua,3,0,0))lua_pop(lua,1);}
static void tick(Obj self,Sel cmd,Obj sender){
    (void)self;(void)cmd;(void)sender;
    double now=monotime();if(now>=next_poll){state=poll_state();paint_cards();next_poll=now+.5;}
    fade_cards();
    if(state!=prev_state){if(state!=IDLE && waking){clear_motion();waking=0;}
        char label[96];snprintf(label,sizeof(label),"Loopy · %s",labels[state]);Obj l=string(label);
        item(window,"setTitle:",l);item(caption,"setTitle:",l);prev_state=state;}
    Point m=cursor();Rect w=rect(window,"frame");double x=m.x-w.origin.x,y=m.y-w.origin.y;
    double top=w.size.h-y;
    int inside=x>=21 && x<133 && top>=0 && top<116;
    flag(window,"setIgnoresMouseEvents:",!dragging && !inside && !(x>=18&&x<138&&y>=18&&y<58));
    if(panel_height>0){
        Rect r=rect(card_window,"frame");
        flag(card_window,"setIgnoresMouseEvents:",!card_hit(m.x-r.origin.x,m.y-r.origin.y));
    }
    int hover=inside && CALL(long,Point,long)(objclass("NSWindow"),SEL("windowNumberAtPoint:belowWindowWithWindowNumber:"),m,0)==CALL(long)(window,SEL("windowNumber"));
    static const int mapping[]={0,7,6,8,5};
    start_motion("frame");lua_pushnumber(lua,now);lua_pushinteger(lua,mapping[state]);
    lua_pushinteger(lua,dragging?facing:0);lua_pushboolean(lua,hover);lua_pushboolean(lua,inside);
    if(lua_pcall(lua,5,2,0)){lua_pop(lua,1);return;}
    int row=(int)lua_tointeger(lua,-2),col=(int)lua_tointeger(lua,-1);lua_pop(lua,2);
    static int last_row=-1,last_col=-1;
    if(row!=last_row || col!=last_col){item(view,"setImage:",images[row][col]);last_row=row;last_col=col;}
}
static signed char accept_mouse(Obj self,Sel cmd,Obj event){(void)self;(void)cmd;(void)event;return 1;}
static void down(Obj self,Sel cmd,Obj e){(void)self;(void)cmd;(void)e;mouse_down=cursor();heading_x=mouse_down.x;window_at=rect(window,"frame").origin;dragging=0;}
static void drag(Obj self,Sel cmd,Obj e){(void)self;(void)cmd;(void)e;Point m=cursor();
    double dx=m.x-mouse_down.x,dy=m.y-mouse_down.y;if(!dragging && hypot(dx,dy)<4)return;
    if(fabs(m.x-heading_x)>=4){facing=m.x>heading_x?1:2;heading_x=m.x;}
    dragging=1;waking=0;Rect screen=screen_at(m);
    Point pos={fmax(screen.origin.x,fmin(window_at.x+dx,screen.origin.x+screen.size.w-156)),
               fmax(screen.origin.y,fmin(window_at.y+dy,screen.origin.y+screen.size.h-177))};
    CALL(void,Point)(window,SEL("setFrameOrigin:"),pos);paint_cards();tick(NULL,NULL,NULL);}
static void up(Obj self,Sel cmd,Obj e){(void)self;(void)cmd;waking=0;
    if(dragging){dragging=0;clear_motion();}
    else play(CALL(long)(e,SEL("clickCount"))>=2?4:3,0);
    tick(NULL,NULL,NULL);}
static void right(Obj self,Sel cmd,Obj e){(void)cmd;CALL(void,Obj,Obj,Obj)(objclass("NSMenu"),SEL("popUpContextMenu:withEvent:forView:"),menu,e,self);}
static void preview(Obj self,Sel cmd,Obj sender){(void)self;(void)cmd;waking=0;play((int)CALL(long)(sender,SEL("tag")),0);tick(NULL,NULL,NULL);}
static void preview_gaze(Obj self,Sel cmd,Obj sender){(void)self;(void)cmd;(void)sender;waking=0;start_motion("previewGaze");lua_pushnumber(lua,monotime());if(lua_pcall(lua,1,0,0))lua_pop(lua,1);tick(NULL,NULL,NULL);}
static void quit(Obj self,Sel cmd,Obj e){(void)self;(void)cmd;(void)e;item(app,"terminate:",NULL);}
static void method(Obj cls,const char *name,void(*fn)(Obj,Sel,Obj)){addmethod(cls,SEL(name),(void(*)(void))fn,"v@:@");}
static Obj menu_item(const char *title,const char *action){
    Obj a=CALL(Obj,Obj,Sel,Obj)(o0(objclass("NSMenuItem"),"alloc"),SEL("initWithTitle:action:keyEquivalent:"),
        string(title),action?SEL(action):NULL,string(""));
    if(action)item(a,"setTarget:",controller);else flag(a,"setEnabled:",0);
    item(menu,"addItem:",a);return a;
}
int main(void){
    if(!dlopen("/System/Library/Frameworks/AppKit.framework/AppKit",RTLD_NOW|RTLD_GLOBAL))return 1;
    msg=dlsym(RTLD_DEFAULT,"objc_msgSend");
#ifdef __x86_64__
    send_large=dlsym(RTLD_DEFAULT,"objc_msgSend_stret");if(!send_large)return 2;
#endif
    objclass=dlsym(RTLD_DEFAULT,"objc_getClass");selector=dlsym(RTLD_DEFAULT,"sel_registerName");
    makeclass=dlsym(RTLD_DEFAULT,"objc_allocateClassPair");regclass=dlsym(RTLD_DEFAULT,"objc_registerClassPair");
    addmethod=dlsym(RTLD_DEFAULT,"class_addMethod");
    if(!msg||!objclass||!selector||!makeclass||!regclass||!addmethod)return 2;
    Obj pool=o0(o0(objclass("NSAutoreleasePool"),"alloc"),"init");
    app=o0(objclass("NSApplication"),"sharedApplication");integer(app,"setActivationPolicy:",1);
    const char *home=getenv("HOME");snprintf(brain,sizeof(brain),"%s/.gemini/antigravity",home?home:"");
    const char *resources=cs(o0(o0(objclass("NSBundle"),"mainBundle"),"resourcePath"));
    if(!start_reader(resources))return 4;
    for(int r=0;r<11;r++)for(int c=0;c<counts[r];c++){
        char path[4096];snprintf(path,sizeof(path),"%s/Frames/%d-%d.png",resources,r,c);
        images[r][c]=CALL(Obj,Obj)(o0(objclass("NSImage"),"alloc"),SEL("initWithContentsOfFile:"),string(path));
        if(!images[r][c])return 3;
    }
    Obj delegate=makeclass(objclass("NSObject"),"LoopyController",0);
    method(delegate,"timerTick:",tick);method(delegate,"preview:",preview);method(delegate,"previewGaze:",preview_gaze);method(delegate,"quitPet:",quit);
    method(delegate,"selectCard:",select_card);method(delegate,"voiceChat:",voice_chat);
    method(delegate,"toggleCards:",toggle_cards);method(delegate,"backCards:",back_cards);method(delegate,"openChat:",open_chat);regclass(delegate);
    controller=o0(o0(delegate,"alloc"),"init");
    Obj pet_class=makeclass(objclass("NSImageView"),"LoopyPetImageView",0);
    addmethod(pet_class,SEL("acceptsFirstMouse:"),(void(*)(void))accept_mouse,"c@:@");
    method(pet_class,"mouseDown:",down);method(pet_class,"mouseDragged:",drag);
    method(pet_class,"mouseUp:",up);method(pet_class,"rightMouseDown:",right);regclass(pet_class);
    Rect screen=rect(o0(objclass("NSScreen"),"mainScreen"),"visibleFrame");
    Rect bounds={{screen.origin.x+screen.size.w-330,screen.origin.y+16},{156,177}};
    window=panel(bounds);card_window=panel((Rect){{0,0},{366,92}});
    Obj frame_name=string("LoopyPet");
    CALL(signed char,Obj,signed char)(window,SEL("setFrameUsingName:force:"),frame_name,1);
    CALL(signed char,Obj)(window,SEL("setFrameAutosaveName:"),frame_name);
    container=new_frame("NSView",0,0,156,177);item(window,"setContentView:",container);
    card_container=new_frame("NSView",0,0,366,92);item(card_window,"setContentView:",card_container);
    Rect local={{21,61},{112,121}};view=CALL(Obj,Rect)(o0(pet_class,"alloc"),SEL("initWithFrame:"),local);
    integer(view,"setImageScaling:",3);item(view,"setImage:",images[0][0]);item(container,"addSubview:",view);
    if(!make_cards())return 5;
    menu=CALL(Obj,Obj)(o0(objclass("NSMenu"),"alloc"),SEL("initWithTitle:"),string("Loopy"));
    flag(menu,"setAutoenablesItems:",0);caption=menu_item("Loopy",NULL);
    const char *actions[]={"待机","向右跑","向左跑","挥挥手","跳一下","遇到错误","等你回复","敲电脑","检查回复"};
    for(int i=0;i<9;i++)integer(menu_item(actions[i],"preview:"),"setTag:",i);
    menu_item("预览视线","previewGaze:");menu_item("退出 Loopy","quitPet:");
    v0(app,"finishLaunching");v0(window,"orderFrontRegardless");play(3,1);tick(NULL,NULL,NULL);
    Obj timer=CALL(Obj,double,Obj,Sel,Obj,signed char)(objclass("NSTimer"),SEL("timerWithTimeInterval:target:selector:userInfo:repeats:"),
        .032,controller,SEL("timerTick:"),NULL,1);
    Obj *common=(Obj*)dlsym(RTLD_DEFAULT,"NSRunLoopCommonModes");
    CALL(void,Obj,Obj)(o0(objclass("NSRunLoop"),"mainRunLoop"),SEL("addTimer:forMode:"),timer,common?*common:string("kCFRunLoopCommonModes"));
    v0(app,"run");v0(pool,"drain");return 0;
}
