#!/usr/bin/env bash
#
# Xoá dữ liệu Firestore của MỘT cơ sở WorkDay.
# Bản bash của tools/reset_data.ps1 - dùng khi chạy trong Git Bash / WSL / macOS.
#
# Dữ liệu mỗi cơ sở nằm trong companies/{companyId}, và companyId chính là uid
# Firebase của chủ cơ sở, nên bắt buộc phải chỉ rõ xoá cơ sở nào. Xem uid ở
# Console > Authentication > Users, hoặc Firestore > companies.
#
# Cách dùng:
#   ./tools/reset_data.sh --company <uid>                    # xoá sạch cơ sở đó
#   ./tools/reset_data.sh --company <uid> --keep-employees   # giữ danh sách nhân viên
#   ./tools/reset_data.sh --company <uid> --keep-settings    # giữ thiết lập chung
#   ./tools/reset_data.sh --company <uid> --project dev-asc  # dọn bản dev
#
# KHÔNG THỂ HOÀN TÁC. Firestore không có thùng rác.
#
# Cần Firebase CLI:  npm install -g firebase-tools  &&  firebase login

set -euo pipefail

PROJECT="tick-go"
COMPANY=""
KEEP_EMPLOYEES=0
KEEP_SETTINGS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --company) COMPANY="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --keep-employees) KEEP_EMPLOYEES=1; shift ;;
    --keep-settings) KEEP_SETTINGS=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Tham so la: $1"; exit 1 ;;
  esac
done

if [[ -z "$COMPANY" ]]; then
  echo "Thieu --company <uid>: phai chi ro xoa co so nao."
  echo "Xem uid o Console > Authentication > Users."
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "Chua co Firebase CLI."
  echo "Cai bang:  npm install -g firebase-tools"
  echo "Roi dang nhap:  firebase login"
  exit 1
fi

ROOT="companies/$COMPANY"
WIPE_ALL=0
[[ $KEEP_EMPLOYEES -eq 0 && $KEEP_SETTINGS -eq 0 ]] && WIPE_ALL=1

TARGETS=("$ROOT/attendance")
[[ $KEEP_EMPLOYEES -eq 0 ]] && TARGETS+=("$ROOT/employees")
[[ $KEEP_SETTINGS -eq 0 ]] && TARGETS+=("$ROOT/settings")
# Xoa sach thi bo luon document co so va ho so nguoi dung.
if [[ $WIPE_ALL -eq 1 ]]; then
  TARGETS+=("$ROOT")
  TARGETS+=("users/$COMPANY")
fi

echo
echo "====================================================="
echo " XOA DU LIEU WORKDAY - KHONG THE HOAN TAC"
echo "====================================================="
echo
echo "Firebase project : $PROJECT"
echo "Co so (companyId): $COMPANY"
echo "Se xoa           : ${TARGETS[*]}"
[[ $KEEP_EMPLOYEES -eq 1 ]] && echo "Giu lai          : danh sach nhan vien"
[[ $KEEP_SETTINGS -eq 1 ]] && echo "Giu lai          : thiet lap chung"
echo

read -r -p "Go dung chu XOA (chu in hoa) roi Enter de tiep tuc: " ANSWER
if [[ "$ANSWER" != "XOA" ]]; then
  echo "Da huy, khong xoa gi."
  exit 0
fi

for path in "${TARGETS[@]}"; do
  echo
  echo "Dang xoa $path ..."
  # --recursive: xoa ca document con; --force: khong hoi lai (da hoi o tren).
  firebase firestore:delete "$path" --recursive --force --project "$PROJECT"
done

echo
echo "Xong. Da xoa du lieu Firestore cua co so nay."
echo

if [[ $WIPE_ALL -eq 1 ]]; then
  echo "CON MOT VIEC PHAI LAM TAY:"
  echo "  Tai khoan dang nhap nam trong Firebase Authentication, khong nam"
  echo "  trong Firestore nen script nay khong xoa duoc."
  echo
  echo "  Mo: https://console.firebase.google.com/project/$PROJECT/authentication/users"
  echo "  Xoa user co uid $COMPANY."
  echo "  Chua xoa thi tai khoan do van dang nhap duoc nhung khong con co so nao."
  echo
fi
