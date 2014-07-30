-module('1').
-export([init/0]).
-export([get_connect/3, start/0, loop_for_every_one/1]).
%%先把record写在这里，以后移到一个单独的hrl文件
-record(person, {name,
                 x,
                 y,
                 hp=100,
                 mp=100,
                 damage=10,
                 direction=right,
                 alive=true}).
%% gsc:gamer sent content,也就是玩家发送的内容的一个record
-record(gsc, {content_type, content}).
%% get_info:请求person信息的record
-record(get_info, {content=[]}).
%% set：玩家操作person
-record(set, {name, direction, attack}).
%%初始化
init()->
    %%ets table放在这里是否不好。（打算一个用户一个进程，但是ets表不能放在
    %%各自的进程里，要放在总的一个进程里，放在各自进程的话，如果只放各自的
    %%person 会不好弄，都放的话要复制几个相同的）
    ets:new(person_info, [named_table, public, {keypos, #person.name}]),
    %%这里以后要定义一些宏，不要硬编码
    ets:insert(tab, #person{name=man_1, x=0, y=0, hp=100, mp=100, damage=10, direction=right}),
    ets:insert(tab, #person{name=man_2, x=20, y=20, hp=100, mp=100, damage=10, direction=left}),

    start().

start()->
    {ok, S} = gen_tcp:listen(10000, [list, {active, false}]),
    {ok, AccSock} = get_connect(S, 2, []),
    loop_for_every_one(AccSock),
    ok.

get_connect(Socket, 0, AccSock)-> {ok, AccSock};
get_connect(Socket, Num, AccSock)->
    case gen_tcp:accept(Socket) of
        {ok, SS} ->
            io:format("connect 1"),
            {ok, Res} = get_connect(Socket, Num-1, [SS | AccSock]);
        _ ->
            io:format("error in fun[get_connect]"),
            {ok, Res} = get_connect(Socket, Num, AccSock)
    end,
    {ok, Res}.

loop_for_every_one([]) -> ok;
loop_for_every_one([Sock|Rest]) ->
    spawn(?MODULE, loop, [Sock]),
    loop_for_every_one(Rest).


%%%%%%%%%%%%%%%%%%%%%%
%tcp 消息格式：
%% '{get_info}': 返回全部person数据
%% '{set,{name, direction, attack}, {name_2, ...}, ....};:
%%见record
%%%%%%%%%%%%%%%%%%%%%%
loop(Socket)->
    case gen_tcp:recv(Socket, 0) of
        {ok, Content} ->
            handle_set(Socket, Content),
            loop(Socket);
        _ ->
            io:format("error in fun[loop/1]"),
            exit('error_in_fun[loop/1]')
        end,
    ok.

%%处理'set'类请求
handle_set(Socket, Content) ->
    ok.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                       init----->start
%                                                 \ \ \
%                                                 / \  \
%                                                /  \   \
%                                              /    \    \
%                                             /      \     \
%                        进程              getinfo   set    operate(具体的操作)
%                                         (返回info)  \
%                                                   (接受玩家的操作信息,并保存到ets)
