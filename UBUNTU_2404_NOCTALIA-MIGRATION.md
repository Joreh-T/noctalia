# Noctalia v5 适配记录

**日期**: 2026-08-13
**环境**: Ubuntu 24.04.4 LTS · niri 26.04 · 笔记本 Yoga + 外接 2560×1440

---

## 一、背景与目标

- **Noctalia 作为桌面 shell 优势**: 原生 C++/Wayland,无 Qt/Gtk 依赖,目标是 niri 一等公民,一体化提供 bar/启动器/通知/锁屏/剪贴板/壁纸/托盘。

---

## 二、关键难点与解法(都踩过坑)

### 1. 构建依赖缺 wireplumber-0.5 ❌→ 补丁降级到 0.4 ✅
- Noctalia v5 构建需要 `wireplumber-0.5` 头文件,Ubuntu 24.04 只有 `wireplumber-0.4`。
- **解法**: 改 `meson.build` 用 `wireplumber-0.4`;`wireplumber_mixer.cpp` 里 3 处 0.5→0.4 API 差异(`wp_core_new` 少一个参数、`wp_core_load_component` 变同步、移除 `_finish`)。

### 2. 缺 `stb_image_resize2.h` ❌→ 仓库内 vendored ✅
- 24.04 的 `libstb-dev` 没有这个新头文件,meson 配置阶段报错。
- **解法**: 从 stb v2.18 把单个头文件 vendor 到 `~/src/noctalia/stb/`,并把 meson 检查指向它。

### 3. 需要 GCC 14 的 `<print>` ❌→ 装 `g++-14` ✅
- 系统默认 gcc-13 无 `<print>`(C++23)。
- **解法**: `apt install g++-14`——它是版本化命令,**不接管默认 gcc-13**,不影响系统其他部分。

### 4. 需要 sdbus-c++ v2 ❌→ 源码构建到隔离前缀 ✅
- Noctalia 用 sdbus-c++ **v2** API(296 处调用),24.04 只有 v1.4.0。
- **解法**: 从源码构建 sdbus-c++ **v2.3.1**,装到隔离前缀 `~/noctalia-deps`(soname `.so.2`,与系统 v1 `.so.1` 不冲突)。Noctalia 通过 RPATH 链接到它,系统其他程序不受影响。

### 5. 需要 libwayland ≥ 1.23 的 `wl_proxy_get_display` ❌→ 补丁单点调用 ✅
- 24.04 的 libwayland 是 1.22,缺这个 API。全树只有 `virtual_keyboard_service.cpp:95` 用了它。
- **解法**: 给 `VirtualKeyboardService` 加 `wl_display*` 成员,由 `bind()` 传入,直接 `wl_display_flush(m_display)`——行为等价。**审查中发现第一版有 bug**(`cleanup()` 把 m_display 置空),修复后复审通过。

### 6. niri spawn 找不到 `noctalia` ❌→ `environment {}` 加 PATH ✅
- **根因**: niri 进程从登录管理器继承 PATH,**不含 `~/.local/bin`**,所以 `spawn "noctalia"` 静默失败(快捷键全无响应)。
- **解法**: `config.kdl` 顶部加 `environment { PATH "..." }`,把 `~/.local/bin` 加进 niri 的 PATH。这是**系统性调试**定位的根因。

### 7. 重启后 waybar 又出现 ❌→ mask systemd 服务 ✅
- **根因**: `/usr/lib/systemd/user/waybar.service` 被发行版预设为 enabled,`WantedBy=graphical-session.target`,每个图形会话自动启动,绕过 niri config。
- **解法**: `systemctl --user mask waybar.service`(创建指向 /dev/null 的链接,彻底阻止自启,可逆)。**对 GNOME 无影响**(GNOME 不用 waybar)。

### 8. 登录弹 "Disconnected Network" 通知 ❌→ 禁用 nm-applet autostart ✅
- **根因**: `nm-applet`(NetworkManager 托盘)通过 `/etc/xdg/autostart/nm-applet.desktop` 自启,登录瞬间网络未就绪误报通知。**不是 Noctalia 发的**。
- **解法**: 在 `~/.config/autostart/nm-applet.desktop` 放用户级覆盖(`Hidden=true`),禁用其自启。GNOME 自带网络指示器,不需要 nm-applet,**对 GNOME 无影响**。

---

## 三、最终配置清单

### niri —— `~/.config/niri/config.kdl`
- `environment { PATH }`: 加 `~/.local/bin`,让 spawn 能找到 noctalia
- 三屏输出:
  - `eDP-1`(内置 2880×1800)→ scale 1.75
  - `DP-1`(USB-C 外接 2560×1440)→ scale 1
  - `DP-2`(坞 HDMI 外接 2560×1440)→ scale 1
- spawn-at-startup: 仅 `noctalia`(绝对路径)+ dbus 环境更新
- 快捷键: `Mod+Space`/`Mod+D` → Noctalia 启动器;`Super+Alt+L` → Noctalia 锁屏
- 原有: 圆角、阴影、动画、prefer-no-csd、gaps 10

### Noctalia —— `~/.config/noctalia/config.toml`
- 主题: `builtin = "Noctalia"`(默认配色,用户选择保持)
- bar: thickness 44, widget_spacing 10, scale 1.3(图标调大)

### 隔离工具链(不污染系统)
- `~/noctalia-deps/`: sdbus-c++ v2.3.1 隔离安装(头文件+libs+pkg-config)
- `~/.local/bin/noctalia`: 编译产物(27MB)

---

## 四、后续更新上游版本

源码仓库(`~/workspaces/window_mananger_ui/noctalia`)的兼容补丁在分支 **`ubuntu-24.04`**
(基于上游 `713e6ca`,包含 wireplumber-0.4 / libwayland-1.22 / vendored stb 全部改动 + `update.sh`)。
remote 布局: `upstream` = `noctalia-dev/noctalia`(上游),`origin` = fork `Joreh-T/noctalia`(备份)。

更新只需一条命令:

```bash
cd ~/workspaces/window_mananger_ui/noctalia && ./update.sh
```

它做的事情: `git fetch upstream` → rebase 补丁到 `upstream/main`(冲突时逐个解决) → 全新 meson 配置
(g++-14 + `~/noctalia-deps` 的 sdbus-c++ v2 + RPATH)→ 编译 → 安装到 `~/.local/bin/noctalia`
→ **构建安装成功后**才 push 分支到 fork(自动备份,失败的 rebase/编译不会被推上去)。
完成后重启 noctalia(或注销重登)生效。

注意:
- 全新机器: 构建依赖见 `apt-packages.txt`(一行一个包),一键安装 `sudo apt install -y $(grep -v '^#' apt-packages.txt)`;手工粘贴版在 `apt-packages.paste.txt`(两份保持同步)。注意 sdbus-c++ v2 **不在** apt 清单内,需按 §二.4 源码构建到 `~/noctalia-deps`。
- Ubuntu 24.04 不会升级 wireplumber-0.5 / libwayland-1.23,这些补丁**长期需要**,每次 rebase 都要带着。
- rebase 冲突高发区: `src/pipewire/wireplumber_mixer.cpp`(0.5→0.4 API)、`src/wayland/virtual_keyboard_service.*`(避开 `wl_proxy_get_display`)。
- 旧的 `build-release/` 记录的是搬家前的路径(`~/src/noctalia`),已被脚本删除重建,无需保留。

---
