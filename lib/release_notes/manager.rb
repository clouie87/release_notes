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

      if releases.present?
        old_tag = find_latest_published_tag(new_tag.tag, server_name: server_name)
        old_tag_sha = old_tag.sha
        pr_texts = texts_from_merged_pr(new_tag, old_tag)
        changelog_text = [release_notes_headers(server_name, old_tag), assemble_changelog(pr_texts)].join("\n\n")
      end

      update_release_notes(server_name, new_tag, old_tag_sha: old_tag_sha, text: changelog_text)
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
    def update_release_notes(server_name, new_tag, old_tag_sha: nil, text: nil)
      release = find_current_release(new_tag.tag)

      if release.metadata[server_name]
        puts "Release Notes are already updated for Server #{server_name}"
        return release
      end

      verification_text = release_verification_text(server_name, old_tag_sha, new_tag)

      @api.update_release(release, text, verification_text)
    end

    def find_current_release(tag_name)
      @api.find_release(tag_name)
    rescue Octokit::NotFound
      @api.create_release(tag_name)
      @api.find_release(tag_name)
    end

    def release_verification_text(server_name, old_tag_sha, new_tag)
      {"#{server_name}": {old_tag: old_tag_sha, new_tag_sha: new_tag.sha, commit_sha: new_tag.object.sha}}
    end

    private

    # find the prs that contain the commits between two tags
    def matching_pr_commits(commits)
      @api.merged_pull_requests.select do |pr|
        (@api.find_pull_request_commits(pr.number).map(&:sha) - commits.map(&:sha)).empty?
      end
    end

    def find_latest_published_tag(new_tag_name, server_name: nil)
      old_release = find_latest_release(server_name: server_name)
      @api.find_tag_by_name(old_release.tag_name)
    end

    # find which release this server was last deployed to
    def find_latest_release(server_name: nil)
      release = releases.find { |r| r.metadata.keys.include?(server_name.to_s) } if server_name
      release || releases.first
    end

    def releases
      @api.releases
    end

    def release_notes_headers(server_name, old_tag)
      ["## Deployed to: #{server_name} (#{Time.zone.now.ctime})", "### Changes Since: Tag #{old_tag.tag}"]
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
