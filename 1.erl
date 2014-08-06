-module('1').
-export([init/0]).
-export([test/0,
         test_get/0,
         test_set/0,
         sub_test_set/1]).
-include("records_and_config.hrl").
-define(TEST, true).
-import(utils, [util_get_info/0,
                get_X_Y_in_control/4,
                get_X_Y_in_control/6]).
-import(handle_get, [loop_for_get_info/1]).
-import(handle_set, [loop_for_set/1]).
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
    {ok, S} = gen_tcp:listen(10000, [list, {active, false}]), %S for set
    {ok, AccSock} = get_connect(S, 2, []),
    loop_for_set(AccSock),
    {ok, SS} = gen_tcp:listen(10001, [list, {active, false}]), %SS for get
    {ok, GetInfoSock} = get_connect(SS, 2, []),
    spawn(handle_get, loop_for_get_info, [GetInfoSock]),
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

%% ------------------------test----------------------------------

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
    timer:sleep(1000),
    spawn(?MODULE, sub_test_set, [S2]),
    ok.

sub_test_set(S) ->
    gen_tcp:send(S, "{set,{man_2, down, false}}").


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
