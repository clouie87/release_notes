module ReleaseNotes
  class ChangelogFile

    attr_accessor :server_name, :file_path

    def initialize(server_name, file_path, api)
      @server_name = server_name
      @file_path = file_path
      @file = File.open(file_path, 'a+') # need to create it if it doesn't already exist
      @api = api
    end

    def metadata
      find_last_metadata
    end

    def update_changelog(changelog_text, new_sha, old_sha)
      original_file = "./#{file_path}"
      new_file = original_file + '.new'

      open(new_file, 'w') do |f|
        f.puts [changelog_header,changelog_text].join("\n\n") + "\n\n" + release_verification_text(new_sha, old_sha).to_json + "\n\n"
        f.puts File.read(original_file)
      end

      File.rename(original_file, original_file + '.old')
      File.rename(new_file, original_file)
    end

    def push_changelog_to_github
      changelog_content = File.read(@file_path)
      file = @api.find_content(@file_path)
      if file.present?
        @api.update_changelog(file, changelog_content)
      else
        @api.create_content(@file_path, changelog_content)
      end
    end

    def release_verification_text(new_sha, old_sha)
      {"#{server_name}": {old_sha: old_sha, commit_sha: new_sha}}
    end

    private

    def find_last_metadata
      File.open(file_path, "r") do |f|
        text = f.read
        text[/{"#{server_name}"(.*)/]
      end
    end

    def changelog_header
      "## Deployed to: #{server_name} (#{Time.now.utc.asctime})"
    end
  end
end
