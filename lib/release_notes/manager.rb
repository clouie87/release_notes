require 'active_support/all'

module ReleaseNotes
  class Manager

    attr_accessor :server_name

    def initialize(repo, token, server_name, changelog_file: "#{server_name}_changelog.md")
      @api = GithubAPI.new(repo, token)
      @changelog_file = changelog_file
      @server_name = server_name
      @changelog = ChangelogFile.new(server_name, changelog_file, @api)
    end

    def create_changelog_from_branch(branch, old_sha: nil, type: :git_changelog)
      new_sha = branch_sha(branch)
      create_changelog_from_sha(new_sha, old_sha, type)
    end

    def create_changelog_from_tag(tag_name, old_sha: nil, type: :git_changelog)
      new_tag = @api.find_tag_by_name(tag_name)
      create_changelog_from_sha(new_tag.object.sha, old_sha, type)
    end

    def create_changelog_from_sha(new_sha, old_sha, type)
      old_sha ||= ChangelogParser.last_commit(server_name, @changelog.metadata)

      prs = texts_from_merged_pr(new_sha, old_sha) if old_sha
      text = changelog_body(old_sha, prs)
      content = @changelog.try(type)

      @changelog.update_changelog(text, new_sha, old_sha, content: content)
      @changelog.push_changelog_to_github(prs)
    end

    private

    def branch_sha(branch)
      @api.branch(branch).commit.sha
    end

    def changelog_body(old_sha, prs)
      old_sha.present? ? ChangelogParser.assemble_changelog(prs) : "First Deploy"
    end

    def texts_from_merged_pr(new_sha, old_sha)
      commits_between_tags = @api.find_commits_between(old_sha, new_sha)
      matching_pr_commits(commits_between_tags, old_sha).map { |commit| {number: commit.number, title: commit.title, text: commit.body.squish } }
    end

    # find the prs that contain the commits between two tags
    def matching_pr_commits(commits, old_sha)
      @api.merged_pull_requests(old_sha).select do |pr|
        (@api.find_pull_request_commits(pr.number).map(&:sha) - commits.map(&:sha)).empty?
      end
    end
  end
end
