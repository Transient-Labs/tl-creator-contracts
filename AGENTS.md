# AGENTS.md

## Scope
These instructions apply to the entire repository.

## Repository Overview
This is a Foundry-based Solidity repository for Transient Labs creator contracts, rendering contracts, and related interfaces. Core contracts live in `src/`, tests live in `test/`, deployment scripts live in `script/`, and dependency packages are managed through Soldeer in `dependencies/`.

## Development Standards
- Prefer OpenZeppelin contracts and libraries over custom implementations when they fit the use case.
- Keep contract logic explicit, readable, and easy to audit.
- Avoid inline assembly unless it is already established in nearby code or explicitly required.
- Preserve public interfaces, storage layout expectations, events, and custom errors unless the task explicitly requires a breaking change.
- Be especially careful with ownership, admin roles, mint permissions, royalties, transfer validators, NFT delegation, rendering contracts, and metadata update behavior.
- Follow existing Solidity style: `pragma solidity 0.8.30`, SPDX headers, NatSpec for public-facing behavior, custom errors, and explicit event assertions in tests.

## Dependencies
- Use Soldeer-managed imports from `dependencies/` and `remappings.txt`.
- Do not vendor new dependencies manually.
- Prefer existing OpenZeppelin `5.6.1` packages and `forge-std-1.14.0` import patterns.
- Use `make install` to install dependencies and `make update` only when dependency refresh is intended.

## Build, Test, and Analysis Commands
- Format Solidity with `make fmt` or `forge fmt`.
- Build with `make build`.
- Run the standard test suite with `make test-std`.
- Use `make test-quick` for faster feedback and `make test-fuzz` for deeper fuzzing.
- Use `make test-gas` when gas impact matters.
- Use `make test-cov` for coverage.
- Run static analysis with `make analyze`, which invokes Slither through `uv`.

## Testing Standards
- Add or update Foundry tests for every behavioral contract change.
- Prefer focused unit tests for isolated behavior and integration-style tests for cross-contract flows.
- Assert emitted events for state-changing paths where events are part of the contract interface.
- Prefer contract constants, selectors, custom errors, and event declarations over hard-coded literals.
- Use fuzz tests for access control, input validation, royalties, metadata state transitions, and delegation/authorization paths.
- Keep fuzz tests deterministic and constrain inputs with `vm.assume(...)` where needed.
- Maintain realistic tests for clone/proxy initialization and disabled-initializer behavior when touching deployable implementations.

## Security and Review Priorities
- Treat changes to authorization, minting, royalties, transfer validation, metadata mutation, delegation checks, and renderer callbacks as high risk.
- Confirm zero-address handling and permanent-disable semantics before changing transfer validator logic.
- Preserve ERC-165 support declarations and interface compatibility.
- Check ERC-4906 metadata update emissions when token URI or rendering behavior changes.
- Avoid broad refactors in security-sensitive code unless required by the task.

## Deployment and Environment
- Deployment commands use `forge script` through Makefile targets and rely on `.env` values.
- Never commit private keys, RPC secrets, ledger configuration, or populated `.env` files.
- Treat `deployments.json` as the source for recorded deployments; update it only when the task explicitly involves deployment metadata.
- Do not run broadcast deployment targets unless explicitly requested.

## Generated and Local Artifacts
- Do not edit `out/`, `cache/`, `broadcast/`, or generated coverage artifacts by hand.
- Keep changes scoped to source, tests, scripts, docs, and configuration relevant to the task.
