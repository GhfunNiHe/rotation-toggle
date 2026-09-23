# Plasma Screen Auto-Rotation Toggle

Plasma 6 系统托盘插件，切换屏幕自动旋转开关。纯 QML，无需编译。

## 原理

```
点击托盘图标 → doToggle()
  → kscreen-doctor output.<输出>.autoRotatePolicy.always|never          # 切换
  → dbus-send ... org.kde.plasmashell /org/kde/osdService \
      org.kde.osdService.showText <icon> <text>                        # OSD
状态刷新 → 每 3 秒执行 kscreen-doctor -j，解析 JSON 里的 autoRotatePolicy
```

- **开** → `Always` — KDE 始终自动旋转
- **关** → `Never` — 锁定当前方向

旋转由 KScreen / iio-sensor-proxy 原生处理，插件不做自定义旋转，也不碰旋转方向。

## 文件结构

```
rotation-toggle/
├── org.kde.plasma.rotation-toggle/            # 插件包（可直接拷贝安装）
│   ├── metadata.json
│   └── contents/
│       ├── config/main.xml
│       ├── ui/main.qml                        # 全部逻辑
│       └── locale/zh_CN/LC_MESSAGES/
│           └── plasma_applet_org.kde.plasma.rotation-toggle.mo
├── po/zh_CN.po                                # 翻译源文件
└── rotation-toggle.plasmoid                   # 打包产物
```

## 依赖

- KDE Plasma 6.0+
- `kscreen-doctor`（由 libkscreen 提供，Plasma 桌面自带）
- `dbus-send`（dbus-tools）

## 安装

> 仓库只放源码：`.mo` 和 `.plasmoid` 是构建产物（已被 .gitignore 忽略），
> 克隆后先按「翻译」「打包」两节生成，或直接用下面的方式一安装（中文界面需要先编译 .mo）。

```bash
# 方式一：直接拷贝目录
cp -r org.kde.plasma.rotation-toggle ~/.local/share/plasma/plasmoids/

# 方式二：安装打包产物
kpackagetool6 -t Plasma/Applet -i rotation-toggle.plasmoid

# 重载
systemctl --user restart plasma-plasmashell.service
```

## 打包

```bash
cd org.kde.plasma.rotation-toggle
zip -r ../rotation-toggle.plasmoid metadata.json contents
```

## 翻译

英文是源语言，直接写在 `contents/ui/main.qml` 的 `i18n()` / `i18nc()` 里。
翻译域由 plasmashell 决定，固定为 `plasma_applet_<pluginId>`，文件放在插件包内的
`contents/locale/<lang>/LC_MESSAGES/` 下即可（实测 plasmashell 会读这个路径，
不需要装到 `~/.local/share/locale`）。

```bash
# 改完 po 后重新编译
msgfmt -o org.kde.plasma.rotation-toggle/contents/locale/zh_CN/LC_MESSAGES/\
plasma_applet_org.kde.plasma.rotation-toggle.mo po/zh_CN.po
```

新增语言：同法生成 `contents/locale/<lang>/LC_MESSAGES/plasma_applet_<同一域名>.mo`。

## 注意事项

- OSD 的 D-Bus 目标不是 `org.kde.osdService`（会话总线上没有这个名字），而是
  `org.kde.plasmashell` 的 `/org/kde/osdService`，签名 `showText(in s icon, in s text)`。
- `kscreen-doctor` 的取值是 `never` / `inTabletMode` / `always`；`in-tablet-mode`
  是尚未发布的 `kscreenctl` 的写法，不要混用。
- OSD 文案含空格时必须把整个 `string:...` 参数用双引号包住，否则会被 QML 的 exec
  引擎按空格拆成多个参数，`dbus-send` 失败、OSD 不显示。
- 插件只操作 `type == 7`（Panel）的输出，找不到时显示为不支持状态。

## 许可

MIT License，见 [LICENSE](LICENSE)。
