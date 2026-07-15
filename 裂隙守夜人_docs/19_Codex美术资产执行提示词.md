# Codex 美术资产执行提示词

## 1. 安装检查提示词

```text
请检查本机 Codex 技能目录中是否已经正确安装 agent-sprite-forge。

目标技能：
- $generate2dsprite
- $generate2dmap

请执行以下检查：
1. 检查 %USERPROFILE%\.codex\skills\generate2dsprite\SKILL.md
2. 检查 %USERPROFILE%\.codex\skills\generate2dmap\SKILL.md
3. 检查 Python 是否可用
4. 检查 numpy 和 Pillow 是否已安装
5. 不要生成任何正式资产，只报告检查结果

若技能不存在，请按仓库说明安装；安装后提醒我新建 Codex 会话，不要在当前未重载技能的会话中假装技能可用。
```

## 2. Batch A：视觉风格锁定

```text
请阅读：
- docs/09_美术与动画制作规范.md
- docs/18_AgentSpriteForge美术生产管线.md

本次只执行美术 Batch A：视觉风格锁定，不接入正式战斗代码。

使用 $generate2dsprite 和 $generate2dmap 生成以下候选资产：

1. 主角“守夜刀客”的侧视标准站立形象
2. 基础敌人“裂隙杂兵”的侧视标准形象
3. 第一张地图“废弃村落”的横版战斗场景视觉参考
4. 技能“烈焰剑气”的弹道和命中概念
5. 3个技能图标概念：烈焰剑气、雷影冲刺、旋刃风暴

统一风格：
- 原创16位精细像素风
- 横版侧视
- 暗色奇幻世界
- 主角轮廓清晰，深色服装配暖色围巾或披风
- 角色与背景有明显明度区分
- 不模仿现有商业游戏角色
- 不生成任何文字或Logo

要求：
- 主角和敌人先生成单体标准帧，不生成完整动作合集
- 地图只作为风格参考，不直接当作最终碰撞地图
- 原始图、透明清理图、预览图和元数据分别保存
- 输出到 assets/generated/_review/batch_a_style_lock/
- 生成 asset_manifest 候选记录
- 不覆盖已有资源

完成后：
- 展示所有候选资源路径
- 说明每张资源是否通过比例、轮廓、色板和透明背景检查
- 不合格的放入 rejected，不得接入项目
- 不要继续生成 Batch B
```

## 3. Batch B：主角基础动作

```text
请阅读 docs/18_AgentSpriteForge美术生产管线.md。

使用已经批准的主角标准帧作为身份和比例参考，调用 $generate2dsprite 生成主角基础动作。

动作：
- idle：4帧，2x2
- run：6帧，2x3
- jump：4帧，2x2
- dodge：4帧，2x2
- hurt：4帧，2x2
- death：8帧，2x4

关键规则：
- 横版侧视，全部朝右
- 主体身份、服装、武器、色板与批准标准帧一致
- 地面动作使用feet锚点
- 同一角色所有地面动作复用统一比例
- 身体保持在每格中央安全区
- 不允许身体、头发、披风、武器跨格
- 身体动作中不加入大型刀光、冲击波或尘土
- 背景使用处理流程要求的纯色背景
- 每个动作独立生成、独立质检，不生成混合动作巨型图集

输出：
assets/generated/_review/characters/player/night_blade/

完成后：
1. 生成透明帧
2. 生成GIF预览
3. 输出QC元数据
4. 建立统一scale profile
5. 只把通过检查的动作复制到approved
6. 更新asset_manifest.json
7. 暂时不要接入战斗逻辑
```

## 4. Batch C：三段平A动作与特效

```text
使用批准的主角标准帧、基础动作和scale profile，调用 $generate2dsprite 生成三段普通攻击。

身体动作：
- attack_01：快速横斩，4帧，2x2
- attack_02：向前踏步反向斩，4帧，2x2
- attack_03：重型上挑或终结斩，6帧，2x3

身体动作要求：
- body-only为默认
- 武器可以随动作移动，但不要加入脱离身体的大型刀光
- 身体高度与idle/run接近
- 脚底锚点稳定
- 三段动作必须能读出前摇、命中峰值和后摇

另外分别生成：
- slash_arc_01：短而快
- slash_arc_02：反向中型刀光
- slash_arc_03：大范围重击刀光
- hit_spark_small：普通命中火花
- hit_spark_heavy：重击命中火花

特效作为独立fx/impact资产，透明背景，允许component_mode=all。

输出到：
assets/generated/_review/characters/player/night_blade/attacks/
assets/generated/_review/skills/common_melee_fx/

质检通过后：
- 创建或更新Godot SpriteFrames资源
- 身体动画与刀光FX分层
- 攻击有效帧通过AnimationPlayer事件开启Hitbox
- 在测试木桩场景中验证三段攻击
- 保存运行截图
```

## 5. Batch D：第一批敌人

```text
调用 $generate2dsprite 生成第一批四种敌人的动作资源：

1. 裂隙杂兵
2. 弓箭手
3. 自爆怪
4. 飞行魔眼

每种敌人至少包含：
- idle
- move
- attack
- hurt
- death

原则：
- 每个动作独立生成
- 低价值普通敌人可使用较少帧数
- 所有敌人保持横版侧视和同一世界风格
- 自爆怪额外生成预警闪烁和爆炸FX
- 弓箭手箭矢与命中FX独立生成
- 飞行魔眼使用center或bottom锚点，不使用feet
- 不要一次把四种敌人塞进一个动画图集

完成后导入Godot敌人场景，但不要修改AI规则，只替换视觉资源并验证动画映射。
```

## 6. Batch E：主动技能资产

```text
调用 $generate2dsprite 为三个主动技能生成完整视觉资产包。

技能一：烈焰剑气
- player_cast_body
- fire_wave_projectile_loop
- fire_wave_impact
- burning_loop
- inferno_explosion
- giant_fire_blade

技能二：雷影冲刺
- player_dash_body
- lightning_afterimage
- lightning_trail
- chain_lightning
- lightning_hit

技能三：旋刃风暴
- player_spin_body_loop
- spin_slash_ring
- flying_blade
- vacuum_swirl
- final_burst

要求：
- 主角身体动作复用已批准身份和scale profile
- 大范围效果必须与身体分离
- 投射物、命中、持续区域分别生成
- 视觉上能够区分基础形态、A分支和B分支
- 特效透明、无文字、无完整场景背景
- 在Godot中使用独立AnimatedSprite2D或GPUParticles2D组合
- 不将完整技能做成一段不可控制的视频或单张大图

完成后逐个技能在测试场景中验证：
- 朝向
- 锚点
- 动画循环
- 攻击范围
- 升级后替换或叠加效果
- 性能
```

## 7. Batch F：废弃村落地图

```text
请使用 $generate2dmap 创建“废弃村落”横版战斗地图资产。

地图不是俯视RPG地图，而是固定横版侧视竞技场。

目标：
- 设计分辨率1280x720
- 世界宽度约2800像素
- 可重复战斗的横版竞技场
- 中央主战区
- 左右出生区
- 2到3组高低平台
- 远景、地面、前景分层
- 暗色奇幻废弃村落

输出拆分：
- background_far
- background_mid
- ground_base
- foreground
- platform strip：left/middle/right
- 独立道具：木箱、破损栅栏、路灯、稻草、破屋、石块
- 场景预览
- 碰撞和出生点参考元数据

规则：
- 平台、地面、长墙不得塞入普通3x3小道具包
- 可重复平台使用条带或自定义宽单元格
- 大型房屋等重要道具单独生成
- 地图美术不能直接决定最终碰撞
- Codex必须在Godot中建立独立StaticBody2D和平台碰撞
- 角色必须能够在高物件前后正确排序时，使用独立Sprite2D道具

完成后创建Godot战场场景，并添加调试玩家验证：
- 地面碰撞
- 平台跳跃
- 摄像机边界
- 敌人出生位置
- 前后景层级
```

## 8. 每次美术任务固定汇报格式

```text
### 本次资产批次

### 使用的Skill与模式

### 生成资产清单

### 原始文件路径

### 清理后文件路径

### QC结果

### 已批准资产

### 被拒绝资产及原因

### Godot导入结果

### 运行测试结果

### 截图与GIF路径

### asset_manifest更新

### 下一批次建议
```
