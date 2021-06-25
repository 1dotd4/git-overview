# Specification

## Data

We would like to answer the following questions:
- What are the last thing people did?
- What is the situation of the project, where are people working most?
- For a specific person, what are his last steps on the whole project?

To answer those questions we need a database structured as follow.

- Authors: **author**, nick, email
- Repositories: **repository**, name, url
- Branches: **branch**, repository
- BranchLabels: **group**, name
- GroupedBranches: **_branch_**, **_group_**
- Commits: **hash**, **repository**, _branch_, _author_, comment, timestamp

Note: **primary keys** are in bold, _external keys_ are in italic.

