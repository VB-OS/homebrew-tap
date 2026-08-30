#!/usr/bin/env bash
set -euo pipefail

# Formula generator for VB-OS CLI Homebrew distribution.
#
# Two input modes:
#   RELEASE:          --version X --url <pypi-url> --sha256 <hash>
#   PRE-PUBLICATION:  --version X --local-sdist <path-to-sdist>
#
# In both modes, dependencies are resolved from the exact package being
# formulaized (the sdist itself), never from a potentially stale PyPI copy.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FORMULA_DIR="$REPO_DIR/Formula"

VERSION=""
SOURCE_URL=""
SOURCE_SHA=""
LOCAL_SDIST=""
PYTHON_DEP="python@3.12"

usage() {
  cat <<'USAGE'
Usage:
  generate-formula.sh --version <ver> --url <url> --sha256 <sha>
  generate-formula.sh --version <ver> --local-sdist <path>

Options:
  --version      Package version (required)
  --url          Source archive URL (release mode)
  --sha256       SHA-256 of source archive (release mode)
  --local-sdist  Path to locally built sdist (pre-publication mode)
  --python       Python dependency for Homebrew (default: python@3.12)
  --help         Show this help
USAGE
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2 ;;
    --url)      SOURCE_URL="$2"; shift 2 ;;
    --sha256)   SOURCE_SHA="$2"; shift 2 ;;
    --local-sdist) LOCAL_SDIST="$2"; shift 2 ;;
    --python)   PYTHON_DEP="$2"; shift 2 ;;
    --help)     usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Error: --version is required" >&2
  exit 1
fi

if [[ -n "$LOCAL_SDIST" && -n "$SOURCE_URL" ]]; then
  echo "Error: --local-sdist and --url are mutually exclusive" >&2
  exit 1
fi

if [[ -z "$LOCAL_SDIST" && -z "$SOURCE_URL" ]]; then
  echo "Error: either --local-sdist or --url is required" >&2
  exit 1
fi

if [[ -n "$SOURCE_URL" && -z "$SOURCE_SHA" ]]; then
  echo "Error: --sha256 is required with --url" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

VENV_DIR="$WORK_DIR/venv"
python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip

if [[ -n "$LOCAL_SDIST" ]]; then
  if [[ ! -f "$LOCAL_SDIST" ]]; then
    echo "Error: local sdist not found: $LOCAL_SDIST" >&2
    exit 1
  fi
  SOURCE_SHA=$(shasum -a 256 "$LOCAL_SDIST" | cut -d' ' -f1)
  LOCAL_SDIST_ABS=$(cd "$(dirname "$LOCAL_SDIST")" && echo "$(pwd)/$(basename "$LOCAL_SDIST")")
  SOURCE_URL="file://$LOCAL_SDIST_ABS"
  echo "Pre-publication mode: using local sdist"
  echo "  Path: $LOCAL_SDIST_ABS"
  echo "  SHA-256: $SOURCE_SHA"
else
  echo "Release mode: using published sdist"
  echo "  URL: $SOURCE_URL"
  echo "  SHA-256: $SOURCE_SHA"
fi

echo ""
echo "Resolving dependencies for vb-os[cli]==$VERSION..."

DOWNLOAD_DIR="$WORK_DIR/downloads"
mkdir -p "$DOWNLOAD_DIR"

if [[ -n "$LOCAL_SDIST" ]]; then
  pip install --quiet "${LOCAL_SDIST_ABS}[cli]" 2>/dev/null || true
  pip download --no-binary :all: --dest "$DOWNLOAD_DIR" \
    --no-deps "$LOCAL_SDIST_ABS" 2>/dev/null || true
  pip download --no-binary :all: --dest "$DOWNLOAD_DIR" \
    httpx pydantic click keyring cryptography tomli_w 2>/dev/null || true
else
  pip download --no-binary :all: --dest "$DOWNLOAD_DIR" \
    "vb-os[cli]==$VERSION" 2>/dev/null || true
fi

pip download --no-binary :all: --dest "$DOWNLOAD_DIR" \
  httpx pydantic click keyring cryptography tomli_w 2>&1 | tail -5 || true

echo ""
echo "Generating resource blocks..."

RESOURCES=""
for sdist_file in "$DOWNLOAD_DIR"/*.tar.gz "$DOWNLOAD_DIR"/*.zip; do
  [[ -f "$sdist_file" ]] || continue
  filename=$(basename "$sdist_file")

  # Skip the vb-os package itself
  if echo "$filename" | grep -qi "^vb.os\|^vb_os"; then
    continue
  fi

  dep_name=$(echo "$filename" | sed -E 's/[-_]([0-9]).*//' | tr '_' '-')
  dep_sha=$(shasum -a 256 "$sdist_file" | cut -d' ' -f1)

  pypi_url="https://files.pythonhosted.org/packages/source/${dep_name:0:1}/${dep_name}/${filename}"

  RESOURCES+="
  resource \"${dep_name}\" do
    url \"${pypi_url}\"
    sha256 \"${dep_sha}\"
  end
"
done

if [[ -z "$RESOURCES" ]]; then
  echo "Warning: no dependency resources resolved. Formula may be incomplete." >&2
  echo "  This can happen in pre-publication mode if dependencies are not available as sdists." >&2
fi

FORMULA_URL="$SOURCE_URL"
if [[ "$SOURCE_URL" == file://* ]]; then
  FORMULA_URL="$SOURCE_URL"
fi

mkdir -p "$FORMULA_DIR"

cat > "$FORMULA_DIR/vbos.rb" <<RUBY
class Vbos < Formula
  include Language::Python::Virtualenv

  desc "VB-OS verification platform CLI"
  homepage "https://vb-os.org"
  url "${FORMULA_URL}"
  sha256 "${SOURCE_SHA}"
  license "LicenseRef-Proprietary"

  depends_on "${PYTHON_DEP}"
${RESOURCES}
  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/vbos --version")
  end
end
RUBY

echo ""
echo "Formula generated: $FORMULA_DIR/vbos.rb"
echo ""

dep_count=$(echo "$RESOURCES" | grep -c 'resource "' || true)
echo "Summary:"
echo "  Version: $VERSION"
echo "  Dependencies: $dep_count resource blocks"
echo "  Output: $FORMULA_DIR/vbos.rb"
echo ""
echo "Next steps:"
echo "  brew audit --new-formula Formula/vbos.rb"
echo "  brew style Formula/vbos.rb"
