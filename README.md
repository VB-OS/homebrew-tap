# VB-OS Homebrew Tap

Official Homebrew tap for the [VB-OS](https://vb-os.org) command-line interface.

## Install

```bash
brew tap VB-OS/tap
brew install vbos
```

## Verify

```bash
vbos --version
```

## Usage

```bash
vbos verify --project my-project --boundary payment-authorization \
  --evidence '{"transaction_amount": 15000, "account_balance": 42000}'
```

See the [CLI documentation](https://docs.vb-os.org/cli/installation/) for the full command reference.

## About VB-OS

VB-OS is deterministic execution authority infrastructure — binary ASSERT/DEFER verdicts, replayable from immutable artifacts.

Created by Asaad Riaz. Developed and maintained by [MNC Labs, Inc.](https://vb-os.org)

## License

Proprietary — MNC Labs, Inc.
