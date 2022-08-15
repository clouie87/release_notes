module ReleaseNotes
  class ChangelogParser

    INCLUDE_PR_TEXT = "[x] Include this PR in the changelog".freeze
    END_STRING = /#\W\S/

    def self.prepare_changelog_body(new_sha, old_sha, server_name, prs)
      header_text = "## #{changelog_header(server_name)}"
      changelog_body = body_text(old_sha, prs)
      metadata_content = "[meta_data]: #{release_verification_text(new_sha, old_sha, server_name).to_json}\n\n"

      [header_text, changelog_body, metadata_content].join("\n\n")
    end

    def self.prepare_changelog_summary(server_name, prs)
      [changelog_header(server_name), changelog_summary(prs).join("\n\n")].join("\n\n")
    end

    def self.last_commit(server_name, metadata)
      return nil unless metadata
      metadata = JSON.parse(metadata)
      metadata[server_name]["commit_sha"]
    end

    private

    def self.body_text(old_sha, prs)
      return "First Deploy" unless old_sha.present?

      changelog_prs = changelog_prs(prs)
      return "No Closed PRS" if changelog_prs.empty?
      ["#### Closed PRS:", changelog_prs_text(changelog_prs)].join("\n\n")
    end

    def self.changelog_summary(prs)
      changelog_prs = changelog_prs(prs)
      return ["No Closed PRS"] if changelog_prs.empty?
      changelog_prs.map do |pr|
        ["Closed PR: ##{pr[:number]} - #{pr[:title]}", "Closes:", section_text(pr[:text], "# Closes")].join(' ')
      end
    end

    def self.changelog_prs(prs)
      return [] unless prs
      prs.select { |pr| pr[:text]&.include?(INCLUDE_PR_TEXT) }
    end

    def self.changelog_prs_text(prs)
      prs.map do |pr|
        [header_text(pr[:number], pr[:title]), changelog_text(pr[:text])].join("\n\n")
      end
    end

    def self.changelog_header(server_name)
      "Deployed to: #{server_name} (#{Time.now.strftime("%a %b %e %Y at %T")})"
    end

    def self.release_verification_text(new_sha, old_sha, server_name)
      {"#{server_name}": {old_sha: old_sha, commit_sha: new_sha}}
    end

    def self.header_text(number, title)
      [ "###### ##{number}", title ].join(' - ')
    end

    def self.changelog_text(text)
      changes = section_text(text, "# Changes").presence || "No Changes included in the log"
      closes = section_text(text, "# Closes").presence || "Nothing Closed"

      ["###### Changes\n\r#{changes}", "\n###### Closes:\n#{closes}"]
    end

    def self.section_text(text, begin_string)
      text.tap do |text|
        text.gsub!("- ", "\n- ")
        return text[/#{begin_string}(.*?)#{END_STRING}/m, 1] || text[/#{begin_string}(.*)$/m, 1]
      end
    end
  end
end
