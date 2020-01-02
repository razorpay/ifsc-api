## Release Guide

1. Go to the latest release on github.com/razorpay/ifsc/releases
2. Download and extract the by-banks.tar.gz file into the data directory
3. Ensure that a new gem release has been made: https://rubygems.org/gems/ifsc
4. Run a dependency update (`bundle update && bundle update --gemfile Gemfile.build`)
5. Check the `ifsc` gem version (`grep ifsc Gemfile.lock`)
6. File a PR with these changes
7. Review/Approve/Merge the PR
8. Tag the master to the new release.

## Gemfile splits

During the docker build, we run an independent script (`init.rb`), which doesn't require most dependencies, only
redis. This is part of a multi-stage-docker-build (See `Dockerfile`). The dependency for this special bundle
are maintained in `Gemfile.build / Gemfile.build.lock`.

- `Gemfile`: Actual application Gemfile, used by the web app
- `Gemfile.build`: CI Gemfile, only used during build
