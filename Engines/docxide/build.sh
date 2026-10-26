#!/bin/zsh
# Builds docxide-pdf (https://github.com/sverrejb/docxide-pdf, Apache-2.0), Gota's most faithful
# engine for .docx (docs/MOTORES.md), as a universal binary at build/engines/docxide-pdf.
#
# Pinned to REVISION, plus metric-clones.patch: when a document asks for Calibri or Cambria and they
# aren't installed (no Office), use their metric-compatible clones Carlito and Caladea (bundled in
# Engines/Fonts) instead of Arial, which shifted every line. Needs Rust (rustup) with the
# aarch64-apple-darwin and x86_64-apple-darwin targets. Without this binary Gota still builds and
# falls back to LibreOffice for .docx.
set -euo pipefail

here=${0:A:h}
root=${here:h:h}
src=$root/build/engines/docxide-src
out=$root/build/engines/docxide-pdf
revision=$(<"$here/REVISION")
export PATH="$HOME/.cargo/bin:$PATH"
export MACOSX_DEPLOYMENT_TARGET=26.0

# Only the pinned commit, shallow: the full history carries hundreds of MB of test documents.
if [[ ! -d $src/.git ]]; then
  git init --quiet "$src"
  git -C "$src" remote add origin https://github.com/sverrejb/docxide-pdf
fi
git -C "$src" fetch --quiet --depth 1 origin "$revision"
git -C "$src" checkout --quiet --force FETCH_HEAD
git -C "$src" apply "$here/metric-clones.patch"

for target in aarch64-apple-darwin x86_64-apple-darwin; do
  cargo build --quiet --release --locked --manifest-path "$src/Cargo.toml" --target "$target"
done
mkdir -p "${out:h}"
lipo -create -output "$out" \
  "$src/target/aarch64-apple-darwin/release/docxide-pdf" \
  "$src/target/x86_64-apple-darwin/release/docxide-pdf"
strip -x "$out"
lipo -archs "$out"
