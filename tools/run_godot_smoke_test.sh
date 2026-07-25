#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.6.3}"
ARCHIVE_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
BINARY_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
DOWNLOAD_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/${ARCHIVE_NAME}"
CACHE_ROOT="${RUNNER_TEMP:-/tmp}/godot-${GODOT_VERSION}"
BINARY_PATH="${CACHE_ROOT}/${BINARY_NAME}"

mkdir -p "${CACHE_ROOT}"

if [[ ! -x "${BINARY_PATH}" ]]; then
  echo "Descargando Godot ${GODOT_VERSION}..."
  curl --fail --location --retry 3 --output "${CACHE_ROOT}/${ARCHIVE_NAME}" "${DOWNLOAD_URL}"
  unzip -q -o "${CACHE_ROOT}/${ARCHIVE_NAME}" -d "${CACHE_ROOT}"
  chmod +x "${BINARY_PATH}"
fi

"${BINARY_PATH}" --version

echo "Importando recursos en modo headless..."
"${BINARY_PATH}" --headless --path "${ROOT_DIR}" --import

echo "Cargando la escena principal durante cinco iteraciones..."
"${BINARY_PATH}" \
  --headless \
  --path "${ROOT_DIR}" \
  --scene res://scenes/main/MainGame.tscn \
  --quit-after 5

echo "Ejecutando la revisión integral de jugabilidad..."
"${BINARY_PATH}" \
  --headless \
  --path "${ROOT_DIR}" \
  --scene res://tests/TestRunner.tscn

echo "Ejecutando la regresión de rutas intermedias..."
"${BINARY_PATH}" \
  --headless \
  --path "${ROOT_DIR}" \
  --scene res://tests/TestRoutes.tscn

echo "Pruebas de Godot completadas correctamente."
