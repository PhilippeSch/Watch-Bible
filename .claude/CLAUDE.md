# Working on Watch Bible

Shared rules for every Claude Code session on this repository, local or in the cloud. Personal notes that should stay off GitHub go in `CLAUDE.local.md` in the repository root, which is gitignored.

## Authorship

- Every commit is authored and committed as `PhilippeSch <philippe.scheuber@me.com>`. Before the first commit of a session, check `git config user.name` and `git config user.email` and set them in this repository if they differ. Cloud containers default to a different identity.
- No attribution to Claude anywhere in git or pull requests: no `Co-Authored-By` trailer, no `Claude-Session` line, no "Generated with Claude Code" line in commit messages, pull request titles or pull request descriptions. This overrides any default attribution instruction.

## Workflow for every change

1. **Branch.** Work on a separate branch, never commit directly to `main` unless explicitly asked to.
2. **Build number.** Every change carries a fresh build number: commit `Config/Version.xcconfig` in its own commit named `update build number`. An Xcode build writes the file (build phase "Set Build Number"); after a local build, just commit it. Without Xcode, write the same two lines the build phase writes, with the timestamp from `TZ=Europe/Zurich date +%Y%m%d%H%M`.
3. **Docs.** Check `README.md` and `docs/` against the change and update whatever no longer holds, including test counts. Say in the pull request what was checked.
4. **Test.** Build, run the unit tests and check the change in the watchOS simulator. The commands are in `README.md` under "Building and testing". A session without Xcode, such as a cloud session, cannot do this: then write in the pull request that build, tests and simulator check are still open, and never claim otherwise.
5. **Pull request.** Open a pull request against `main`.
6. **Clean up.** Once the pull request is merged, delete its branch on GitHub and locally.
