## Release Notes

**Release Notes** is a gem that makes it easy to track updates to servers between deployments. Release Notes compiles the text from your projects merged pull requests to keep your team informed about which changes have been deployed to which servers.

Key features:
- gives direction to beta user testing to help uncover bugs
- relays to dev and non-devs which problems have been solved and deployed

### Install
Add Release Notes to your Gemfile:
``` ruby
gem 'release_notes', :github => 'clouie87/release_notes'
```

### Setup
1. This gem parses your project’s pull requests based on keywords. Create a new file that templates your pull requests:
  ```markdown
  ### Changes
    - *Give enough detail that testers can evaluate any changes*
    -
    -

  ### Closes
  *Comma separated list of closed issue links*

  ### Special Handling
    - [x] Include this PR in the changelog
  ```
  *Note*: When 'Include this PR in the changelog' is unchecked, the release notes will not update changes from that pull request.
2. Create an [OAuth token](https://developer.github.com/v3/oauth/) to access your repo through the Github API. You can [create access tokens in GitHub Account Settings](https://help.github.com/articles/creating-an-access-token-for-command-line-use/).

### Usage
1. Create a changelog:
Pass the ReleaseNotes Manager your repo, the access_token and server name. There are methods that can be called to create the changelog:

```ruby
release_manager = ReleaseNotes::Manager.new('github_user/your_repo', 'access token', 'server_name')

# create changelog by branch
changelog = release_manager.create_changelog_from_branch('branch_name')

# create changelog by tag
changelog = release_manager.create_changelog_from_tag('tag_name')

# create changelog by sha
changelog = release_manager.create_changelog_from_sha('sha')
```

2. Push the changelog to Github:
Once the changelog has been created, you can push it to Github. By default, the changelog will be saved to the repo initialized in the ReleaseNotes Manager. To save the changelog on other repos, pass the name of **all** the repos you would like the changelog to appear in, including the initialized repo.

``` ruby
# Default
release_manager.push_changelog_to_github(changelog)

# Pass in repo names where you want the changelog to be created
release_manager.push_changelog_to_github(changelog, 'github_user/your_repo', 'github_user/another_repo')

```

Then on Github, a file will be added to your project `{server_name}_changelog.md`

### Future Plans:
- allow the changelog to be emailed or printed.
