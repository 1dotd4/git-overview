# Git Overview
A simple overview of many git repositories.

## Main features
- User status and current working branch and repository.
- User status on each repository:
	- every repository is a row in a table;
	- each column is a group of branches (ie. `features/*`) that are gathered together with a regular expression;
	- more people can be working on the same group of branches.
- All user commits in one place sorted by time:
	- filter by repositories and branches;
  - show the work of multiple users on selected repositories.

## Other features
- No JavaScript.
- Desktop, tablet and mobile view (Bootstrap).
- Single program for importing repository and standalone server.
- Webhook integration (TBD).
- Portable SQLite3 database for data and configuration.

## Running

- Import repositories with `git-overview --import /path/to/git/repository`.
- Run the server with `git-overview --serve`.

## Help
- man pages (TBD)

## Compiling

- Install [chicken scheme](//call-cc.org).
- Install dependencies: `chicken-install args spiffy sxml-serializer sql-de-lite`.
- Compile with `csc -static go.scm`.

Notes:
- OpenBSD has `chicken-csc` instead of `csc`.
- On OpenBSD you may need to manually compile the sqlite3 library by adding `-I/usr/local/include/` to the compile command.

