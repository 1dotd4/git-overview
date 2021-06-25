# go
Git overview of many repositories.

## Features
- shows the last update on repository and branch for each contributor;
- shows the last update for each contributor on grouped branches on each repositories
	- table with each row a repository
	- each column is a group of branches (ie. `features/*`) that are gathered together with a regular expression
	- more people can be working on the same group of branches
- show last updates of all repository and branches for a specific contributor
	- filter by repositories and branches

## Running

- Install [chicken scheme](//call-cc.org)
- Install dependencies: `chicken-install spiffy sxml-serializer`
- Run the server: `csi go.scm`

Notes:
- OpenBSD has `chicken-csi` instead of `csi`

## Compiling

- See running
- Compile with `csc -static go.scm`
