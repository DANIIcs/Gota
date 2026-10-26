# Where these fonts come from

The original metric-compatible builds of Carlito (Calibri) and Caladea (Cambria), the same files LibreOffice ships.
Not the later Google Fonts builds: those changed Carlito's line height and Caladea's widths, so they no longer match
Calibri and Cambria (measured: 0.772 vs 0.961 SSIM against Word on a table document). LibreOffice warns about it too
(`download.lst`: "two Caladea fonts with different metrics").

| Files | Tarball (dev-www.libreoffice.org/src/) | SHA-256 | License |
|---|---|---|---|
| Caladea-*.ttf | `368f114c078f94214a308a74c7e991bc-crosextrafonts-20130214.tar.gz` | `c48d1c2fd613c9c06c959c34da7b8388059e2408d2bb19845dc3ed35f76e4d09` | Apache-2.0 |
| Carlito-*.ttf | `c74b7223abe75949b4af367942d96c7a-crosextrafonts-carlito-20130920.tar.gz` | `4bd12b6cbc321c1cf16da76e2c585c925ce956a08067ae6f6c64eff6ccfdaf5a` | OFL-1.1 |

To verify: download both tarballs, check them with `shasum -a 256`, unpack and compare the `.ttf` files with these.
Do not replace them with newer builds without measuring against Word first (docs/MOTORES.md).
