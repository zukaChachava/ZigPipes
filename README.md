# zigPipes

A small Zig library / demo for building simple pipeline-style workflows using channels and threads.

## Status

This project is under active development. Do NOT use this code in production. APIs, internals, and error handling may change at any time.

## What it does

- Provides a generic `Pipe(T)` abstraction (see `src/root.zig`).
- Starts worker threads that communicate over channels to form producer/consumer pipelines.
- Includes basic helpers for chaining stages (`begin`, `then`, `finally`) and managing units of work.

## Project layout

- `src/root.zig` — core `Pipe` / `Continuation` / `UnitOfWork` implementation.
- `build.zig` — build script.
- `zig-out/` — build outputs.

## Contributing

Contributions and issues are welcome. If you plan to contribute, open an issue first describing your intended change.
