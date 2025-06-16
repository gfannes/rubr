# Reusable Utilities By RUBR

- [/] Support for export to single file
	- `rake export[cli,slice]`
	- Parse @import statements
		- [x] Replace std with a single global import
		- [ ] Add recursive local imports that are not part of the mod list
	- [x] Drop tests
		- [ ] Move `const ut = std.testing` into tests

## &ansi ANSI code support

### Func
- Remove codes

### CLI &cli
- Remove codes from single file
- Remove codes from tree
	- Take `.gitignore` into account
- Convert naft annotations into ANSI colors
