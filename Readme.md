> 因为Caibiii目前比较忙，很难一个人进行维护，商量后觉得闭源很难进行长时间的维护，所以接下来会陆陆续续将部分代码开源，希望有代码能力可以一起参与这个项目，没有代码能力的服主可以提交issues来反馈测试分支碰到的bug，测试版本稳定后会合并到主分支。
> 新增测试版docker，docker使用方法请看wiki

## ## 7月修改介绍

- 使用树树子tank2.0和charger 2.0更换ai_tank_new和ai_charger_new

- AI_HardSI_new 被 AI_HardSI_2.0替代，主要用来匹配tank2.0版本，而且删除里面原有的charger，smoker，jockey控制

- tank传送稍微修改传送条件，获取flow失败的时候不进行检测

- ai_smoker_new更新，解决了射线刷特导致smoker刷到半空中成为斗宗强者的问题

- ai_boomer_new属性小幅调整，要不打不到人了，喷人的时候花洒式

- 刷特插件也修复了smoker传送导致的斗宗smoker问题，同时倒地的人视线不会影响特感传送时间累计

- 10特及以上增加AnneHappyPlus武器配置

- 适配ai_jockey_new到7月插件(5月有问题没有加载)

- 优化刷特，降低了对服务器的压力，要不然刷特服务器帧数太难看啦

## 修改介绍

当前测试分支在电信测试服测试过后，感觉没有很大问题，所以放到测试分支方便有兴趣的服主下载下来测试。

修改后的infected_control等插件源码在script文件夹里
特感行为插件名字更改为正确的名字，L4D2_TankThrow为AI_HardSI.smx，方便理解

目前已经用AI_HardSI_new.smx实现了L4D2_TankThrow和l4d2_asiai.smx两个插件功能，所以去掉这两个插件(暂时没删除)，增加了所有特感的加强插件。

### 新增插件介绍

#### l4d2_Anne_stuck_tank_teleport.smx(你可以删除，默认安装）

原来那个防卡tank和Anne搭配不好，借鉴infected_control和l4d_tankantistuck，写了这个版本tank防卡和跑男惩罚插件。

    ChangeLog:
    
    1.5
        修改tank传送可能被卡住的情况
    
    1.4
        救援关不启动rush传送，修改Tank流程检测.生还者进度超过98%的也不会传送（防止传送到安全门内）
    
    1.3 
        增加倒地被控玩家不进入检测
    
    1.2 
        增加tank流程检测
    
    1.1 
         修改tank传送逻辑
    
    1.0 
        版本发布

#### AI_HardSI_new.smx

在原版L4D2_TankThrow.smx基础上，增加了特感激进进攻的指令(来自 l4d2_asiai.ssp)，增加了跳砖，其余的两个插件相差不大，所以直接用这个插件替代原来那两个插件。

### 插件修改介绍

#### infected_control.smx

刷特插件稍作修改，修复了有时候会多刷一只特感的bug，并且减少了每服务器帧的刷特循环，降低服务器var值，刷特也变得更加分散，传送逻辑改变，不再是6s后没人看到就能传送，改为连续5s，每0.1s检测一次，都没被看到就能允许传送。

#### l4d_infected_movement.smx(spitter跳吐和boomer跳吐已经提供了关闭投票）

这个插件本来时tank的跳砖功能，但是跳砖已经继承到了ai_tank_new.smx插件中，就在这个插件上增加了Spitter跳吐的能力。

#### l4d_target_override

更新为最新版本，并修改了一些目标顺序。

#### Alone

单人装逼插件已经用新版刷特逻辑替代，并且继承了老版对smoker加伤，不刷boomer spitter等功能（但是刷特种类依旧是读取特感限制来刷，不过应该没影响）

#### l4d_target_override

更新到最新版本，多了一些目标可以选择，修改后的l4d_target_override.cfg在data文件内。

#### hunter

1vht插件也用新版刷特逻辑替代，并且1vht模式用了增强的hunter。

### 特感增强介绍

> 特感功能大部分都来自于[GitHub - GlowingTree880/L4D2_LittlePlugins: L4D2_LittlePlugins](https://github.com/GlowingTree880/L4D2_LittlePlugins)，感谢~~

#### Hunter

Hunter将优先选择拿机枪的玩家进行攻击，如果有墙面的时候优先选择弹墙，降低垂直高度限制(这会导致水平速度加快，你如果你用原来的，把这个从7改回原来的10)，低扑更加灵活。

#### Smoker

Smoker优先拉超前或者落单者，拉喷子效果一般。

#### Tank

Tank将连跳到选定生还者前TankAttack+50的距离停止连跳，增加检测绕树功能，被绕的情况下重新选取目标。增加了消耗克的投票。

#### Boomer

Boomer连跳速度加快，但是不会再有飞天炸了，应该算削了？update:可以空中吐，但是相比2-2应该还是算削了

#### Spitter

Spitter优先吐被控的人，其次时人密度最大的地方，且用l4d_infected_movement.smx增加了跳吐。

#### Jockey

改的不多，就在原版上增加了在必要时候锁定的功能

#### Charger

由原版的300血冲锋改为350，倒霉的人就用刀砍不死了，目标由l4d_target_overide选择。
有了这些增强，原来那个aichargerboomer插件也可以删除了

## 结语

如果由发现*Bug*希望能够提交issue，有好的想法实现了可以pull request到项目，好的想法会合并到分支里。如果发现源码的错误也希望提出并pull request，长久的维护离不开大家的努力~

## 重要提示

第一阶段测试插件基本完成，从2022年4月15日开始进行15-30天的测试时间，如果没有大bug将会合并分支到main分支。
