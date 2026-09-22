# Vlad Consulting

Source for [vladbeffa.com](https://vladbeffa.com/), plus small utilities used to manage the consulting workflow.

## Local development

Run the static site locally with:

```bash
./run-local.sh
```

## Consulting lead project

`scripts/setup-github-project.sh` creates a private, user-owned GitHub Project named **Tech Consulting** and links it to this repository. The project is intended as a lightweight CRM for prospects and client opportunities; implementation work should remain in repository issues/PRs or a client-specific repository.

The project uses this pipeline:

`Prospect → Contacted → Replied → Discovery → Proposal → Won → Lost / Dormant`

`Discovery` means requirements and scope are still being explored before a concrete proposal. Meetings can happen during Discovery, Proposal, or later stages without changing the stage by themselves.

It also creates fields for Contact, Email, Phone, Website, Opportunity, Next follow-up, Last contact, Source, Notes, and Estimated value, plus a Pipeline board view.

The setup script intentionally contains **no prospect or client data**, because this repository is public.

### Setup

The setup script requires the GitHub CLI and authentication with the `project` scope:

```bash
gh auth refresh -s project
bash scripts/setup-github-project.sh
```

By default it creates the project under `vbeffa` and links `vbeffa/vlad-consulting`. These can be overridden with `OWNER`, `REPO`, and `PROJECT_TITLE` environment variables.

### Import private leads

Actual prospect/client data should remain local. The repository ignores `.private/`, and `scripts/import-consulting-leads.sh` reads lead data from `.private/consulting-leads.json` by default.

Start from the committed example:

```bash
mkdir -p .private
cp scripts/consulting-leads.example.json .private/consulting-leads.json
```

Edit the local JSON file with the lead contact details and opportunity data, then preview the import without changing the Project:

```bash
DRY_RUN=1 bash scripts/import-consulting-leads.sh
```

When the preview looks correct, run the importer without `DRY_RUN`. Existing Project items with the same title are skipped to reduce accidental duplicates.

The importer defaults to GitHub Project `#2` under `vbeffa`. Override `OWNER`, `PROJECT_NUMBER`, or `DATA_FILE` as needed.
