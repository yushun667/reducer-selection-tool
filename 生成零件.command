#!/bin/bash
# 减速器零件生成器：自动找到 ~/Downloads 里最新的 gen_rv_parts*.py 并生成 STEP 零件
# 用法：在选型工具里点「一键生成零件 STEP」下载脚本后，双击本文件
PY=$(ls -t ~/Downloads/gen_rv_parts*.py 2>/dev/null | head -1)
if [ -z "$PY" ]; then
  echo "未找到 ~/Downloads/gen_rv_parts*.py"
  echo "请先在减速器选型工具里点「一键生成零件 STEP」按钮下载脚本。"
  read -r -p "按回车退出..."
  exit 1
fi
echo "使用脚本: $PY"
cd "$(dirname "$PY")" || exit 1
/Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd "$PY"
echo ""
echo "完成：零件 STEP 已输出到 $(dirname "$PY")/rv-parts/"
read -r -p "按回车退出..."
