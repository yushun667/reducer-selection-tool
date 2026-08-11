#!/bin/bash
# 构建原生 macOS 应用：减速器选型工具.app
# 依赖：macOS 自带 swiftc / sips / iconutil，无需安装任何第三方工具
set -e
cd "$(dirname "$0")/.."

APP_NAME="减速器选型工具"
APP_DIR="dist/${APP_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "==> 编译 Swift 壳"
rm -rf dist
mkdir -p "$MACOS_DIR" "$RES_DIR"
swiftc -O app/main.swift -o "$MACOS_DIR/reducer-tool" -framework Cocoa -framework WebKit

echo "==> 拷贝资源"
cp index.html planetary_gear_params.html RV结构剖视示意图.html "$RES_DIR/"
cp app/Info.plist "$APP_DIR/Contents/Info.plist"

echo "==> 生成图标"
# 用主工具的齿轮画法临时渲染一张 1024 图标
cat > /tmp/icon_gen.html <<'EOF'
<!DOCTYPE html><html><body style="margin:0;background:#1e2430">
<canvas id="c" width="1024" height="1024"></canvas>
<script>
const ctx = document.getElementById('c').getContext('2d');
const inv = x => Math.tan(x) - x;
const A = 20*Math.PI/180;
function gear(m, z, cx, cy, rot, fill, sc) {
  const r=m*z/2, rb=r*Math.cos(A), ra=r+m, rf=r-1.25*m;
  const ht=Math.PI/(2*z), ha=R=>R<=rb?ht+inv(A):ht+inv(A)-inv(Math.acos(rb/R));
  const hT=Math.max(ha(ra),0.002), Rl=Math.max(rb,rf);
  ctx.save(); ctx.translate(cx,cy); ctx.rotate(rot); ctx.scale(sc,sc);
  ctx.beginPath();
  for(let k=0;k<z;k++){const Ak=k*2*Math.PI/z,N=10;
    for(let s=0;s<=N;s++){const R=Rl+(ra-Rl)*s/N,pt=[R*Math.cos(Ak-ha(R)),R*Math.sin(Ak-ha(R))];k||s?ctx.lineTo(...pt):ctx.moveTo(...pt)}
    for(let s=1;s<=4;s++)ctx.lineTo(ra*Math.cos(Ak-hT+2*hT*s/4),ra*Math.sin(Ak-hT+2*hT*s/4));
    for(let s=N;s>=0;s--){const R=Rl+(ra-Rl)*s/N;ctx.lineTo(R*Math.cos(Ak+ha(R)),R*Math.sin(Ak+ha(R)))}
    const a1=Ak+ht+inv(A),a2=Ak+2*Math.PI/z-ht-inv(A);
    for(let s=1;s<=6;s++)ctx.lineTo(rf*Math.cos(a1+(a2-a1)*s/6),rf*Math.sin(a1+(a2-a1)*s/6))}
  ctx.closePath(); ctx.fillStyle=fill; ctx.fill();
  ctx.strokeStyle='#dfe7ee'; ctx.lineWidth=0.15; ctx.stroke(); ctx.restore();
}
ctx.fillStyle='#1e2430'; ctx.fillRect(0,0,1024,1024);
gear(1,72,512,512,0,'#5d6d7e',6.2);           // 内齿圈外缘近似
gear(1,18,512,512,0.1,'#6d7d8e',10.5);        // 太阳轮
gear(1,27,512,512-330,0.4,'#4e6d5e',10.5);    // 行星轮
gear(1,27,512+286,512+165,1.2,'#4e6d5e',10.5);
gear(1,27,512-286,512+165,2.0,'#4e6d5e',10.5);
ctx.beginPath(); ctx.arc(512,512,60,0,7); ctx.fillStyle='#141a23'; ctx.fill();
</script></body></html>
EOF
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ -x "$CHROME" ]; then
  "$CHROME" --headless --disable-gpu --screenshot=/tmp/icon_1024.png --window-size=1024,1024 \
    --virtual-time-budget=800 "file:///tmp/icon_gen.html" 2>/dev/null
else
  echo "!! 未找到 Chrome，用默认色块图标"; sips -z 1024 1024 /tmp/icon_1024.png --out /tmp/icon_1024.png 2>/dev/null || true
fi
ICONSET=dist/reducer.iconset
mkdir -p "$ICONSET"
for s in 16 32 64 128 256 512 1024; do
  sips -z $s $s /tmp/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RES_DIR/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> 打包 zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "dist/${APP_NAME}.zip"

echo "==> 完成: $APP_DIR"
