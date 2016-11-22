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

    def create_release(tag_name)
      release = @client.create_release(@repo, tag_name)
      release[:metadata] = {}
      release
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
      populate_releases_metadata(@client.releases(@repo))
    end

    def find_release(tag_name)
      populate_release_metadata(@client.release_for_tag(@repo, tag_name))
    end

    def update_release(release, text, verification)
      body = [release.body.to_s, text].join("\n\n")
      @client.update_release(release.url, body: [body + METADATA_DELIMITER + release.metadata.merge(verification).to_json].join("\n\n"))
    end

    private

    def populate_releases_metadata(releases)
      releases.map do |release|
        populate_release_metadata(release)
      end
    end

    def populate_release_metadata(release)
      metadata = release.body.to_s.split(METADATA_DELIMITER)
      release[:body] = metadata[0]
      release[:metadata] = metadata[1].present? ? JSON.parse(metadata[1]) : {}
      release
    end
  end
end
