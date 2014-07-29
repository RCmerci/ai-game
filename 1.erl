-module('1').
-export([init/0]).
%%先把record写在这里，以后移到一个单独的hrl文件
-record(person, {name,
                 x,
                 y,
                 hp=100,
                 mp=100,
                 damage=10,
                 direction=right}).
%%初始化
init()->
    %%ets table的名字‘tab’不太好
    %%ets table放在这里是否不好。（打算一个用户一个进程，但是ets表不能放在
    %%各自的进程里，要放在总的一个进程里，放在各自进程的话，如果只放各自的
    %%person 会不好弄，都放的话要复制几个相同的）
    ets:new(tab, [named_table, {keypos, #person.name}]),
    %%这里以后要定义一些宏，不要硬编码
    ets:insert(tab, #person{name=man_1, x=0, y=0, hp=100, mp=100, damage=10, direction=right}),
    ets:insert(tab, #person{name=man_2, x=20, y=20, hp=100, mp=100, damage=10, direction=left}),
    ok.
