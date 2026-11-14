# AGENTS.md

GitHub Action for Autosana CI integration: uploads builds and triggers flows from customers' GitHub workflows. It's a customer-facing interface, so changes here usually need matching API support (AutosanaBackend) and docs (AutosanaDashboard/docs).

Run tests with `make test` (bats).

## Interfaces & Feature Parity (IMPORTANT)

Customers interact with Autosana through multiple surfaces: the dashboard (AutosanaDashboard), the REST API, MCP server and CLI (AutosanaBackend `app/`, `mcp_server/`, `cli/`), code-managed flows (the customer-facing `.autosana/` YAML format), and the CI action (the `Autosana/autosana-ci` repo). When you add or change functionality on one, decide whether the others need it too. If an interface changes, docs (AutosanaDashboard/docs) probably need updating, too.

## Feature Completeness (IMPORTANT)

Always consider what systems will be affected by your changes. For example, if making a change to how flows are run, ask things like:
- "Will this work with the caching system?"
- "Will this work for multi-device flows?"

## What users and PR reviewers care about (IMPORTANT)

Keep these in mind when talking with the user or creating a PR on any repo. Reviewers have limited time. They don't need the nitty gritty of how each file works. They need concise (ideally no more than a couple sentences for simple tasks) and accurate answers to the following. The reviewer should be able to understand the following, ideally in under a minute.
- Architecture (high level): What systems are involved, and how do they interact with one another? Are there any flaws that could prevent something mission-critical from working, or that could prevent this from being extensible (if a core feature)?
- Interfaces: How will customers interact with this? Interfaces include CLI, MCP, API, docs, CI/GH action, dashboard...
