-module(handle_set).
-export([loop_for_set/1]).
-export([sub_loop_for_set/1]).
-include("records_and_config.hrl").
-import(utils, [util_get_info/0,
                get_X_Y_in_control/4,
                get_X_Y_in_control/6,
                get_item_by_keypos/1]).


loop_for_set([]) -> ok;
loop_for_set([Sock|Rest]) ->
    spawn(?MODULE, sub_loop_for_set, [Sock]),
    loop_for_set(Rest).


sub_loop_for_set(Socket)->
    case gen_tcp:recv(Socket, 0) of
        {ok, Content} ->
            handle_set(Socket, Content),
            sub_loop_for_set(Socket);
        A ->
            io:format("error in fun[loop/1],content:~p~n", [A]),
            exit('error_in_fun[loop/1]')
    end,
    ok.

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

%% 处理set request的函数
%% [name, direction, att]
operation_on_ets(ListToBeOperate)->
    case ListToBeOperate of
        [Name, _Direction, _Attack] ->
            QueryResult = get_item_by_keypos(Name),
            case [QueryResult] of
                [_A] ->
                    operate_receiver ! ListToBeOperate;
                [] ->
                    io:format("no result match~n");
                _ ->
                    io:format("no result match_2~n")
            end;
        _ ->
            io:format("in line ~p~n", [?LINE])
    end.


%% sub_operation_on_ets(ListToBeOperate) ->
%%     DirectionAtom = direction_string_to_atom(Direction),
%%     ets:update_element(?ETS_TABLE_NAME,
%%                        QueryResult#?RD_PERSON.?ETS_KEY_POS,
%%                        {8, Direction}),
%%     {RES_X, RES_Y} =  get_X_Y_in_control(QueryResult#?RD_PERSON.x,
%%                                          QueryResult#?RD_PERSON.y,
%%                                          DirectionAtom,
%%                                          1),
%%     ets:update_element(?ETS_TABLE_NAME,
%%                        QueryResult#?RD_PERSON.?ETS_KEY_POS,
%%                        {3, RES_X}),
%%     ets:update_element(?ETS_TABLE_NAME,
%%                        QueryResult#?RD_PERSON.?ETS_KEY_POS,
%%                        {4, RES_Y}),
%%     %% Attack 还没处理
%%     ok.
