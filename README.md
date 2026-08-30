# VB-OS Homebrew Tap

Homebrew formulae for VB-OS CLI tools.

## Installation

```bash
brew tap VB-OS/tap
brew install vbos
```

## Verification

```bash
vbos --version
```

## Formula Generation

Formulae are generated from published PyPI releases using the generation tooling
in `scripts/`. See the [release procedure](#release-procedure) below.

### Prerequisites

- Python 3.10+
- `pip` (for dependency resolution)
- Homebrew (for `brew audit`, `brew style` validation)

### Release Procedure

After a PyPI release of `vb-os[cli]`:

```bash
# Generate the formula from the published package
./scripts/generate-formula.sh \
  --version 0.1.0 \
  --url "https://files.pythonhosted.org/packages/.../vb_os-0.1.0.tar.gz" \
  --sha256 "<sha256-of-sdist>"

# Validate
brew audit --new-formula Formula/vbos.rb
brew style Formula/vbos.rb

# Install and test
brew install --build-from-source Formula/vbos.rb
brew test Formula/vbos.rb

# Commit and push
git add Formula/vbos.rb
git commit -m "vbos 0.1.0"
git push origin main
```

### Pre-Publication Testing

For local development and validation before PyPI publication:

```bash
# Build a local sdist
cd /path/to/vb-os-python-sdk
python -m build --sdist

# Generate formula from local sdist
./scripts/generate-formula.sh \
  --version 0.1.0 \
  --local-sdist dist/vb_os-0.1.0.tar.gz

# Validate the generated formula
brew audit --new-formula Formula/vbos.rb
brew style Formula/vbos.rb
```

## License

Proprietary — MNC Labs, Inc.
