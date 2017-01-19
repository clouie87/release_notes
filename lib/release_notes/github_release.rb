module ReleaseNotes
  class GithubRelease

    attr_accessor :server_name

    def initialize(server_name, api)
      @server_name = server_name
      @api = api
    end

    def update_release_notes(new_tag, old_sha, text: nil, verification_text: nil)
      release = find_current_release(new_tag.tag)

      if release.metadata[server_name]
        puts "Release Notes are already updated for Server #{server_name}"
        return release
      end

      @api.update_release(release, [release_notes_headers(server_name, old_sha), text].join("\n\n"), verification_text)
    end

    private

    # find which release this server was last deployed to
    def find_latest_release(server_name: nil)
      return releases.find { |r| r.metadata.keys.include?(server_name.to_s) } if server_name
    end

    def find_current_release(tag_name)
      @api.find_release(tag_name)
    rescue Octokit::NotFound
      @api.create_release(tag_name)
      @api.find_release(tag_name)
    end

    def releases
      @api.releases
    end

    def release_notes_headers(server_name, old_sha)
      changes = "Changes Since: Tag " if old_sha
      ["## Deployed to: #{server_name} (#{Time.now.utc.asctime})", "### " + changes.to_s + old_sha]
    end
  end
end
