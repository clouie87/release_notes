require "base64"

module ReleaseNotes
  class ChangelogFile

    attr_accessor :server_name, :file_path

    def initialize(server_name, api)
      @file_path = "#{server_name.downcase.parameterize.snakecase}_changelog.md"
      @server_name = server_name
      @api = api
    end

    def prepare(new_sha, old_sha, prs)
      { summary: ChangelogParser.prepare_changelog_summary(server_name, prs),
        body: ChangelogParser.prepare_changelog_body(new_sha, old_sha, server_name, prs) }
    end

    def push_to_github(changelog)
      if github_file.present?
        changelog_body = changelog[:body] + old_changelog_content
        @api.update_changelog(github_file, changelog[:summary], changelog_body)
      else
        @api.create_content(@file_path, changelog)
      end
    end

    def metadata
      find_last_metadata
    end

    private

    def github_file
      @api.find_content(@file_path)
    end

    def old_changelog_content
      return nil unless github_file.present?
      Base64.decode64(github_file.content).force_encoding("UTF-8")
    end

    def find_last_metadata
      return nil unless old_changelog_content.present?
      old_changelog_content[/{"#{server_name}"(.*)/]
    end
  end
end
