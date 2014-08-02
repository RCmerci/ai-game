%% person infomation
-record(person, {name,
                 x,
                 y,
                 hp=100,
                 mp=100,
                 damage=10,
                 direction=right,
                 alive=true}).

%% 下面这些暂时没用---------------------------------------
%% gsc:gamer sent content,也就是玩家发送的内容的一个record
-record(gsc, {content_type, content}).
%% get_info:请求person信息的record
-record(get_info, {content=[]}).
%% set：玩家操作person
-record(set, {name, direction, attack}).
%% ------------------------------------------------------

%% some config macros
-define(RD_PERSON, person).
-define(ETS_TABLE_NAME, person_info).
-define(ETS_KEY_POS, name).
