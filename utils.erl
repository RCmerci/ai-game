-module(utils).
-include("records_and_config.hrl").

-export([util_get_info/0, get_X_Y_in_control/6, get_X_Y_in_control/4]).
-export([test_util_get_info/0]).

-define(TEST, false).
%% ----------------------------------------------------------
%% 得到 EtsTableName ets table所有条目

util_get_info() when not(?TEST) ->
    FirstKey = ets:first(?ETS_TABLE_NAME),
    Res = ets:lookup(?ETS_TABLE_NAME, FirstKey),
    gather(Res, ?ETS_KEY_POS);
util_get_info() when ?TEST ->
    FirstKey = ets:first(testtable),
    Res = ets:lookup(testtable, FirstKey),
    gather(Res, ?ETS_KEY_POS).

test_util_get_info() ->
    ets:new(testtable, [named_table, {keypos, #person.name}]),
    ets:insert(testtable, #person{name=1, x=2, y=3}),
    ets:insert(testtable, #person{name=4, x=5, y=6}),
    ets:insert(testtable, #person{name=7, x=8 ,y=9}),
    ets:insert(testtable, #person{name=mmm, x=11, y=123}),
    util_get_info().


%% gather(Res) ->
%%     [{Key, _Value}|_Rest] = Res,
%%     NextKey = ets:next(?ETS_TABLE_NAME, Key),
%%     if
%%         NextKey == '$end_of_table' ->
%%             Res;
%%         true ->
%%             [NextRes] = ets:lookup(?ETS_TABLE_NAME, NextKey),
%%             gather([NextRes|Res])
%%    end.

gather(Res, ?ETS_KEY_POS) when not(?TEST) ->           %PosName == name.
    [First|_Rest] = Res,
    NextKey = ets:next(?ETS_TABLE_NAME, First#?RD_PERSON.?ETS_KEY_POS),
    if
        NextKey == '$end_of_table' ->
            Res;
        true ->
            [NextRes] = ets:lookup(?ETS_TABLE_NAME, NextKey),
            gather([NextRes|Res], ?ETS_KEY_POS)
    end;
gather(Res, name) when ?TEST ->
    [First|_Rest] = Res,
    NextKey = ets:next(testtable, First#person.name),
    if
        NextKey == '$end_of_table' ->
            Res;
        true ->
            [NextRes] = ets:lookup(testtable, NextKey),
            gather([NextRes|Res], name)
    end.


%% -----------------------------------------------------
%% 返回x，y坐标，并保持在范围里面

get_X_Y_in_control(X, Y, Direction, Step, MAX_X, MAX_Y) ->
    case Direction of
        left ->
            if
                X-Step < 0 -> {0, Y};
                true -> {X-Step, Y}
            end;
        right ->
            if
                X+Step > MAX_X -> {MAX_X, Y};
                true -> {X+Step, Y}
            end;
        up ->
            if
                Y+Step > MAX_Y -> {X, MAX_Y};
                true -> {X, Y+Step}
            end;
        down ->
            if
                Y-Step < 0 -> {X, 0};
                true -> {X, Y-Step}
            end
    end.
get_X_Y_in_control(X, Y, Direction, Step) ->
    get_X_Y_in_control(X, Y, Direction, Step, ?MAX_X, ?MAX_Y).
