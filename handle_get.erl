-module(handle_get).
-export([loop_for_get_info/1]).
-import(utils, [util_get_info/0]).



loop_for_get_info(Sockets) ->
    sub_loop_for_get_info(Sockets, Sockets).

sub_loop_for_get_info([], All)->
    sub_loop_for_get_info(All, All);
sub_loop_for_get_info([Socket|Rest], All) ->
    %% 0.1s wait
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
