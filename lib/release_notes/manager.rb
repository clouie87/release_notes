require 'active_support/all'

module ReleaseNotes
  class Manager

    def initialize(repo, token)
      @api = GithubAPI.new(repo, token)
    end

    def publish_release(server_name, tag_name)
      new_tag = @api.find_tag_by_name(tag_name)
      release_to_compare = find_latest_release(server_name: server_name)

      if release_to_compare.present?
        old_tag = find_latest_published_tag(release_to_compare)
        pr_texts = texts_from_merged_pr(new_tag, old_tag)
        changelog_text = ChangelogParser.assemble_changelog(pr_texts)
      end

      old_tag ||= OpenStruct.new(sha: nil, tag: "First Deploy")

      update_release_notes(server_name, new_tag, old_tag, text: changelog_text)
    end

    def texts_from_merged_pr(new_tag, old_tag)
      commits_between_tags = @api.find_commits_between(old_tag.object.sha, new_tag.object.sha)
      matching_pr_commits(commits_between_tags).map { |commit| commit.body.squish }
    end

    # update release notes with changelog
    def update_release_notes(server_name, new_tag, old_tag, text: nil)
      release = find_current_release(new_tag.tag)

      if release.metadata[server_name]
        puts "Release Notes are already updated for Server #{server_name}"
        return release
      end

      verification_text = release_verification_text(server_name, old_tag, new_tag)

      @api.update_release(release, [release_notes_headers(server_name, old_tag), text].join("\n\n"), verification_text)
    end

    def find_current_release(tag_name)
      @api.find_release(tag_name)
    rescue Octokit::NotFound
      @api.create_release(tag_name)
      @api.find_release(tag_name)
    end

    def release_verification_text(server_name, old_tag, new_tag)
      {"#{server_name}": {old_tag: old_tag.sha, new_tag_sha: new_tag.sha, commit_sha: new_tag.object.sha}}
    end

    private

    # find the prs that contain the commits between two tags
    def matching_pr_commits(commits)
      @api.merged_pull_requests.select do |pr|
        (@api.find_pull_request_commits(pr.number).map(&:sha) - commits.map(&:sha)).empty?
      end
    end

    # find which release this server was last deployed to
    def find_latest_release(server_name: nil)
      return releases.find { |r| r.metadata.keys.include?(server_name.to_s) } if server_name
    end

    def find_latest_published_tag(old_release)
      @api.find_tag_by_name(old_release.tag_name)
    end

    def releases
      @api.releases
    end

    def release_notes_headers(server_name, old_tag)
      changes = "Changes Since: Tag " if old_tag.sha
      ["## Deployed to: #{server_name} (#{Time.now.utc.asctime})", "### " + changes.to_s + old_tag.tag]
    end
  end
end
