require 'active_support/all'

module ReleaseNotes
  class Manager

    attr_accessor :server_name

    def initialize(repo, token, server_name, changelog_file: "#{server_name}_changelog.md")
      @api = GithubAPI.new(repo, token)
      @changelog_file = changelog_file
      @server_name = server_name
      @changelog = ChangelogFile.new(server_name, changelog_file)
    end

    def create_changelog_from_branch(branch)
      new_sha = branch_sha(branch)
      create_changelog_from_sha(new_sha)
    end

    def create_changelog_from_tag(tag_name)
      new_tag = @api.find_tag_by_name(tag_name)
      create_changelog_from_sha(new_tag.object.sha)
    end

    def create_changelog_from_sha(new_sha)
      old_sha = ChangelogParser.last_commit(server_name, @changelog.metadata)
      text = changelog_body(new_sha, old_sha)
      verification_text = @changelog.release_verification_text(new_sha, old_sha)

      changelog_content = @changelog.update_changelog(text, verification_text)
      update_github_changelog(changelog_content)
      return changelog_content
    end

    def update_github_changelog(changelog_content)
      file = @api.find_content(@changelog_file)
      if file.present?
        @api.update_changelog(file, changelog_content)
      else
        @api.create_content(@changelog_file, changelog_content)
      end
    end

    private

    def branch_sha(branch)
      @api.branch(branch).commit.sha
    end

    def changelog_body(new_sha, old_sha)
      old_sha.present? ? ChangelogParser.assemble_changelog(texts_from_merged_pr(new_sha, old_sha)) : "First Deploy"
    end

    def texts_from_merged_pr(new_sha, old_sha)
      commits_between_tags = @api.find_commits_between(old_sha, new_sha)
      matching_pr_commits(commits_between_tags).map { |commit| {number: commit.number, title: commit.title, text: commit.body.squish } }
    end

    # find the prs that contain the commits between two tags
    def matching_pr_commits(commits)
      @api.merged_pull_requests.select do |pr|
        (@api.find_pull_request_commits(pr.number).map(&:sha) - commits.map(&:sha)).empty?
      end
    end
  end
end
