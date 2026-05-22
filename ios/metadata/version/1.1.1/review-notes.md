# App Review Notes — v1.1.1

## Reviewer Test Account
Email: review@colossusstrategies.com
Password: (set in ASC Demo Account field)
Race pre-assigned: Ohio HD-65 (Trumbull County). District tab will render with live data.

## What's New in 1.1.1
A "District" tab adds a Voter Data module for the candidate's own race. It surfaces public Ohio Secretary of State voter file data (registered voters, party affiliation, turnout history, precinct rollups) scoped to the candidate's district only, via Postgres RLS.

## Data Source & Legal Basis (5.1.1 / 5.1.2)
- Source: Ohio Secretary of State public voter file, published at https://www6.ohiosos.gov/ords/f?p=VOTERFTP:HOME
- Legal basis: Ohio Revised Code §3503.38 permits campaign and election-related use of the voter file. Commercial solicitation is prohibited.
- We do not sell, share, or use the data for commercial solicitation. Use is limited to verified candidates for their own race.
- First access to any voter-data screen requires the user to acknowledge an in-app data-use notice. Acknowledgment is stored on the user profile and every query is written to an audit table.

## Access Scope
- Each candidate can only query voters whose district matches the race they selected during onboarding. Enforced server-side via Postgres Row-Level Security, not in the client.
- The reviewer account is scoped to OH HD-65 / Trumbull County, so the District tab is fully populated.

## Privacy
- No new data is collected from end users beyond what 1.1.0 declared.
- Voter records are read-only; users cannot edit or upload personal data.
- PrivacyInfo.xcprivacy is unchanged from 1.1.0.

## Known States Reviewer May See
- If the reviewer signs up fresh without race selection, the District tab shows an onboarding prompt to complete race setup. This is intentional.
- If voter ingest has not run for the test account's county yet, the dashboard shows "AWAITING FIRST INGEST" — the reviewer account is pre-seeded so this should not happen.

## Contact
support@colossusstrategies.com
