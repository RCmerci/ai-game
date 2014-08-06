-module(operate).
-include("records_and_config.hrl").
-export([operate_receiver/0]).
-export([test_check_and_return_result/0]).
-import(utils, [util_get_info/0,
                get_X_Y_in_control/4,
                get_X_Y_in_control/6,
                get_item_by_keypos/1]).
-define(TEST, false).
%% [name, direction, attack]
%% 这里name，direction，attack都是string
operate_receiver() ->
    receive
        Set_info ->
            operate(Set_info),
            operate_receiver()
    end.


operate([Name, Direction, Attack])->
    DirectionAtom = direction_string_to_atom(Direction),
    ets:update_element(?ETS_TABLE_NAME,
                       Name,
                       {8, DirectionAtom}),
    {Res_X, Res_Y} = check_and_return_result([Name, DirectionAtom, Attack]),
    ets:update_element(?ETS_TABLE_NAME,
                       Name,
                       {3, Res_X}),
    ets:update_element(?ETS_TABLE_NAME,
                       Name,
                       {4, Res_Y}).


check_and_return_result([Name, Direction, Attack]) ->
    Aim = get_item_by_keypos(Name),
    {X, Y} = get_X_Y_in_control(Aim#?RD_PERSON.x,
                                Aim#?RD_PERSON.y,
                                Direction,
                                1),
    case check_and_return_result(X, Y, util_get_info()) of
        true ->
            {X, Y};
        false ->
            {Aim#?RD_PERSON.x, Aim#?RD_PERSON.y}
    end.

check_and_return_result(_, _, []) ->true;
check_and_return_result(X, Y, All) ->
    Lambda = fun(Other_X, Other_Y) ->
                     if
                         (Other_X == X) and (Other_Y == Y) ->false;
                         true ->true
                     end end,
    [First|Rest] = All,
    Other_X = First#?RD_PERSON.x,
    Other_Y = First#?RD_PERSON.y,
    case Lambda(Other_X,Other_Y) of
        false -> false;
        true -> check_and_return_result(X, Y, Rest)
    end.
test_check_and_return_result() ->
    ets:new(tttt, [named_table]),
    ets:insert(ttt, #?RD_PERSON{name=name1,
                               x=2,
                                y=2}),
    ets:insert(ttt, #?RD_PERSON{name=name2,
                                x=2,
                                y=2}),
    Res = check_and_return_result(2,2,util_get_info()),
    case Res of
        true ->
            io:format("test_check_and_return_result failed");
        false ->
            io:format("test_check_and_return_result success")
    end.



direction_string_to_atom("left") -> left;
direction_string_to_atom("right") -> right;
direction_string_to_atom("up") -> up;
direction_string_to_atom("down") -> down;
direction_string_to_atom(_) -> left.
