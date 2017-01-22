require 'octokit'
require 'release_notes'
require 'byebug'

describe ReleaseNotes::Manager do
  include Octokit
  mattr_accessor :uniq_number
  DEFAULT_SERVER = "Production"

  before(:all) do
    @access_token = ENV['GITHUB_API_TOKEN']
    @test_client = Octokit::Client.new(access_token: @access_token)
    @test_client.login
    @repo = @test_client.create_repo('test_release_notes', description: "testing gitHubAPI", auto_init: true).full_name
    @api = ReleaseNotes::GithubAPI.new(@repo, ENV['GITHUB_API_TOKEN'])
  end

  describe '#create_changelog_from_sha' do
    let(:branch) { create_branch }
    let(:pr) { setup_issue_commit_pr('master', branch) }

    before(:each) do
      sleep 1 # Github Best Practices https://developer.github.com/guides/best-practices-for-integrators/#dealing-with-rate-limits
    end

    before(:each) { branch; pr }

    subject { ReleaseNotes::Manager.new(@repo, @access_token, DEFAULT_SERVER) }

    it 'informs that it is the First Deploy if nothing to compare against' do
      expect(ReleaseNotes::Manager.new(@repo, @access_token, "fake").create_changelog_from_sha(pr.merge_commit_sha)).to include("First Deploy")
    end

    it 'compares against the last commit to the server' do
      subject.create_changelog_from_sha(pr.merge_commit_sha)
      pr_two = setup_issue_commit_pr('master', branch)
      expect(subject.create_changelog_from_sha(pr_two.merge_commit_sha)).to include(pr_two.title)
    end

    context 'when commits are merged into one branch and then merged into another_branch' do
      let(:branch_one) { create_branch }
      let(:branch_two) { create_branch }
      let(:pr_three) { setup_issue_commit_pr(branch_one, branch_two) }
      let(:pr_four) { setup_issue_commit_pr(branch_one, branch_two) }
      let(:unmerged_pr) { setup_issue_commit_unmerged(branch_one, branch_two) }

      before(:each) { branch_one; branch_two; pr_three; pr_four; unmerged_pr }

      it 'finds all the prs since the last deploy' do
        subject.create_changelog_from_sha(pr.merge_commit_sha)
        expect(subject.create_changelog_from_sha(pr_four.merge_commit_sha)).to include(pr_three.title, pr_four.title)
      end

      it 'finds all the pr texts when a branch is merged into another branch' do
        subject.create_changelog_from_sha(pr.merge_commit_sha)
        pr_five =  create_and_merge_pull_request(main_branch: 'master', feature_branch: branch_one)
        expect(subject.create_changelog_from_sha(pr_five.merge_commit_sha)).to include(pr_three.title, pr_four.title, pr_five.title)
      end

      it "does not find unmerged prs" do
        subject.create_changelog_from_sha(pr.merge_commit_sha)
        expect(subject.create_changelog_from_sha(pr_four.merge_commit_sha)).not_to include(unmerged_pr.title)
      end

      it "does not find prs that have already been in the changelog" do
        subject.create_changelog_from_sha(pr_three.merge_commit_sha)
        expect(subject.create_changelog_from_sha(pr_four.merge_commit_sha)).not_to include(pr_three.title)
      end
    end

    after(:each) { File.delete("#{DEFAULT_SERVER}_changelog.md")}
  end

  after(:all) do
    puts "delete created repo"
    @test_client.delete_repo(@repo)
    File.delete("#{DEFAULT_SERVER}_changelog.md.old")
    File.delete("fake_changelog.md.old")
    File.delete("fake_changelog.md")
  end
end

# Helper Methods
# SETUP
def setup_issue_commit_pr(main_branch, feature_branch, body: 'dummyText')
  issue = create_issue
  closing_commit = create_commit("closing_commit_#{issue.number}", feature_branch)
  create_and_merge_pull_request(main_branch: main_branch, feature_branch: feature_branch, body: "#{body}_#{issue.number}", issue: issue.number)
end

def setup_issue_commit_unmerged(main_branch, feature_branch, body: 'dummyText')
  issue = create_issue
  closing_commit = create_commit("closing_commit_#{issue.number}", feature_branch)
  @test_client.create_pull_request(@repo, main_branch, feature_branch, "#{body}_#{issue.number}", pull_request_body(issue))
end

# CREATE
def create_branch
  uniq_number = create_uniq_number
  name = "branch_#{uniq_number}"
  @test_client.create_ref(@repo, 'heads/' + name, tagging_commit)
  return name
end

def create_issue
  uniq_number = create_uniq_number
  @test_client.create_issue(@repo, "issue_#{uniq_number}", "issue_desc")
end

def create_uniq_number
  self.uniq_number ||= 0
  self.uniq_number +=1
end

def create_commit(commit_name, branch_name)
  add_content(commit_name, branch_name: branch_name)
end

def create_and_merge_pull_request(main_branch: 'master', feature_branch: nil, body: 'dummyText', issue: nil)
  pr = @test_client.create_pull_request(@repo, main_branch, feature_branch, body, pull_request_body(issue))
  merge_pull_request(pr.number)
  @test_client.pull_request(@repo, pr.number)
end

def merge_pull_request(number)
  @test_client.merge_pull_request(@repo, number)
end

def tagging_commit(branch: 'master')
  @test_client.branch(@repo, branch).commit.sha
end

def add_content(tag, branch_name: "master")
  @test_client.create_content(@repo, "lib/test#{tag}.rb", 'AddingContent', 'Closes Issue#1', :branch => branch_name)
end

# CHANGELOG TEXT
def pull_request_body(issue)
  "### Changes- testing_pull_request ### Closes ##{issue} ### Special Handling - [x] Include this PR in the changelog"
end
