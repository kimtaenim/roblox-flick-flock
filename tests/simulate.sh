#!/bin/sh
# NPC 대 NPC 시뮬레이션 실행 : sh tests/simulate.sh  (luau CLI 필요)
set -e
cd "$(dirname "$0")"
mkdir -p _build
{
	echo 'local Color3 = { fromRGB = function() return {} end, new = function() return {} end }'
	cat ../src/shared/Config.lua
} > _build/Config.lua
luau simulate.luau
