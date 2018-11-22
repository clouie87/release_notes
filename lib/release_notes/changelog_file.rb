require "base64"

module ReleaseNotes
  class ChangelogFile

    attr_accessor :server_name, :file_path

    def initialize(server_name, api)
      @file_path = "#{server_name.downcase.parameterize.snakecase}_changelog.md"
      @server_name = server_name
      @api = api
    end

    def update(text, new_sha, old_sha, prs)
      summary = ChangelogParser.create_summary(prs, server_name)
      changelog_content = ChangelogParser.update_changelog(text, new_sha, old_sha, server_name)
      push_changelog_to_github(changelog_content, summary)
    end

    def metadata
      find_last_metadata
    end

    def push_changelog_to_github(changelog_content, summary)
      if github_file.present?
        content = changelog_content + old_changelog_content
        @api.update_changelog(github_file, summary, content)
      else
        @api.create_content(@file_path, changelog_content)
      end
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
