#!/bin/bash

# 作者: 像素代码师
# 版本: 9.4.3 (简化版)

# SMCL Simple: 简化版 Minecraft 启动器 (仅 macOS)
# 特点: 不支持 Fabric, 无资产目录

# ========== 系统检测 ==========
OS_TYPE=$(uname -s)
ARCH_TYPE=$(uname -m)

# 仅支持 macOS
if [ "$OS_TYPE" != "Darwin" ]; then
    echo "错误: 此简化版仅支持 macOS"
    exit 1
fi

# 检测架构 (仅支持64位)
case "$ARCH_TYPE" in
    x86_64|amd64)
        ARCH_NAME="x86_64"
        ;;
    arm64|aarch64)
        ARCH_NAME="arm64"
        ;;
    *)
        echo "错误: 不支持的架构 '$ARCH_TYPE'"
        exit 1
        ;;
esac

echo "系统: macOS ($ARCH_NAME)"

# ========== 配置 ==========
java_path='java'
mc_version="1.20.1"
uuid="123e4567e89b12d3a456426614174000"
memory=4096

# ========== 路径设置 ==========
game_dir="$(dirname $(abspath $0))/$mc_version"
echo "游戏目录: $game_dir"

lwjgl_natives_dir="$game_dir/lwjgl-natives-macos-${ARCH_NAME}"
natives_dir="$game_dir/run/natives-macos-${ARCH_NAME}"

# 主类 (原版)
main_class="net.minecraft.client.main.Main"

# 类路径
classpath=$(find "$game_dir/libraries" -name "*.jar" | tr '\n' ':')
classpath="${classpath%:}" # 移除结尾的:
mc_jar_path="$game_dir/$mc_version.jar"
classpath="$classpath:$mc_jar_path"

# ========== 启动命令 ==========
cmd="'$java_path' -Xmx${memory}M -Xms${memory}M -cp '$classpath' -XstartOnFirstThread '-Djava.library.path=$lwjgl_natives_dir:$natives_dir' '-Djna.tmpdir=$natives_dir' '-Dio.netty.native.workdir=$natives_dir' $main_class --uuid $uuid --accessToken 0 --version $mc_version"

echo "命令: $cmd"

cd "$game_dir/run"
eval $cmd
