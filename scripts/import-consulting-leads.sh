#!/usr/bin/env bash
set -euo pipefail

# Import private consulting leads into an existing GitHub Project.
#
# Lead data stays in a local JSON file that should not be committed.
#
# Requirements:
#   - GitHub CLI (`gh`) authenticated with the `project` scope
#   - `jq`
#
# Optional environment variables:
#   OWNER=vbeffa
#   PROJECT_NUMBER=2
#   DATA_FILE=.private/consulting-leads.json
#   DRY_RUN=1

OWNER="${OWNER:-vbeffa}"
PROJECT_NUMBER="${PROJECT_NUMBER:-2}"
DATA_FILE="${DATA_FILE:-.private/consulting-leads.json}"
DRY_RUN="${DRY_RUN:-0}"

for cmd in gh jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "error: required command '$cmd' is not installed" >&2
    exit 1
  }
done

[[ -f "$DATA_FILE" ]] || {
  echo "error: lead data file not found: $DATA_FILE" >&2
  echo "Copy scripts/consulting-leads.example.json to $DATA_FILE and edit it first." >&2
  exit 1
}

jq -e '
  type == "array" and
  all(.[];
    (.title | type == "string" and length > 0) and
    (.status | type == "string" and length > 0)
  )
' "$DATA_FILE" >/dev/null || {
  echo "error: $DATA_FILE must be a JSON array whose entries have non-empty title and status fields" >&2
  exit 1
}

gh auth status >/dev/null

PROJECT_ID="$(
  gh project view "$PROJECT_NUMBER" --owner "$OWNER"     --format json --jq '.id'
)"

FIELDS_JSON="$(
  gh api graphql     -F login="$OWNER"     -F number="$PROJECT_NUMBER"     -f query='query($login:String!, $number:Int!) {
      user(login:$login) {
        projectV2(number:$number) {
          fields(first:100) {
            nodes {
              ... on ProjectV2Field { id name dataType }
              ... on ProjectV2SingleSelectField {
                id
                name
                options { id name }
              }
            }
          }
        }
      }
    }'     --jq '.data.user.projectV2.fields.nodes'
)"

field_id() {
  local name="$1"
  jq -r --arg name "$name" '.[] | select(.name == $name) | .id // empty' <<<"$FIELDS_JSON" | head -n 1
}

option_id() {
  local field_name="$1"
  local option_name="$2"
  jq -r     --arg field "$field_name"     --arg option "$option_name"     '.[] | select(.name == $field) | .options[]? | select(.name == $option) | .id // empty'     <<<"$FIELDS_JSON" | head -n 1
}

STATUS_FIELD_ID="$(field_id "Status")"
CONTACT_FIELD_ID="$(field_id "Contact")"
EMAIL_FIELD_ID="$(field_id "Email")"
PHONE_FIELD_ID="$(field_id "Phone")"
WEBSITE_FIELD_ID="$(field_id "Website")"
OPPORTUNITY_FIELD_ID="$(field_id "Opportunity")"
NEXT_FOLLOW_UP_FIELD_ID="$(field_id "Next follow-up")"
LAST_CONTACT_FIELD_ID="$(field_id "Last contact")"
SOURCE_FIELD_ID="$(field_id "Source")"
NOTES_FIELD_ID="$(field_id "Notes")"
ESTIMATED_VALUE_FIELD_ID="$(field_id "Estimated value")"

for required in   STATUS_FIELD_ID CONTACT_FIELD_ID EMAIL_FIELD_ID PHONE_FIELD_ID WEBSITE_FIELD_ID OPPORTUNITY_FIELD_ID NEXT_FOLLOW_UP_FIELD_ID   LAST_CONTACT_FIELD_ID SOURCE_FIELD_ID NOTES_FIELD_ID ESTIMATED_VALUE_FIELD_ID; do
  if [[ -z "${!required}" ]]; then
    echo "error: required project field is missing: $required" >&2
    exit 1
  fi
done

set_text_field() {
  local item_id="$1" field_id="$2" value="$3"
  [[ -n "$value" ]] || return 0
  gh project item-edit --id "$item_id" --project-id "$PROJECT_ID"     --field-id "$field_id" --text "$value" >/dev/null
}

set_date_field() {
  local item_id="$1" field_id="$2" value="$3"
  [[ -n "$value" ]] || return 0
  gh project item-edit --id "$item_id" --project-id "$PROJECT_ID"     --field-id "$field_id" --date "$value" >/dev/null
}

set_number_field() {
  local item_id="$1" field_id="$2" value="$3"
  [[ -n "$value" ]] || return 0
  gh project item-edit --id "$item_id" --project-id "$PROJECT_ID"     --field-id "$field_id" --number "$value" >/dev/null
}

set_select_field() {
  local item_id="$1" field_name="$2" field_id="$3" option_name="$4"
  [[ -n "$option_name" ]] || return 0

  local selected_option_id
  selected_option_id="$(option_id "$field_name" "$option_name")"
  if [[ -z "$selected_option_id" ]]; then
    echo "error: unknown '$field_name' option: $option_name" >&2
    exit 1
  fi

  gh project item-edit --id "$item_id" --project-id "$PROJECT_ID"     --field-id "$field_id" --single-select-option-id "$selected_option_id" >/dev/null
}

existing_items_json="$(
  gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --limit 1000 --format json
)"

count="$(jq 'length' "$DATA_FILE")"
for ((i = 0; i < count; i++)); do
  lead="$(jq -c ".[$i]" "$DATA_FILE")"
  title="$(jq -r '.title' <<<"$lead")"
  status="$(jq -r '.status' <<<"$lead")"
  contact="$(jq -r '.contact // ""' <<<"$lead")"
  email="$(jq -r '.email // ""' <<<"$lead")"
  phone="$(jq -r '.phone // ""' <<<"$lead")"
  website="$(jq -r '.website // ""' <<<"$lead")"
  opportunity="$(jq -r '.opportunity // ""' <<<"$lead")"
  next_follow_up="$(jq -r '.next_follow_up // ""' <<<"$lead")"
  last_contact="$(jq -r '.last_contact // ""' <<<"$lead")"
  source="$(jq -r '.source // ""' <<<"$lead")"
  notes="$(jq -r '.notes // ""' <<<"$lead")"
  estimated_value="$(jq -r '.estimated_value // ""' <<<"$lead")"

  duplicate_id="$(
    jq -r --arg title "$title" '.items[]? | select(.title == $title) | .id // empty'       <<<"$existing_items_json" | head -n 1
  )"

  if [[ -n "$duplicate_id" ]]; then
    echo "skip: '$title' already exists in project"
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "would add: $title [$status]"
    continue
  fi

  echo "adding: $title [$status]"
  item_id="$(
    gh project item-create "$PROJECT_NUMBER" --owner "$OWNER"       --title "$title" --format json --jq '.id'
  )"

  set_select_field "$item_id" "Status" "$STATUS_FIELD_ID" "$status"
  set_text_field "$item_id" "$CONTACT_FIELD_ID" "$contact"
  set_text_field "$item_id" "$EMAIL_FIELD_ID" "$email"
  set_text_field "$item_id" "$PHONE_FIELD_ID" "$phone"
  set_text_field "$item_id" "$WEBSITE_FIELD_ID" "$website"
  set_text_field "$item_id" "$OPPORTUNITY_FIELD_ID" "$opportunity"
  set_date_field "$item_id" "$NEXT_FOLLOW_UP_FIELD_ID" "$next_follow_up"
  set_date_field "$item_id" "$LAST_CONTACT_FIELD_ID" "$last_contact"
  set_select_field "$item_id" "Source" "$SOURCE_FIELD_ID" "$source"
  set_text_field "$item_id" "$NOTES_FIELD_ID" "$notes"
  set_number_field "$item_id" "$ESTIMATED_VALUE_FIELD_ID" "$estimated_value"
done

if [[ "$DRY_RUN" == "1" ]]; then
  echo "dry run complete; no project items were created"
else
  echo "import complete"
fi
