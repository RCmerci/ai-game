-module(utils).
-export([util_get_info/1]).

-export([test_util_get_info/0]).


%% 得到 EtsTableName ets table所有条目
util_get_info(EtsTableName) ->
    FirstKey = ets:first(EtsTableName),
    Res = ets:lookup(EtsTableName, FirstKey),
    gather(Res, EtsTableName).

util_get_info(EtsTableName, PosName) ->
    FirstKey = ets:first(EtsTableName),
    Res = ets:lookup(EtsTableName, FirstKey),
    gather(Res, EtsTableName, PosName).

test_util_get_info() ->
    ets:new(testtable, [named_table]),
    ets:insert(testtable,{1,2,3}),
    ets:insert(testtable, {2,sss}),
    ets:insert(testtable, {1,aaa}),
    ets:insert(testtable, {[1,2], 22,ee}),
    util_get_info(testtable).


gather(Res, EtsTableName) ->
    [{Key, _Value}|_Rest] = Res,
    NextKey = ets:next(EtsTableName, Key),
    if
        NextKey == '$end_of_table' ->
            Res;
        true ->
            [NextRes] = ets:lookup(EtsTableName, NextKey),
            gather([NextRes|Res], EtsTableName)
    end.

gath
