#!/bin/bash

# 作者: 像素代码师
# 版本: 9.4.3

# SMCL: Simple Minecraft Launcher: 一个简单的 Minecraft 启动器 (bash 实现)

# ========== 系统检测 ==========
# 检测操作系统
OS_TYPE=$(uname -s)
ARCH_TYPE=$(uname -m)

case "$OS_TYPE" in
    Darwin)
        IS_MAC=true
        OS_NAME="macos"
        ;;
    Linux)
        IS_MAC=false
        OS_NAME="linux"
        ;;
    *)
        echo "错误: 不支持的操作系统 '$OS_TYPE'"
        echo "仅支持 macOS 和 Linux"
        exit 1
        ;;
esac

# 检测架构 (仅支持64位)
case "$ARCH_TYPE" in
    x86_64|amd64)
        ARCH_NAME="x86_64"  # x86_64 通常不需要后缀
        ;;
    arm64|aarch64)
        ARCH_NAME="arm64"
        ;;
    *)
        echo "错误: 不支持的架构 '$ARCH_TYPE'"
        echo "仅支持 64 位系统 (x86_64/amd64 或 arm64/aarch64)"
        exit 1
        ;;
esac

echo "检测到系统: $OS_NAME"
echo "检测到架构: $ARCH_NAME"
echo ""

# 目录结构
# /
#     assets/ # 可选(不存在不会影响核心内容, 也不会崩溃), 里面是非en-us的语言, 音效, 全景图
#     indexes/
#         $mc_version.json
#         注意: 原本可能是'[一个数字].json', 例如1.20.1是'5.json', 需要重命名为'$mc_version.json'
#     objects/
#         哈希前2位/哈希值
#     libraries/ # 必须, 里面是所有的 java 库, 包括 lwjgl 等
#     $mc_version.jar # 必须, 游戏jar文件. 默认为 versions/$mc_version/$mc_version.jar, 请移动并删除 versions 目录
#     lwjgl-natives-系统-架构/ # 必须, lwjgl 的 natives 文件
#     natives-系统-架构/ # 无需出处理, 会自动解压到这里
#     run/
#         以下是游戏内容的, 删除游戏不会崩溃, 但一些内容(如存档)则会丢失
#         resourcepacks/ # 资源包, 资源包放到这里
#         saves/ # 存档
#         options.txt # 设置选项, 如选择的语言等
#         以下是游戏运行时生成的内容, 建议在非调试情况下删除
#         logs/ # 日志
#         crash-reports/ # 崩溃报告

# 注意:
# 1. 请不要把无关的 jar 文件放到 libraries 目录下
# 2. 请确保 libraries 目录下有所有的 java 库完整, 版本正确
# 3. 请确保 $mc_version.jar 存在, 且完整
# 4. 不支持 Fabric以外的模组加载器, Fabric需把FabricLoader等相关库放入libraries目录下
# 5. 如果需要自定义启动参数, 请修改下面的 cmd 变量

# 以下是配置, 请根据实际情况修改
java_path='java'
is_fabric="false" # 是否使用 Fabric 加载器
mc_version="1.20.1"
username="test"
uuid="123e4567e89b12d3a456426614174000" # 32位uuid, 不要包含-
memory=4096 # 内存(单位: MB)

# 进入游戏目录
game_dir="$(dirname $(abspath $0))/$mc_version"
echo "游戏目录: $game_dir"

# natives 目录 (使用绝对路径，因为命令在 run 目录下执行)
lwjgl_natives_dir="$game_dir/lwjgl-natives-${OS_NAME}-${ARCH_NAME}"
natives_dir="$game_dir/natives-${OS_NAME}-${ARCH_NAME}"

# 资产目录 (可选, 不存在不会影响核心内容, 也不会崩溃)
assets_dir="$game_dir/assets"

# 主类, 不同版本可能不一样
if [ "$is_fabric" = "true" ]; then
    # 这里 libraries 目录必须包含 Fabric loader 的libraries项
    main_class="net.fabricmc.loader.impl.launch.knot.KnotClient"
else
    main_class="net.minecraft.client.main.Main"
fi

libraries_dir="$game_dir/libraries"
classpath=$(find "$libraries_dir/universal" -name "*.jar" | tr '\n' ':') # 类路径, 包含所有的 java 库
classpath="${classpath%:}" # 移除classpath结尾的:(如果有)
mc_jar_path="$game_dir/$mc_version.jar"
classpath+=":$mc_jar_path"

# Linux 加 netty-transport-native-epoll
if [ "$OS_NAME" = "linux" ]; then
    # arm64 -> aarch64
    if [ "$ARCH_NAME" = "arm64" ]; then
        arch="aarch64"
    else
        arch="$ARCH_NAME"
    fi
    
    # 拼接classpath
    classpath+=":$libraries_dir/linux/netty-transport-native-epoll-4.1.82.Final-linux-$arch.jar"

    # 移除无用的arch变量
    unset arch
fi

# macOS 专有参数
if [ "$OS_NAME" = "macos" ]; then
    # 必须, 否则会崩溃
    MACOS_ARGS="-XstartOnFirstThread"
else
    MACOS_ARGS=""
fi

# 运行目录
run_dir="$game_dir/run"
mkdir -p "$run_dir" # 确保运行目录存在

# [可选] 如果设置文件不存在, 则创建, 并设置语言为中文简体
if [ ! -f "$run_dir/options.txt" ]; then    
    echo "lang:zh_cn" > "$run_dir/options.txt"
    echo "已创建设置文件, 语言为中文简体"
fi

cmd="'$java_path' -Xmx${memory}M -Xms${memory}M -cp '$classpath' $MACOS_ARGS '-Djava.library.path=$lwjgl_natives_dir:$natives_dir' '-Djna.tmpdir=$natives_dir' '-Dio.netty.native.workdir=$natives_dir' $main_class --username '$username' --uuid $uuid --accessToken 0 --userType offline --version $mc_version --assetsDir '$assets_dir' --assetIndex $mc_version"

# 命令说明:
# -XstartOnFirstThread 仅在 macOS 上需要, 现已自动处理
# 对使用了$变量的参数添加单引号, 防止变量包含空格等问题, 一些参数不需要, 因为内存是整数, uuid 是32位十六进制数, mc_version 是仅包含数字和点的字符串
# --accessToken 0 的 0 表示离线模式, 不使用 Mojang 账号登录

# 用于调试
echo "命令: $cmd"

# 进入运行目录
cd "$run_dir"

eval $cmd