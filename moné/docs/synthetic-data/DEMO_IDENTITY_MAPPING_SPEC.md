# Demo Identity Mapping Specification

Demo identity is separate from Account Aggregator holder profile data.

## Purpose

Synthetic AA payloads may contain source-like holder fields such as masked names, dummy mobile numbers, placeholder PAN values, or synthetic email addresses. Those fields are fixture source facts only. They must not determine the signed-in demo user shown in the app.

## Mapping File

The dataset package includes `data/synthetic/output/aarav_spend_control_rash_decisions/demo_identity_map.json`, and the generator also writes a shared root copy at `data/synthetic/output/demo_identity_map.json` for app/provider convenience.

The mapping defines supported demo phone numbers:

- `8828290489` -> Aarav, dataset `aarav_spend_control_rash_decisions`, status `wired`
- `7304893952` -> Priya, status `not_wired_yet`, no dataset id
- all other numbers -> `unsupported_demo_number`

## Dataset Registry

The dataset package includes `data/synthetic/output/aarav_spend_control_rash_decisions/dataset_registry.json`, and the generator also writes a shared root copy at `data/synthetic/output/dataset_registry.json`.

The registry declares dataset availability:

- `aarav_spend_control_rash_decisions` is ready.
- `priya_goal_planner` is not wired yet.

Runtime provider code must only wire datasets whose registry status is `ready`.

## Rules

- Do not show raw holder profile identity such as synthetic holder placeholders in user-facing UI.
- Do not map Priya's phone number to Aarav data.
- Unsupported demo numbers must show an explicit retry/unsupported state.
- Validation must fail if the identity map or registry is missing or contradicts these rules.
