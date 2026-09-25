# Marketing records

Craigslist ads are stored as structured directories so exact ad copy, metadata, publication history, and performance data remain separate.

For each ad:

- `body.txt` — exact current ad body text; Git history tracks wording changes.
- `metadata.yaml` — title, category, delivery/location settings, and ordered images.
- `postings.csv` — one row per newly published or reposted ad. `commit_sha` points to a Git commit containing the matching creative snapshot. For postings that predate this structure, the snapshot may have been reconstructed later and should be noted.
- `revisions.csv` — optional; records edits to an already-published posting.
- `stats.csv` — dated impression/view snapshots.
- `outcomes.csv` — anonymized lead/job outcomes.

Do not make a new body file for a simple repost. Create a separate ad directory only for a materially different creative or positioning experiment.
