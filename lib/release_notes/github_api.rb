require 'octokit'

module ReleaseNotes
  class GithubAPI
    include Octokit

    METADATA_DELIMITER = "\n\nRelease Metadata: (do not edit)".freeze

    def initialize(repo, token)
      @repo = repo
      @client = Octokit::Client.new(access_token: token)
      @client.login
    end

    def find_commits_between(commit_old_sha, commit_new_sha)
      found_commits = []
      1.step do |page|
        current_commits = @client.compare(@repo, commit_old_sha, commit_new_sha, page: page).commits
        puts "Associated commits for page: #{page}"

        break if current_commits.count.zero?

        found_commits += current_commits
        sleep(1)
      end

      return found_commits
    end

    def find_tag_by_name(tag_name)
      tag_sha = find_tag_ref(tag_name).object.sha
      find_tag(tag_sha)
    end

    def find_tag_ref(tag)
      @client.ref(@repo, 'tags/' + tag)
    end

    def find_tag(tag_sha)
      @client.tag(@repo, tag_sha)
    end

    def merged_pull_requests(old_sha)
      closed_pull_requests_between(old_sha).select(&:merged_at?)
    end

    def closed_pull_requests_between(old_sha)
      end_date = commit_date(old_sha)
      closed_pull_requests = []

      1.step do |page|
        current_prs = closed_pull_requests_for_page(page)
        break if current_prs.count.zero?

        current_prs_since_end_date = current_prs.take_while { |pr| pr.updated_at > end_date }

        closed_pull_requests += current_prs_since_end_date

        # PRs are sorted by most recently updated.
        # When there are fewer current_prs_since_end_date than current_prs,
        # then we have all the closed_pull_requests since the old_sha.
        break if current_prs_since_end_date.count < current_prs.count
      end

      return closed_pull_requests
    end

    def commit_date(old_sha)
      @client.commit(@repo, old_sha).commit.committer.date
    end

    def closed_pull_requests_for_page(page)
      puts "Closed PRs for page: #{page}"
      @client.pull_requests(@repo, state: 'closed', sort: 'updated', direction: "desc", page: page)
    end

    def find_pull_request_commits(pr)
      @client.pull_request_commits(@repo, pr)
    end

    def branch(branch)
      @client.branch(@repo, branch)
    end

    def find_content(changelog_file, repo)
      repo ||= @repo
      @client.contents(repo, path: changelog_file)
    rescue Octokit::NotFound
      return nil
    end

    def update_changelog(repo, file, summary, changelog_content)
      @client.update_contents(repo, file.path, summary, file.sha, changelog_content)
    end

    def create_content(repo, file, changelog_content, message: "Creating Changelog")
      @client.create_content(repo, file, message, changelog_content)
    end
  end
end
