# Engine audit

Findings from the config engine audit, applied in the order they were fixed.

- **H1** — lua/config/health.lua:595 — compilation database loop assigned without `break`, so `compile_flags.txt` won over `compile_commands.json` — fixed
- **H2** — lua/config/health.lua:141 — `rustup show active-toolchain` returning nil reported as green `active toolchain: unknown` — fixed
