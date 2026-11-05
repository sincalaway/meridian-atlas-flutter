#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Install Flutter 3.x first, then rerun this script." >&2
  exit 1
fi
if [[ -e android || -e ios ]]; then
  echo "android/ or ios/ already exists; refusing to overwrite native project files." >&2
  exit 1
fi

project_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

flutter create --project-name meridian_atlas --platforms=android,ios --no-pub "$tmp_dir/app"
cp -R "$tmp_dir/app/android" "$project_root/android"
cp -R "$tmp_dir/app/ios" "$project_root/ios"
cd "$project_root"
flutter pub get

echo "Native Android/iOS folders generated; run 'flutter run' to launch on a connected device."
