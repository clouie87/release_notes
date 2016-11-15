require 'octokit'

module ReleaseNotes
  class GithubAPI
    include Octokit

    def initialize(repo, token)
      @repo = repo
      @client = Octokit::Client.new(access_token: token)
      @client.login
      @client.auto_paginate = true
    end

    def find_commits_between(commit_old_sha, commit_new_sha)
      @client.compare(@repo, commit_old_sha, commit_new_sha).commits
    end

    def create_release(tag_name)
      @client.create_release(@repo, tag_name)
    end

    def find_tag_by_name(tag_name)
      tag_sha = find_tag_ref(tag_name).object.sha
      find_tag(tag_sha)
    end

    def find_tag_ref(tag)
      @client.ref(@repo, 'tags/' + tag)
    end

    def find_tag(tag_sha)
      @client.tag(@repo, tag_sha)
    end

    def merged_pull_requests
      closed_pull_requests.select(&:merged_at?)
    end

    def closed_pull_requests
      @client.pull_requests(@repo, state: 'closed')
    end

    def find_pull_request_commits(pr)
      @client.pull_request_commits(@repo, pr)
    end

    def releases
      @client.releases(@repo)
    end

    def find_release(tag_name)
      @client.release_for_tag(@repo, tag_name)
    end

    def update_release(release, text)
      @client.update_release(release.url, body: text)
    end
  end
end
