# IAM Lifecycle (PowerShell)

Identity & Access Management (IAM) automation project.  
It simulates an Active Directory/Entra environment using CSV files as the “directory.”

## What it does

- **Onboarding**: Bulk-create users from `data/new_hires.csv`, assign them to groups, generate temporary passwords, and log actions.
- **Offboarding**: Disable accounts listed in `data/offboarding.csv` and remove all group memberships.
- **Access Review (Compliance)**:
  - “Who has what” (user → group mapping)
  - **Inactive users** (no login for N days, configurable)
  - **Toxic combinations** (conflicting group memberships)

Outputs both **CSV and HTML reports** in `./reports`.

## Tech

- **PowerShell 7 (cross-platform)**
- **CSV** as a simple, portable data store
- **HTML** for human-readable reports








## How it works (flow)

1. **Seed data**  
   - Fill `data/groups.csv` with available groups.  
   - Add new hires / offboarding candidates as needed.

2. **Onboarding (`Invoke-Onboarding.ps1`)**  
   - Reads `data/new_hires.csv`.  
   - Creates each user:
     - Generates UPN like `jsmith@corp.local` (first initial + last name).
     - Creates user row with a temporary password.
     - Adds user to their `primaryGroup`.  
   - Updates:
     - `data/users.csv` (users directory)
     - `data/memberships.csv` (group links)
   - Produces **onboarding** report (CSV + HTML).

3. **Offboarding (`Invoke-Offboarding.ps1`)**  
   - Reads `data/offboarding.csv`.  
   - For each user:
     - Removes all group memberships.
     - Sets status to `Disabled` in `data/users.csv`.  
   - Produces **offboarding** report (CSV + HTML).

4. **Access Review (`Invoke-AccessReview.ps1`)**  
   - Aggregates data from users, groups, memberships.  
   - Generates three reports:
     - **Who Has What**: user → group mapping.
     - **Inactive Users**: flags users with no login for ≥ `DormantDaysThreshold` (from `config.psd1`, using `login_activity.csv`).
     - **Toxic Combinations**: flags users whose groups match any pair in `toxic_combos.csv`.  
   - Produces all three reports (CSV + HTML).

5. **Reports**  
   - Saved in `./reports/` with timestamps, e.g., `onboarding_YYYYMMDD_HHMM.html`.  
   - Open HTML files in a browser for review.
