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

    def get_commits_between(commit_old_sha, commit_new_sha)
      @client.compare(@repo, commit_old_sha, commit_new_sha).commits
    end

    def get_merged_pull_requests(commits)
      commit_messages = commits.pluck(:commit).pluck(:message)
      pull_request_ids = get_pull_request_ids(commit_messages)

      pull_request_ids.map do |id|
        @client.pull_request(@repo, id, state: 'closed')
      end
    end

    def get_pull_request_ids(commit_messages)
      commit_messages.map do |message|
        Regexp.last_match(1) if message.match(/Merge pull request #(\d*).*/)
      end.compact
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

    def branch(branch)
      @client.branch(@repo, branch)
    end

    def find_content(changelog_file, repo)
      repo ||= @repo
      @client.contents(repo, path: changelog_file)
    rescue Octokit::NotFound
      return nil
    end

    def update_changelog(repo, file, summary, changelog_content, branch: "master")
      @client.update_contents(repo, file.path, summary, file.sha, changelog_content)
    end

    def create_content(repo, file, changelog_content, message: "Creating Changelog")
      @client.create_content(repo, file, message, changelog_content)
    end
  end
end
