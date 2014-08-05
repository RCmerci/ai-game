-module('1').
-export([init/0]).
-export([test/0,
         test_get/0,
         test_set/0]).
-export([loop_for_set/1,
         loop_for_get_info/1,
         handle_content/1]).
-include("records_and_config.hrl").
-define(TEST, true).
-import(utils, [util_get_info/0,
                get_X_Y_in_control/4,
                get_X_Y_in_control/6]).
%%初始化
init()->
    %%ets table放在这里是否不好。（打算一个用户一个进程，但是ets表不能放在
    %%各自的进程里，要放在总的一个进程里，放在各自进程的话，如果只放各自的
    %%?RD_PERSON 会不好弄，都放的话要复制几个相同的）
    ets:new(?ETS_TABLE_NAME, [named_table, public, {keypos, #?RD_PERSON.?ETS_KEY_POS}]),
    %%这里以后要定义一些宏，不要硬编码
    ets:insert(?ETS_TABLE_NAME, #?RD_PERSON{name="man_1", x=0, y=0, hp=100, mp=100, damage=10, direction="right"}),
    ets:insert(?ETS_TABLE_NAME, #?RD_PERSON{name="man_2", x=20, y=20, hp=100, mp=100, damage=10, direction="left"}),

    start().

start()->
    {ok, S} = gen_tcp:listen(10000, [list, {active, false}]),
    {ok, AccSock} = get_connect(S, 2, []),
    loop_for_every_one(AccSock),
    {ok, SS} = gen_tcp:listen(10001, [list, {active, false}]),
    {ok, GetInfoSock} = get_connect(SS, 2, []),
    spawn(?MODULE, loop_for_get_info, [GetInfoSock]),
    timer:sleep(infinity).

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
        A ->
            io:format("error in fun[loop/1],content:~p~n", [A]),
            exit('error_in_fun[loop/1]')
        end,
    ok.

loop_for_get_info(Socket) ->
    sub_loop_for_get_info(Socket, Socket).

sub_loop_for_get_info([], All) ->
    sub_loop_for_get_info(All, All);
sub_loop_for_get_info([Socket|Rest], All) ->
    %% 0.1秒等待
    case gen_tcp:recv(Socket, 0, 100) of
        {ok, Content} ->
            handle_get(Socket, Content),
            sub_loop_for_get_info(Rest, All);
        {error, timeout} ->
            io:format("timeout in line:~p~n", [?LINE]),
            sub_loop_for_get_info(Rest, All);
        A ->
            io:format("in line:~p,content:~p~n", [?LINE, A]),
            exit("{error 1}")
    end.

%%%%%%%%%%%%%%%%%%%%%%
%tcp 消息格式：
%% '{get_info}': 返回全部?RD_PERSON数据
%% '{set,{name, direction, attack}, {name_2, ...}, ....};:
%%见record
%%%%%%%%%%%%%%%%%%%%%%

%% +-----------------------------------------------------------+
%% |handle_set------------+                                    |
%% |      |               |                                    |
%% |      |           handle_content                           |
%% |      |               |                                    |
%% |sub_handle_set -------+                                    |
%% |      |                                                    |
%% |      |                                                    |
%% |      |                                                    |
%% |operation_on_ets                                           |
%% |      |                                                    |
%% |      |                                                    |
%% |      |                                                    |
%% |sub_operation_on_ets                                       |
%% |                                                           |
%% |                                                           |
%% |                                                           |
%% +-----------------------------------------------------------+

%%处理'set'类请求
handle_set(Socket, Content) ->
    ContentList = handle_content(Content),
    [Set|RestList] = ContentList,
    if
        Set=="set" ->
            sub_handle_set(Socket,RestList);
        true ->
            io:format("set format wrong,~n~p~n", [Content])
    end,
    ok.

%% 处理Content的内容,分割成list
handle_content(Content) ->
    InitList = string:tokens(Content, "{}"),
    lists:filter(fun(X)->length(X)>1 end, lists:map(fun(X)-> string:strip(string:strip(string:strip(X),both,$,)) end, InitList)).


%% ContentList 形如 ["name,direction,att", "name2,direction2,att2"]
sub_handle_set(Socket, []) -> ok;
sub_handle_set(Socket, ContentList) ->
    [First|Rest] = ContentList,
    FirstList = string:tokens(First, ","),
    ListToBeOperate = lists:map(fun(X)->string:strip(X) end, FirstList),
    operation_on_ets(ListToBeOperate),
    sub_handle_set(Socket, Rest).

%% 真正处理set request的函数
%% [name, direction, att]
operation_on_ets(ListToBeOperate)->
    case ListToBeOperate of
        [Name, Direction, Attack] ->
            QueryResult = ets:lookup(?ETS_TABLE_NAME, Name),
            case QueryResult of
                [A] ->
                    sub_operation_on_ets(A, Direction, Attack);
                [] ->
                    io:format("no result match~n");
                _ ->
                    io:format("no result match_2~n")
            end;
        _ ->
            io:format("in line ~p~n", [?LINE])
    end.

%% 先随便写一下
sub_operation_on_ets(QueryResult, Direction, Attack) ->
    CurrentInfo = util_get_info(),
    case Direction of
        "left" ->
            DirectionAtom = left;
        "right" ->
            DirectionAtom = right;
        "up" ->
            DirectionAtom = up;
        "down" ->
            DirectionAtom = down;
        _ ->
            io:format("wrong direction ~p~n", [?LINE]),
            DirectionAtom = left
    end,
    ets:update_element(?ETS_TABLE_NAME,
                       QueryResult#?RD_PERSON.?ETS_KEY_POS,
                       {8, Direction}),
    {RES_X, RES_Y} =  get_X_Y_in_control(QueryResult#?RD_PERSON.x,
                                         QueryResult#?RD_PERSON.y,
                                         DirectionAtom,
                                         1),
    ets:update_element(?ETS_TABLE_NAME,
                       QueryResult#?RD_PERSON.?ETS_KEY_POS,
                       {3, RES_X}),
    ets:update_element(?ETS_TABLE_NAME,
                       QueryResult#?RD_PERSON.?ETS_KEY_POS,
                       {4, RES_Y}),
    %% Attack 还没处理
    ok.



%% ========================================================================
%%处理‘get’类请求
handle_get(Socket, Content) ->
    if
        "{get_info}" == Content ->
            sub_handle_get(Socket);
        true -> io:format("dont match ‘{get_info}’")
    end,
    ok.

sub_handle_get(Socket) ->
    Result = lists:flatten(io_lib:format("~p", [util_get_info()])),
    gen_tcp:send(Socket, Result).


%% 处理‘get’请求 (end)


test()->
    spawn(?MODULE, init, []),
    timer:sleep(1000),
    %% spawn(?MODULE, test_set, []),
    %% timer:sleep(1000),
    %% spawn(?MODULE, test_get, []),
    ok.

test_set() ->
    {ok, S1} = gen_tcp:connect({127,0,0,1}, 10000, [list, {packet,0},{active, false}]),
    timer:sleep(500),
    {ok, S2} = gen_tcp:connect({127,0,0,1}, 10000, [list,{packet,0},{active,false}]),
    gen_tcp:send(S2, "{set,{man_2, down, false}}"),
    ok.


test_get() ->
    {ok, S1} = gen_tcp:connect({127, 0, 0, 1}, 10001, [list, {packet, 0}, {active, false}]),
    timer:sleep(500),
    {ok, S2} = gen_tcp:connect({127, 0, 0, 1}, 10001, [list, {packet, 0}, {active, false}]),
    gen_tcp:send(S1, "{get_info}"),
    Result = gen_tcp:recv(S1, 0, 5000),
    io:format("get_info:~p~n", [Result]),
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
