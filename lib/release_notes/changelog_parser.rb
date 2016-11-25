module ReleaseNotes
  class ChangelogParser

    INCLUDE_PR_TEXT = "- [x] Include this PR in the changelog".freeze
    END_STRING = /#\D\S/

    def self.assemble_changelog(pr_texts)
      change_texts = pr_texts.select { |text| text if text.include?(INCLUDE_PR_TEXT) }
      changelog_text(change_texts)
    end

    private

    def self.changelog_text(texts)
      changes = section_text(texts, "# Changes").join("\n").presence || "No Changes included in the log"
      closes = section_text(texts, "# Closes").join(',').presence || "Nothing Closed"

      ["### Changes\n#{changes}", "### Closes\n#{closes}"]
    end

    def self.section_text(texts, begin_string)
      texts.map do |text|
        text.gsub!("- ", "\n- ")
        text[/#{begin_string}(.*?)#{END_STRING}/m, 1] || text[/#{begin_string}(.*)$/m, 1]
      end
    end
  end
end
