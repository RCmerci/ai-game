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
    {ok, SS} = gen_tcp:listen(10001, [list, {active, false}]),
    {ok, GetInfoSock} = get_connect(SS, 2, []),
    spawn(?MODULE, loop_for_get_info, [GetInfoSock]),
    ok.

get_connect(_Socket, 0, AccSock)-> {ok, AccSock};
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
    spawn(?MODULE, loop_for_set, [Sock]),
    loop_for_every_one(Rest).


loop_for_set(Socket)->
    case gen_tcp:recv(Socket, 0) of
        {ok, Content} ->
            handle_set(Socket, Content),
            loop_for_set(Socket);
        _ ->
            io:format("error in fun[loop/1]"),
            exit('error_in_fun[loop/1]')
        end,
    ok.

loop_for_get_info(Socket) ->
    sub_loop_for_get_info(Socket, Socket).

sub_loop_for_get_info([], All) ->
    sub_loop_for_get_info(All, All);
sub_loop_for_get_info([Socket|Rest], All) ->
    %% 0.2秒等待
    case gen_tcp:recv(Socket, 0, 200) of
        {ok, Content} ->
            handle_get(Socket, Content),
            sub_loop_for_get_info(Rest, All);
        {error, timeout} ->
            sub_loop_for_get_info(Rest, All)
    end.

%%%%%%%%%%%%%%%%%%%%%%
%tcp 消息格式：
%% '{get_info}': 返回全部person数据
%% '{set,{name, direction, attack}, {name_2, ...}, ....};:
%%见record
%%%%%%%%%%%%%%%%%%%%%%

%%处理'set'类请求
handle_set(Socket, Content) ->
    ContentList = handle_content(Content),
    [Set|RestList] = ContentList,
    if
        Set=="set" ->
            sub_handle_set(Socket,RestList);
        true ->
            io:format("set 类请求格式错误~n~p~n", [Content])
    end,
    ok.

%% 处理Content的内容,分割成list
handle_content(Content) ->
    InitList = string:tokens(Content, "{}"),
    lists:filter(fun(X)->length(string:strip(X))>1 end, InitList).

%% 真正处理set request的函数
sub_handle_set(Socket, ContentList) ->
    ok.                                         %明天写= =

%%处理‘get’类请求
handle_get(Socket, Content) ->
    if
        "{get_info}" == Content ->
            sub_handle_get(Socket),
            ok;
        true -> io:format("dont match ‘{get_info}’")
    end,
    ok.

sub_handle_get(Socket) ->
    Key = ets:first(person_info),
    Res = ets:lookup(person_info, Key),
    Result = lists:flatten(io_lib:format("~p", gather(Res))),
    gen_tcp:send(Socket, Result).


gather(Res) ->
    [Combine|_Rest] = Res,
    [Key|_] = Combine,
    AnotherKey = ets:next(person_info, Key),
    if
        AnotherKey == '$end_of_table' ->
            Res;
        true ->
            [AnotherRes] = ets:lookup(person_info, AnotherKey),
            gather([AnotherRes|Res])
    end.
%% 处理‘get’请求 (end)

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
