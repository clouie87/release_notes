module ReleaseNotes
  class ChangelogFile

    attr_accessor :server_name, :file_path

    def initialize(server_name, file_path)
      @server_name = server_name
      @file_path = file_path
      @file = File.open(file_path, 'a+') # need to create it if it doesn't already exist
    end

    def metadata
      find_last_metadata
    end

    def update_changelog(changelog_text, verification_text)
      original_file = "./#{file_path}"
      new_file = original_file + '.new'

      open(new_file, 'w') do |f|
       f.puts [changelog_header,changelog_text].join("\n\n") + "\n\n"
       f.puts verification_text.to_json
       f.puts "\n\n"
       File.foreach(original_file) do |li|
         f.puts li
       end
      end

      File.rename(original_file, original_file + '.old')
      File.rename(new_file, original_file)
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
