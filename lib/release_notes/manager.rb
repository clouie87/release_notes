require 'active_support/all'

module ReleaseNotes
  class Manager

    attr_accessor :server_name

    def initialize(repo, token, server_name)
      @repo = repo
      @api = GithubAPI.new(repo, token)
      @server_name = server_name
      @changelog = ChangelogFile.new(server_name, @api)
    end

    def create_changelog_from_branch(branch, old_sha: nil)
      new_sha = branch_sha(branch)
      create_changelog_from_sha(new_sha, old_sha: old_sha)
    end

    def create_changelog_from_tag(tag_name, old_sha: nil)
      new_tag = @api.find_tag_by_name(tag_name)
      create_changelog_from_sha(new_tag.object.sha, old_sha: old_sha)
    end

    def create_changelog_from_sha(new_sha, old_sha: nil)
      old_sha ||= last_commit_sha
      prs = texts_from_merged_pr(new_sha, old_sha) if old_sha

      @changelog.prepare(new_sha, old_sha, prs)
    end

    def push_changelog_to_github(content, *repos)
      repos = Array(@repo) if repos.empty?
      changelog_body = @changelog.prepend_to_existing(content)
      repos.flatten.compact.each do |repo|
        @changelog.push_to_github(repo, content[:summary], changelog_body)
      end
    end

    def texts_from_merged_pr(new_sha, old_sha)
      commits_between_tags = @api.find_commits_between(old_sha, new_sha)
      matching_pr_commits(commits_between_tags, old_sha).map { |commit| {number: commit.number, title: commit.title, text: commit.body.squish } }
    end

    private

    def branch_sha(branch)
      @api.branch(branch).commit.sha
    end

    def last_commit_sha
      ChangelogParser.last_commit(server_name, @changelog.metadata)
    end

    # find the prs that contain the commits between two tags
    def matching_pr_commits(commits, old_sha)
      @api.merged_pull_requests(old_sha).select do |pr|
        (@api.find_pull_request_commits(pr.number).map(&:sha) - commits.map(&:sha)).empty?
      end
    end
  end
end
