require 'active_support/all'

module ReleaseNotes
  class Manager

    INCLUDE_PR_TEXT = "- [x] Include this PR in the changelog".freeze
    END_STRING = /#\D\S/

    def initialize(repo, token)
      @api = GithubAPI.new(repo, token)
    end

    def publish_release(server_name, tag_name)
      new_tag = @api.find_tag_by_name(tag_name)
      old_tag = find_latest_published_tag(server_name: server_name)
      pr_texts = texts_from_merged_pr(new_tag, old_tag)

      changelog_text = assemble_changelog(pr_texts)
      verification_text = release_verification_text(server_name, old_tag, new_tag)
      release = update_release_notes(server_name, old_tag.tag, new_tag, verification_text.to_s, changelog_text)
      release[:verification] = verification_text
      release
    end

    def texts_from_merged_pr(new_tag, old_tag)
      commits_between_tags = @api.find_commits_between(old_tag.object.sha, new_tag.object.sha)
      matching_pr_commits(commits_between_tags).map { |commit| commit.body.squish }
    end

    def assemble_changelog(pr_texts)
      change_texts = pr_texts.select { |text| text if text.include?(INCLUDE_PR_TEXT) }
      changelog_text(change_texts)
    end

    # update release notes with changelog
    def update_release_notes(server_name, old_tag_name, new_tag, verification_text, text)
      return puts "Release Notes are already updated for Server #{server_name}" if old_tag_name == new_tag.tag
      release = find_current_release(new_tag.tag)
      title = "## Deployed to: #{server_name} (#{Time.zone.now.ctime})"
      subtitle = "### Changes Since: Tag #{old_tag_name}"
      verification_title = "Verification Data: (do not edit)"

      release_text = [title, subtitle, text, verification_title, verification_text]
      @api.update_release(release, release.body.to_s + release_text.join("\n\n"))
    end

    def find_current_release(tag_name)
      @api.find_release(tag_name)
    rescue Octokit::NotFound
      @api.create_release(tag_name)
    end

    private

    # find the prs that contain the commits between two tags
    def matching_pr_commits(commits)
      @api.merged_pull_requests.select do |pr|
        (@api.find_pull_request_commits(pr.number).map(&:sha) - commits.map(&:sha)).empty?
      end
    end

    def find_latest_published_tag(server_name: nil)
      old_release = find_latest_release(server_name: server_name)
      @api.find_tag_by_name(old_release.tag_name)
    end

    # find which release this server was last deployed to
    def find_latest_release(server_name: nil)
      releases = @api.releases
      release = releases.find { |r| r if r.body.to_s.include?("\"server\"=>\"#{server_name}\"") } if server_name
      release || releases.first
    end

    # verfication so we can identify on next deploy (look for server: server_name)
    def release_verification_text(server_name, old_tag, new_tag)
      { server: server_name, old_tag: old_tag.sha, new_tag_sha: new_tag.sha, commit_sha: new_tag.object.sha }.as_json
    end

    def changelog_text(texts)
      changes = section_text(texts, "# Changes").join("\n").presence || "No Changes included in the log"
      closes = section_text(texts, "# Closes").join(',').presence || "Nothing Closed"

      ["### Changes\n#{changes}", "### Closes\n#{closes}"]
    end

    def section_text(texts, begin_string)
      texts.map do |text|
        text.gsub!("- ", "\n- ")
        text[/#{begin_string}(.*?)#{END_STRING}/m, 1] || text[/#{begin_string}(.*)$/m, 1]
      end
    end
  end
end
