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

`Prospect → Contacted → Replied → Meeting → Proposal → Won → Lost / Dormant`

It also creates fields for Contact, Opportunity, Next follow-up, Last contact, Source, Notes, and Estimated value, plus a Pipeline board view.

The setup script intentionally contains **no prospect or client data**, because this repository is public. Add leads as draft items directly in the private GitHub Project.

### Setup

The script requires the GitHub CLI and authentication with the `project` scope:

```bash
gh auth refresh -s project
bash scripts/setup-github-project.sh
```

By default it creates the project under `vbeffa` and links `vbeffa/vlad-consulting`. These can be overridden with `OWNER`, `REPO`, and `PROJECT_TITLE` environment variables.
