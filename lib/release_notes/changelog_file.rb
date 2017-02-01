require "base64"

module ReleaseNotes
  class ChangelogFile

    attr_accessor :server_name, :file_path

    def initialize(server_name, file_path, api)
      @server_name = server_name
      @file_path = file_path
      @file = File.open(file_path, 'a+') # need to create it if it doesn't already exist
      @api = api
    end

    def update(text, new_sha, old_sha, prs)
      update_changelog(ChangelogParser.update_changelog(text, new_sha, old_sha, server_name))
      push_changelog_to_github(prs)
      remove_files
    end

    def metadata
      find_last_metadata
    end

    def update_changelog(text)
      original_file = "./#{file_path}"
      new_file = original_file + '.new'

      open(new_file, 'w') do |f|
        f.puts text
        f.puts old_changelog_content
      end

      File.rename(original_file, original_file + '.old')
      File.rename(new_file, original_file)
    end

    def push_changelog_to_github(prs)
      changelog_content = File.read(@file_path)
      if github_file.present?
        @api.update_changelog(github_file, ChangelogParser.create_summary(prs, server_name), changelog_content)
      else
        @api.create_content(@file_path, changelog_content)
      end
    end

    def remove_files
      File.delete(@file_path)
      File.delete("#{@file_path}.old")
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
      File.open(file_path, "r") do |f|
        text = f.read
        text[/{"#{server_name}"(.*)/]
      end
    end
  end
end
