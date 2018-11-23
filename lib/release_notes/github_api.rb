require 'octokit'

module ReleaseNotes
  class GithubAPI
    include Octokit

    METADATA_DELIMITER = "\n\nRelease Metadata: (do not edit)".freeze

    def initialize(repo, token)
      @repo = repo
      @client = Octokit::Client.new(access_token: token)
      @client.login
      @client.auto_paginate = true
    end

    def find_commits_between(commit_old_sha, commit_new_sha)
      @client.compare(@repo, commit_old_sha, commit_new_sha).commits
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

    def merged_pull_requests(old_sha)
      closed_pull_requests_between(old_sha).select(&:merged_at?)
    end

    def closed_pull_requests_between(old_sha)
      closed_pull_requests.take_while do |pr|
        pr.updated_at > last_commit_date(old_sha)
      end
    end

    def last_commit_date(old_sha)
      @client.commit(@repo, old_sha).commit.committer.date
    end

    def closed_pull_requests
      @client.pull_requests(@repo, state: 'closed', sort: 'updated', direction: "desc")
    end

    def find_pull_request_commits(pr)
      @client.pull_request_commits(@repo, pr)
    end

    def branch(branch)
      @client.branch(@repo, branch)
    end

    def find_content(changelog_file)
      @client.contents(@repo, path: changelog_file)
    rescue Octokit::NotFound
      return nil
    end

    def update_changelog(repo, file, summary, changelog_content, branch: "master")
      @client.update_contents(repo, file.path, summary, file.sha, changelog_content, branch: "master")
    end

    def create_content(repo, file, changelog_content, message: "Creating Changelog", branch: "master")
      @client.create_content(repo, file, message, changelog_content, branch: branch)
    end
  end
end
