module ReleaseNotes
  class ChangelogParser

    INCLUDE_PR_TEXT = "- [x] Include this PR in the changelog".freeze
    END_STRING = /#\D\S/

    def self.assemble_changelog(prs)
      changelog_prs = prs.select { |pr| pr if pr[:text].include?(INCLUDE_PR_TEXT) }
      return "No Closed PRS" if changelog_prs.empty?
      ["#### Closed PRS:", changelog_prs_text(changelog_prs)].join("\n\n")
    end

    def self.last_commit(server_name, metadata)
      return nil unless metadata
      metadata = JSON.parse(metadata)
      metadata[server_name]["commit_sha"]
    end

    private

    def self.changelog_prs_text(prs)
      prs.map do |pr|
        [header_text(pr[:number], pr[:title]), changelog_text(pr[:text])].join("\n\n")
      end
    end

    def self.changelog_summary(prs)
      prs.map do |pr|
        [header_text(pr[:number], pr[:title]), "Closes:", section_text(pr[:text], "# Closes")].join(' ')
      end
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
