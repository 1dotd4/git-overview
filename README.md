# Git Overview
Save time on conflicts

For developers with many repositories who need to track many repositories at once to see where other are working,
the _git-overview is a simple overview of many git repositories_ that show in an organized way the latest changes of tracked repositories.
Unlike git, this program aggregates multiple changes from many repositories in a simple web based dashboard.

## Main features
- User status and current working branch and repository.
- All user commits in one place sorted by time:
	- filter by repositories and users;
  - filter commits before and after a selected commit temporally for the selected repository;
  - filter commits before and after a selected commit in the same tree;

## Other features
- No JavaScript.
- Desktop, tablet and mobile view (Bootstrap).
- Single program for importing repository and standalone server.
- Portable S-expression database for data and configuration.

## Running
- Import repositories with `git-overview --import /path/to/git/repository`.
- Run the server with `git-overview --serve`.

## Help
- man pages (TBD)

## Compiling
- Install [chicken scheme](//call-cc.org).
- Install dependencies: `chicken-install args combinators spiffy srfi-1 sxml-serializer`.
- Compile with `csc -static go.scm`.

Notes:
- OpenBSD has `chicken-csc` instead of `csc`.

