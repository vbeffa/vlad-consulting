#!/usr/bin/env bash
set -euo pipefail

# Create a private, user-owned GitHub Project for consulting lead tracking.
#
# Requirements:
#   - GitHub CLI (`gh`)
#   - authentication with the `project` scope
#
# Optional environment variables:
#   OWNER=vbeffa
#   REPO=vbeffa/vlad-consulting
#   PROJECT_TITLE='Tech Consulting'

OWNER="${OWNER:-vbeffa}"
REPO="${REPO:-vbeffa/vlad-consulting}"
PROJECT_TITLE="${PROJECT_TITLE:-Tech Consulting}"

command -v gh >/dev/null 2>&1 || {
  echo "error: GitHub CLI (gh) is not installed" >&2
  exit 1
}

gh auth status >/dev/null
gh repo view "$REPO" >/dev/null

existing_number="$(
  gh project list --owner "$OWNER" --format json --limit 100     --jq ".projects[] | select(.title == \"$PROJECT_TITLE\") | .number"     2>/dev/null || true
)"

if [[ -n "$existing_number" ]]; then
  echo "error: project '$PROJECT_TITLE' already exists as #$existing_number" >&2
  echo "Open it with: gh project view $existing_number --owner $OWNER --web" >&2
  exit 1
fi

echo "Creating project: $PROJECT_TITLE"
PROJECT_NUMBER="$(
  gh project create --owner "$OWNER" --title "$PROJECT_TITLE"     --format json --jq '.number'
)"

PROJECT_ID="$(
  gh project view "$PROJECT_NUMBER" --owner "$OWNER"     --format json --jq '.id'
)"

gh project edit "$PROJECT_NUMBER" --owner "$OWNER"   --visibility PRIVATE   --description "Lightweight CRM for consulting prospects, follow-ups, proposals, and client opportunities."   --readme $'Use this project to track consulting relationships and sales activity.\n\nKeep implementation work in repository issues/PRs (or a client-specific repository) once an opportunity becomes an actual project.'   >/dev/null

gh project link "$PROJECT_NUMBER" --owner "$OWNER" --repo "$REPO"

STATUS_FIELD_ID="$(
  gh api graphql     -F login="$OWNER"     -F number="$PROJECT_NUMBER"     -f query='query($login:String!, $number:Int!) {
      user(login:$login) {
        projectV2(number:$number) {
          fields(first:100) {
            nodes {
              ... on ProjectV2SingleSelectField { id name }
            }
          }
        }
      }
    }'     --jq '.data.user.projectV2.fields.nodes[] | select(.name == "Status") | .id'
)"

if [[ -z "$STATUS_FIELD_ID" ]]; then
  echo "error: could not locate the project's built-in Status field" >&2
  exit 1
fi

# Repurpose the built-in Status field as the consulting pipeline. This is safe
# for a newly-created project because it has no meaningful item status data yet.
gh api graphql   -F fieldId="$STATUS_FIELD_ID"   -f query='mutation($fieldId:ID!) {
    updateProjectV2Field(input:{
      fieldId:$fieldId,
      singleSelectOptions:[
        {name:"Prospect",       color:GRAY,   description:"Identified lead not yet contacted"},
        {name:"Contacted",      color:BLUE,   description:"Initial outreach sent"},
        {name:"Replied",        color:PURPLE, description:"Lead has responded; discovery has not started yet"},
        {name:"Discovery",      color:YELLOW, description:"Requirements and scope are being explored before a proposal"},
        {name:"Proposal",       color:ORANGE, description:"Scope/pricing proposal under consideration"},
        {name:"Won",            color:GREEN,  description:"Converted to paying client/project"},
        {name:"Lost / Dormant", color:RED,    description:"Declined, inactive, or no longer worth active follow-up"}
      ]
    }) {
      projectV2Field { ... on ProjectV2SingleSelectField { id name } }
    }
  }' >/dev/null

create_field() {
  local name="$1"
  local type="$2"
  shift 2

  gh project field-create "$PROJECT_NUMBER" --owner "$OWNER"     --name "$name" --data-type "$type" "$@" >/dev/null
}

echo "Creating fields"
create_field "Contact" TEXT
create_field "Opportunity" TEXT
create_field "Next follow-up" DATE
create_field "Last contact" DATE
create_field "Source" SINGLE_SELECT   --single-select-options "Cold outreach,Referral,Existing relationship,Craigslist"
create_field "Notes" TEXT
create_field "Estimated value" NUMBER

# A board view is convenient for moving leads through the Status pipeline.
# GitHub board views group new projects by Status by default.
gh api graphql   -F projectId="$PROJECT_ID"   -f query='mutation($projectId:ID!) {
    createProjectV2View(input:{
      projectId:$projectId,
      name:"Pipeline",
      layout:BOARD_LAYOUT
    }) {
      projectV2View { id name layout }
    }
  }' >/dev/null

echo
echo "Created GitHub Project #$PROJECT_NUMBER: $PROJECT_TITLE"
echo "Linked repository: $REPO"
echo "Open it with: gh project view $PROJECT_NUMBER --owner $OWNER --web"
echo
echo "Lead data is intentionally not stored in this public repository."
echo "Add prospects as draft items directly in the private GitHub Project."
