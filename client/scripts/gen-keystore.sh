#!/usr/bin/env bash
# 生成 Android release 签名密钥库，并输出 GitHub Actions 需要的 secrets。
#
# 用法：
#   bash scripts/gen-keystore.sh [输出目录]
#
# 默认输出到仓库外的 .workbuddy/keystore/，避免密钥库被误提交。
# 生成后按提示把 4 个值填进 GitHub 仓库 Settings → Secrets and variables → Actions。
set -euo pipefail

cd "$(dirname "$0")/.."
OUT_DIR="${1:-../.workbuddy/keystore}"
ALIAS="${KEY_ALIAS:-upload}"

mkdir -p "$OUT_DIR"

if [ -f "$OUT_DIR/upload-keystore.jks" ]; then
  echo "已存在 $OUT_DIR/upload-keystore.jks，先删掉再来，避免覆盖已有签名。" >&2
  exit 1
fi

read -r -s -p "设置密钥库口令（至少 6 位）: " STORE_PASS; echo
read -r -s -p "再输一次: " STORE_PASS2; echo
[ "$STORE_PASS" = "$STORE_PASS2" ] || { echo "两次输入不一致" >&2; exit 1; }
[ ${#STORE_PASS} -ge 6 ] || { echo "口令太短" >&2; exit 1; }

read -r -p "证书主体（可直接回车用默认值）: " DNAME
DNAME="${DNAME:-CN=AlandX, OU=dev, O=AlandX, L=Unknown, ST=Unknown, C=CN}"

keytool -genkeypair \
  -keystore "$OUT_DIR/upload-keystore.jks" \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$ALIAS" \
  -storepass "$STORE_PASS" \
  -keypass "$STORE_PASS" \
  -dname "$DNAME"

echo
echo "密钥库已生成：$OUT_DIR/upload-keystore.jks"
echo
echo "===== 到 GitHub 依次添加这 4 个 Secret ====="
echo
echo "1) KEYSTORE_BASE64   （下面这一整行，注意别换行）"
echo "----------------------------------------------------------------"
base64 -w0 < "$OUT_DIR/upload-keystore.jks"
echo
echo "----------------------------------------------------------------"
echo
echo "2) KEYSTORE_PASSWORD = （你刚才输入的口令）"
echo "3) KEY_ALIAS         = $ALIAS"
echo "4) KEY_PASSWORD      = （与 KEYSTORE_PASSWORD 相同）"
echo
echo "填完之后打 tag 就会出正式签名的包："
echo "  git tag v0.1.1 && git push origin v0.1.1"
echo
echo "警告：upload-keystore.jks 丢了就无法再发布同签名的更新，务必自己备份。"
