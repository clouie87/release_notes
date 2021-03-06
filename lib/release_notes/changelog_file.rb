require "base64"

module ReleaseNotes
  class ChangelogFile

    attr_accessor :server_name, :file_path

    def initialize(server_name, api)
      @file_path = "#{server_name.downcase.parameterize.underscore}_changelog.md"
      @server_name = server_name
      @api = api
    end

    def prepare(new_sha, old_sha, prs)
      { summary: ChangelogParser.prepare_changelog_summary(server_name, prs),
        body: ChangelogParser.prepare_changelog_body(new_sha, old_sha, server_name, prs) }
    end

    def prepend_to_existing(changelog)
      return changelog[:body] unless github_file.present?
      changelog[:body] + old_changelog_content
    end

    def push_to_github(repo, summary, body)
      file = github_file(repo)
      if file.present?
        @api.update_changelog(repo, file, summary, body)
      else
        @api.create_content(repo, @file_path, body)
      end
    end

    def metadata
      find_last_metadata
    end

    private

    def github_file(repo = nil)
      @api.find_content(@file_path, repo)
    end

    def find_last_metadata
      return nil unless old_changelog_content.present?
      old_changelog_content[/{"#{server_name}"(.*)/]
    end

    def old_changelog_content
      return nil unless github_file.present?
      Base64.decode64(github_file.content).force_encoding("UTF-8")
    end
  end
end
