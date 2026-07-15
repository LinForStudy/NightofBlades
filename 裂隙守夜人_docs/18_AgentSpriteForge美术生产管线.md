# Agent Sprite Forge 美术生产管线

## 1. 定位

`agent-sprite-forge` 在本项目中负责生成和整理可供 Godot 使用的 2D 美术资源，不负责代替战斗逻辑、AI、数值和关卡代码。

它主要承担：

- 主角、敌人、Boss 的像素动画帧
- 技能施法、弹道、命中、爆炸等特效
- 武器、道具、图标和场景道具
- 战斗地图、分层地图和 Godot 可编辑地图资源
- 透明背景清理、切帧、对齐、GIF预览和质量检查

Codex 负责：

- 调用技能并组织资产批次
- 检查生成结果
- 把合格资源复制到项目目录
- 创建 SpriteFrames、AnimatedSprite2D 和 AnimationPlayer
- 配置碰撞、攻击帧、锚点和动画事件
- 在 Godot 中运行验证

## 2. 安装位置

Windows 下将仓库的 `skills` 内容复制到：

```text
%USERPROFILE%\.codex\skills\
```

安装完成后必须新建 Codex 会话，使技能重新加载。

项目仓库中不要复制完整技能源码，只保留：

```text
tools/
  agent_sprite_forge/
    README.md
    asset_manifest.json
    prompts/
```

真正的 Codex 技能仍安装在用户目录中。

## 3. 本项目使用的两个技能

### 3.1 `$generate2dsprite`

用于：

- 主角动作
- 敌人动作
- Boss动作
- 技能特效
- 投射物
- 命中特效
- 场景小道具
- UI技能图标

### 3.2 `$generate2dmap`

用于：

- 废弃村落战斗场景
- 远景、地面、前景分层
- 独立场景道具
- 平台和碰撞参考
- Godot可编辑地图场景

MVP阶段地图应先生成视觉参考和分层素材，再由 Codex 按战斗需要调整碰撞与平台，不能直接把一张完整背景图当作全部地形碰撞。

## 4. 资产目录规范

```text
assets/
  generated/
    _references/
    _raw/
    _review/
    characters/
      player/
        night_blade/
          idle/
          run/
          jump/
          attack_01/
          attack_02/
          attack_03/
          dodge/
          hurt/
          death/
          skills/
    enemies/
    bosses/
    skills/
      fire_wave/
      lightning_dash/
      blade_storm/
      ultimate_meteor_slash/
    environments/
      abandoned_village/
    props/
    ui/
      skill_icons/
  approved/
  rejected/
```

规则：

- 原始生成图保存在 `_raw`
- 清理和切帧后的候选资源保存在 `_review`
- 通过人工或Codex检查的资源进入 `approved`
- 不合格资源进入 `rejected`，不直接覆盖
- 游戏运行时只引用 `approved` 或正式资源目录

## 5. 统一风格规范

### 5.1 视角

- 横版侧视图
- 角色主要朝右生成
- Godot中通过 `flip_h` 处理向左
- 不为左右方向分别生成整套动作，除非角色服装明显不对称且翻转会出错

### 5.2 像素风格

- 16位主机感的精细像素风
- 清晰外轮廓
- 中高对比度
- 人物与背景色值分离
- 不使用写实渲染
- 不使用模糊抗锯齿边缘
- 不在角色身体帧中烘焙大范围发光背景

### 5.3 尺寸

建议处理后统一单帧尺寸：

- 主角：128×128 单元格，身体高度约64～80像素
- 普通敌人：96×96或128×128
- Boss：192×192或256×256
- 技能特效：128×128、192×192或256×256
- 技能图标：64×64

尺寸指最终统一帧画布，不代表角色必须铺满画布。

### 5.4 锚点

地面角色统一：

- `anchor=feet`
- 脚底Y轴保持一致
- 身体中心不横向漂移
- 同角色所有地面动作复用同一比例配置

空中动作：

- 使用中心或自定义锚点
- 不强行对齐脚底

## 6. 主角资产拆分原则

主角不能一次生成一张“包含所有动作的巨型图集”。

必须分别生成并检查：

1. idle
2. run
3. jump_start / jump_loop / fall
4. attack_01
5. attack_02
6. attack_03
7. air_attack
8. charge
9. charge_release
10. dodge
11. hurt
12. death
13. skill_fire_body
14. skill_dash_body
15. skill_spin_body
16. ultimate_body

每个动作通过检查后，再由脚本或 Codex 组装成 Godot SpriteFrames 或运行时图集。

## 7. 身体动画与特效分离

主角身体动作中默认不包含：

- 大型刀光
- 长距离剑气
- 爆炸
- 命中火花
- 雷电链
- 地面冲击波
- 大范围尘土

这些必须分别生成：

```text
player_attack_body
slash_arc_fx
impact_spark_fx
fire_wave_projectile
fire_wave_impact
lightning_dash_trail
blade_storm_blades
ultimate_ground_impact
```

Godot 中将身体动画和 FX 分层播放。

好处：

- 角色比例稳定
- 特效可独立缩放
- 可调整命中时机
- 可复用
- 技能升级时只替换特效，不必重画角色

## 8. 建议帧数

### 主角

- idle：4帧，2×2
- run：6帧，2×3
- jump：4帧，2×2
- attack_01：4帧，2×2
- attack_02：4帧，2×2
- attack_03：6帧，2×3
- dodge：4帧，2×2
- hurt：4帧，2×2
- death：8帧，2×4
- 技能施法：4～6帧
- 大招身体：8～12帧

### 敌人

MVP普通敌人先做：

- idle：4帧
- move：4～6帧
- attack：4～6帧
- hurt：2～4帧
- death：4～6帧

### 技能FX

- 弹道循环：4～6帧
- 命中爆炸：6～9帧
- 地面持续区：4～8帧循环
- 大招冲击：9～16帧

## 9. 资产批次顺序

不要一次生成全部美术。

### Batch A：风格锁定

只生成：

- 主角静态标准立绘/站立帧
- 基础杂兵静态帧
- 废弃村落视觉参考
- 烈焰剑气单帧概念
- 一组技能图标概念

目标：确认风格、轮廓、比例和色板。

### Batch B：主角基础动作

- idle
- run
- jump
- dodge
- hurt
- death

目标：建立主角比例配置和脚底锚点。

### Batch C：平A战斗

- attack_01 body
- attack_02 body
- attack_03 body
- 三组独立刀光FX
- 命中火花

### Batch D：第一批敌人

- 裂隙杂兵
- 弓箭手
- 自爆怪
- 飞行魔眼

### Batch E：主动技能

- 烈焰剑气：施法身体、剑气、命中、燃烧
- 雷影冲刺：身体、残影、雷电轨迹、命中
- 旋刃风暴：身体循环、旋刃、飞刃、吸附旋涡

### Batch F：地图

- 地面基底
- 远景
- 前景
- 平台条带
- 木箱、路灯、破屋、栅栏等独立道具
- 碰撞参考和预览

### Batch G：Boss与大招

核心玩法稳定后再制作。

## 10. 质量检查清单

每个动作必须检查：

- [ ] 每格角色身份一致
- [ ] 比例一致
- [ ] 脚底锚点稳定
- [ ] 没有身体被裁切
- [ ] 没有跨格像素
- [ ] 没有残留洋红背景
- [ ] 没有多余身体部件
- [ ] 武器数量正确
- [ ] 帧顺序可形成连续动作
- [ ] 向右朝向一致
- [ ] 透明边缘无明显洋红杂边
- [ ] Godot中关闭Filter后显示清晰

攻击动作额外检查：

- [ ] 前摇、命中、后摇清晰
- [ ] 有明确的攻击峰值帧
- [ ] 身体和武器不会突然缩小
- [ ] 大型刀光已与身体分离

## 11. Godot导入规则

Codex导入后必须：

- 关闭纹理Filter
- 关闭Mipmaps
- 使用无损压缩
- 创建SpriteFrames资源
- 设置每个动作FPS
- 非循环动画关闭Loop
- 统一脚底锚点
- 通过AnimationPlayer或帧事件控制Hitbox
- 不以整张SpriteSheet作为碰撞依据

## 12. 资产清单文件

项目应维护：

```text
assets/generated/asset_manifest.json
```

每条记录包含：

```json
{
  "asset_id": "player_night_blade_attack_01",
  "type": "player_action",
  "status": "approved",
  "source_skill": "generate2dsprite",
  "view": "side",
  "grid": "2x2",
  "frame_count": 4,
  "cell_size": 128,
  "anchor": "feet",
  "game_path": "res://assets/approved/characters/player/night_blade/attack_01/",
  "notes": "body only, slash FX separated"
}
```

## 13. 失败处理

出现以下情况必须重新生成，而不是勉强切帧：

- 角色在不同帧大小变化明显
- 武器或身体跨越单元格
- 同一动作中人物服装变化
- 动作方向错误
- 多出手臂、武器或头部
- 身体被大特效遮挡
- 背景不是纯色，无法稳定清理

后处理只负责确定性清理，不能修复角色设计漂移和动作逻辑错误。
