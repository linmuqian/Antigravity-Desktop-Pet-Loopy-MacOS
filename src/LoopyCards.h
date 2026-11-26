/* AppKit views. Both hosts consume the same activity feed and UI artwork. */
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
enum { SLOT_COUNT=6 };
typedef struct {char title[500],sub[200],question[1200],reply[1800],id[64];int done;double expires_at;} Card;
static Card slots[SLOT_COUNT];
static int shown[SLOT_COUNT],history_mode,scroll_offset,detail_visible;
static char chosen[64],ui_path[4096];
static double voice_until;
static lua_State *lua;
static int feed_ref,motion_ref,place_ref,snapshot_ref=LUA_NOREF,panel_height=0;
static Obj container,card_container,tiles[SLOT_COUNT],heads[SLOT_COUNT],subs[SLOT_COUNT],checks[SLOT_COUNT];
static Obj detail,detail_title,detail_q,detail_a,bar_image,art_bubble,art_detail,art_bar[2],art_check,hit_class;

static Obj new_frame(const char *cls,double x,double y,double w,double h){
    Rect f={{x,y},{w,h}};return CALL(Obj,Rect)(o0(objclass(cls),"alloc"),SEL("initWithFrame:"),f);
}
static void frame_of(Obj v,double x,double y,double w,double h){
    Rect f={{x,y},{w,h}};CALL(void,Rect)(v,SEL("setFrame:"),f);
}
static Obj artwork(const char *name){
    char file[4096];snprintf(file,sizeof(file),"%s/UI/%s.png",ui_path,name);
    return CALL(Obj,Obj)(o0(objclass("NSImage"),"alloc"),SEL("initWithContentsOfFile:"),string(file));
}
static Obj picture(Obj parent,double x,double y,double w,double h,Obj img){
    Obj v=new_frame("NSImageView",x,y,w,h);integer(v,"setImageScaling:",3);item(v,"setImage:",img);
    item(parent,"addSubview:",v);return v;
}
static Obj group(Obj parent,double x,double y,double w,double h){
    Obj v=new_frame("NSView",x,y,w,h);item(parent,"addSubview:",v);return v;
}
static Obj label(Obj parent,double x,double y,double w,double h,double size,int bold,int multiline){
    Obj v=new_frame("NSTextField",x,y,w,h);
    flag(v,"setEditable:",0);flag(v,"setSelectable:",0);flag(v,"setBezeled:",0);flag(v,"setDrawsBackground:",0);
    item(v,"setFont:",CALL(Obj,double,double)(objclass("NSFont"),SEL("systemFontOfSize:weight:"),size,bold?.40:0));
    item(v,"setTextColor:",CALL(Obj,double,double)(objclass("NSColor"),SEL("colorWithCalibratedWhite:alpha:"),bold?.13:.44,1.0));
    Obj cell=o0(v,"cell");flag(cell,"setWraps:",multiline);integer(cell,"setLineBreakMode:",multiline?0:4);
    integer(v,"setMaximumNumberOfLines:",multiline?3:1);item(parent,"addSubview:",v);return v;
}
static void set_label(Obj control,const char *text){
    Obj s=string(text);if(!s)s=string("");
    if(!CALL(signed char,Obj)(o0(control,"stringValue"),SEL("isEqualToString:"),s))item(control,"setStringValue:",s);
}
static Obj hit(Obj parent,double x,double y,double w,double h,const char *action,const char *hint){
    Rect f={{x,y},{w,h}};Obj v=CALL(Obj,Rect)(o0(hit_class,"alloc"),SEL("initWithFrame:"),f);
    item(v,"setTitle:",string(""));flag(v,"setBordered:",0);flag(v,"setTransparent:",1);item(v,"setTarget:",controller);
    CALL(void,Sel)(v,SEL("setAction:"),SEL(action));item(v,"setToolTip:",string(hint));item(parent,"addSubview:",v);return v;
}
static int start_reader(const char *resources){
    snprintf(ui_path,sizeof(ui_path),"%s",resources);
    lua=luaL_newstate();if(!lua)return 0;luaL_openlibs(lua);
    char file[4096];snprintf(file,sizeof(file),"%s/ActivityFeed.lua",resources);
    if(luaL_dofile(lua,file)!=0)return 0;
    lua_pushstring(lua,resources);if(lua_pcall(lua,1,1,0)!=0)return 0;
    feed_ref=luaL_ref(lua,LUA_REGISTRYINDEX);
    snprintf(file,sizeof(file),"%s/Motion.lua",resources);if(luaL_dofile(lua,file)!=0)return 0;
    motion_ref=luaL_ref(lua,LUA_REGISTRYINDEX);
    snprintf(file,sizeof(file),"%s/Placement.lua",resources);if(luaL_dofile(lua,file)!=0)return 0;
    place_ref=luaL_ref(lua,LUA_REGISTRYINDEX);return 1;
}
static void table_text(const char *key,char *dst,size_t cap){
    lua_getfield(lua,-1,key);const char *s=lua_tostring(lua,-1);snprintf(dst,cap,"%s",s?s:"");lua_pop(lua,1);
}
static void card_at(int index,Card *c){
    lua_rawgeti(lua,-1,index);table_text("id",c->id,sizeof(c->id));table_text("title",c->title,sizeof(c->title));
    table_text("sub",c->sub,sizeof(c->sub));table_text("question",c->question,sizeof(c->question));table_text("reply",c->reply,sizeof(c->reply));
    lua_getfield(lua,-1,"done");c->done=lua_toboolean(lua,-1);lua_pop(lua,1);
    lua_getfield(lua,-1,"expiresAt");c->expires_at=lua_tonumber(lua,-1);lua_pop(lua,2);
}
static void fade_cards(void){
    struct timespec t;clock_gettime(CLOCK_REALTIME,&t);double stamp=t.tv_sec+t.tv_nsec/1000000000.0;
    for(int i=0;i<SLOT_COUNT;i++)if(shown[i]){
        double a=!history_mode && slots[i].expires_at>0?fmin(1,fmax(0,(slots[i].expires_at-stamp)/.26)):1;
        CALL(void,double)(tiles[i],SEL("setAlphaValue:"),a);
    }
}
static int poll_state(void){
    lua_rawgeti(lua,LUA_REGISTRYINDEX,feed_ref);lua_pushstring(lua,brain);lua_newtable(lua);
    char directory[4096];snprintf(directory,sizeof(directory),"%s/brain",brain);
    DIR *root=opendir(directory);int n=0;
    if(root){
        struct dirent *e;while((e=readdir(root))){
            if(strlen(e->d_name)!=36 || strspn(e->d_name,"abcdefABCDEF0123456789-")!=36)continue;
            char path[4096];int size=snprintf(path,sizeof(path),"%s/%s/.system_generated/logs/transcript.jsonl",directory,e->d_name);
            struct stat st;if(size<0 || (size_t)size>=sizeof(path) || stat(path,&st)!=0 || !S_ISREG(st.st_mode))continue;
            lua_createtable(lua,0,3);lua_pushstring(lua,e->d_name);lua_setfield(lua,-2,"id");
            lua_pushnumber(lua,(double)st.st_size);lua_setfield(lua,-2,"size");
            lua_pushnumber(lua,(double)st.st_mtimespec.tv_sec);lua_setfield(lua,-2,"mtime");lua_rawseti(lua,-2,++n);
        }closedir(root);
    }
    if(lua_pcall(lua,2,1,0)!=0){lua_pop(lua,1);return state;}
    lua_getfield(lua,-1,"state");int row=(int)lua_tointeger(lua,-1);lua_pop(lua,1);
    if(snapshot_ref!=LUA_NOREF)luaL_unref(lua,LUA_REGISTRYINDEX,snapshot_ref);
    snapshot_ref=luaL_ref(lua,LUA_REGISTRYINDEX);
    switch(row){case 7:return WORK;case 6:return WAIT;case 8:return READY;case 5:return FAIL;default:return IDLE;}
}
static void paint_cards(void){
    int len=0,found=0;Card selected={0};
    if(snapshot_ref!=LUA_NOREF){
        lua_rawgeti(lua,LUA_REGISTRYINDEX,snapshot_ref);lua_getfield(lua,-1,history_mode?"recent":"live");
        len=(int)lua_objlen(lua,-1);
        if(chosen[0])for(int i=1;i<=len;i++){
            card_at(i,&selected);if(!strcmp(chosen,selected.id)){found=1;break;}
        }
    }
    if(!found)chosen[0]=0;
    int hint=monotime()<voice_until,empty=history_mode && len==0;
    detail_visible=found||hint||empty;flag(detail,"setHidden:",!detail_visible);
    if(detail_visible){
        char q[1550]="",a[2048]="";
        const char *title=hint?"语音对话":found?selected.title:"最近的对话";
        if(hint){snprintf(q,sizeof(q),"在 Antigravity 中开始");snprintf(a,sizeof(a),"点空白输入框右侧的声波按钮即可开始。");}
        else if(found){
            if(selected.question[0])snprintf(q,sizeof(q),"你：%s",selected.question);
            snprintf(a,sizeof(a),"Gemini：%s",selected.reply);
        }else snprintf(a,sizeof(a),"有新对话时，会显示在这里。");
        set_label(detail_title,title);set_label(detail_q,q);set_label(detail_a,a);
    }
    Rect pet=rect(window,"frame");
    Rect screen=screen_at((Point){pet.origin.x+78,pet.origin.y+88});
    lua_rawgeti(lua,LUA_REGISTRYINDEX,place_ref);lua_pushnumber(lua,pet.origin.x);lua_pushnumber(lua,-pet.origin.y-pet.size.h);
    lua_pushnumber(lua,screen.origin.x);lua_pushnumber(lua,-screen.origin.y-screen.size.h);
    lua_pushnumber(lua,screen.size.w);lua_pushnumber(lua,screen.size.h);lua_pushinteger(lua,len);lua_pushboolean(lua,detail_visible);
    if(lua_pcall(lua,8,5,0)){lua_pop(lua,1);if(snapshot_ref!=LUA_NOREF)lua_pop(lua,2);return;}
    double px=lua_tonumber(lua,-5),py=lua_tonumber(lua,-4);
    int h=(int)lua_tointeger(lua,-3),count=detail_visible?0:(int)lua_tointeger(lua,-2),capacity=(int)lua_tointeger(lua,-1);
    lua_pop(lua,5);
    int maxoff=len>capacity?len-capacity:0;
    if(scroll_offset>maxoff)scroll_offset=maxoff;if(scroll_offset<0)scroll_offset=0;
    for(int i=0;i<SLOT_COUNT;i++){
        shown[i]=i<count;flag(tiles[i],"setHidden:",!shown[i]);
        if(shown[i]){
            Card *c=&slots[i];card_at(scroll_offset+count-i,c);
            flag(checks[i],"setHidden:",!c->done);frame_of(heads[i],c->done?51:32,45,c->done?281:300,20);
            set_label(heads[i],c->title);set_label(subs[i],c->sub);
        }
    }
    if(snapshot_ref!=LUA_NOREF)lua_pop(lua,2);
    item(bar_image,"setImage:",art_bar[history_mode]);
    if(h){
        Rect next={{px,-py-h},{366,h}},old=rect(card_window,"frame");
        if(old.origin.x!=next.origin.x || old.origin.y!=next.origin.y || panel_height!=h)
            CALL(void,Rect,signed char)(card_window,SEL("setFrame:display:"),next,1);
        if(!panel_height)v0(card_window,"orderFrontRegardless");
    }else if(panel_height)item(card_window,"orderOut:",NULL);
    panel_height=h;
}
static void open_chat(Obj self,Sel cmd,Obj e){
    (void)self;(void)cmd;(void)e;
    Obj workspace=o0(objclass("NSWorkspace"),"sharedWorkspace");
    // The empty deep link opens two windows on a cold start in Antigravity 2.35.2.
    Obj application=CALL(Obj,Obj)(workspace,SEL("URLForApplicationWithBundleIdentifier:"),string("com.google.antigravity"));
    if(application)CALL(signed char,Obj)(workspace,SEL("openURL:"),application);
    else CALL(signed char,Obj)(workspace,SEL("launchApplication:"),string("Antigravity"));
}
static void select_card(Obj self,Sel cmd,Obj sender){
    (void)self;(void)cmd;int i=(int)CALL(long)(sender,SEL("tag"));
    if(i>=0 && i<SLOT_COUNT && shown[i]){snprintf(chosen,sizeof(chosen),"%s",slots[i].id);voice_until=0;paint_cards();}
}
static void back_cards(Obj self,Sel cmd,Obj e){(void)self;(void)cmd;(void)e;chosen[0]=0;voice_until=0;paint_cards();}
static void toggle_cards(Obj self,Sel cmd,Obj e){
    (void)self;(void)cmd;(void)e;history_mode=!history_mode;scroll_offset=0;chosen[0]=0;voice_until=0;paint_cards();
}
static void voice_chat(Obj self,Sel cmd,Obj e){chosen[0]=0;voice_until=monotime()+8;paint_cards();open_chat(self,cmd,e);}
static void wheel(Obj self,Sel cmd,Obj event){
    (void)self;(void)cmd;double delta=CALL(double)(event,SEL("scrollingDeltaY"));
    if(fabs(delta)>.1){scroll_offset+=delta<0?1:-1;paint_cards();}
}
static int card_hit(double x,double y){
    if(x<18 || x>348)return 0;
    if(detail_visible && y>=18 && y<=138)return 1;
    for(int i=0;i<SLOT_COUNT;i++){int start=18+64*i;if(shown[i] && y>=start && y<=start+56)return 1;}
    return 0;
}
static int make_cards(void){
    hit_class=makeclass(objclass("NSButton"),"LoopyActivityControl",0);
    addmethod(hit_class,SEL("scrollWheel:"),(void(*)(void))wheel,"v@:@");regclass(hit_class);
    art_bubble=artwork("Bubble");art_detail=artwork("Detail");art_check=artwork("Check");
    art_bar[0]=artwork("Toolbar");art_bar[1]=artwork("ToolbarOpen");
    if(!art_bubble||!art_detail||!art_check||!art_bar[0]||!art_bar[1])return 0;
    for(int i=SLOT_COUNT-1;i>=0;i--){
        tiles[i]=group(card_container,0,64*i,366,92);
        picture(tiles[i],0,0,366,92,art_bubble);heads[i]=label(tiles[i],32,45,300,20,13.4,1,0);
        subs[i]=label(tiles[i],32,29,300,19,12.8,0,0);checks[i]=picture(tiles[i],34,46,14,14,art_check);
        Obj control=hit(tiles[i],18,18,330,56,"selectCard:","查看对话");integer(control,"setTag:",i);
    }
    detail=group(card_container,0,0,366,156);picture(detail,0,0,366,156,art_detail);
    detail_title=label(detail,32,106,300,22,13.4,1,0);detail_q=label(detail,32,81,300,22,12.8,0,0);
    detail_a=label(detail,32,23,300,55,12.8,0,1);hit(detail,18,18,330,120,"backCards:","返回");
    Obj bar=group(container,0,0,156,76);bar_image=picture(bar,0,0,156,76,art_bar[0]);
    hit(bar,18,18,40,40,"openChat:","打开 Antigravity 对话");
    hit(bar,58,18,40,40,"voiceChat:","打开 Antigravity 语音入口");
    hit(bar,98,18,40,40,"toggleCards:","查看或收起最近对话");paint_cards();return 1;
}
