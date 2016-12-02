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
After a new tag is created, pass the ReleaseNotes Manager the server name of the deployment and the new tag name:
```ruby
ReleaseNotes::Manager.new('your repo', 'access token').publish_release('server name', 'new tag name')
```
Then on Github, go to your releases to view your changelog.
