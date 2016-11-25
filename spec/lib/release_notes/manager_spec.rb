require 'octokit'
require 'release_notes'

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

  describe 'Test Repo' do
    before(:all) do
      @tag_one = create_new_tag("1", commit_sha: tagging_commit)
      ReleaseNotes::Manager.new(@repo, @access_token).publish_release(DEFAULT_SERVER, @tag_one.tag)
    end

    before(:each) do
      sleep 1 # Github Best Practices https://developer.github.com/guides/best-practices-for-integrators/#dealing-with-rate-limits
    end

    describe '#publish_release' do
      let(:branch) { create_branch }
      let(:pr) { setup_issue_commit_pr('master', branch) }

      before(:each) { branch; pr }

      subject { ReleaseNotes::Manager.new(@repo, @access_token) }

      context 'when deploying the first release' do
        it 'adds the metadata' do
          hash = subject.release_verification_text(DEFAULT_SERVER, OpenStruct.new(sha: nil, tag: "First Deploy"), @tag_one)
          expect(subject.find_current_release(@tag_one.tag).metadata).to include(JSON.parse(hash.to_json))
        end

        it 'adds that this is the first deploy to this server to the body' do
          expect(subject.find_current_release(@tag_one.tag).body).to include(DEFAULT_SERVER, "First Deploy")
        end
      end

      context 'when deploying to one server' do
        let(:new_tag_name) { create_new_tag(find_tag_name(latest_tag.name).to_s).tag }

        before(:each) { new_tag_name }

        it 'finds the tag that was last linked to a server_name' do
          expect(subject.publish_release(DEFAULT_SERVER, new_tag_name).body).to include(@tag_one.sha)
        end

        it 'does not update metadata if already deployed tag to server' do
          expect(subject.publish_release(DEFAULT_SERVER, @tag_one.tag).body).to match("\n\n")
        end
      end

      context 'when deploying to multiple servers' do
        let(:new_tag_name) { create_new_tag(find_tag_name(latest_tag.name).to_s).tag }
        let(:release) { subject.publish_release(DEFAULT_SERVER, new_tag_name) }

        before(:each) { new_tag_name; release; }

        it 'updates the metadata with both servers if two servers have been deployed to the same tag' do
          server_name = 'NewServer'
          subject.publish_release(server_name, new_tag_name)
          expect(subject.find_current_release(new_tag_name).metadata.keys).to include(DEFAULT_SERVER, server_name)
        end
      end
    end

    context 'when a new tag is created after a pull request is merged into a branch' do
      let(:branch_name) { create_branch }
      let(:pull_request_one) { setup_issue_commit_pr('master', branch_name) }
      let(:old_tag) { @api.find_tag_by_name(find_latest_release) }
      let(:new_tag) { create_new_tag(find_tag_name(latest_tag.name).to_s) }
      let(:pull_request_two) { setup_issue_commit_pr('master', branch_name) }

      describe '#texts_from_merged_pr' do
        before(:each) { branch_name; pull_request_one; old_tag; new_tag; pull_request_two }

        def delete_tag_ref
          @test_client.delete_ref(@repo, "tags/#{new_tag.tag}")
        end

        subject { ReleaseNotes::Manager.new(@repo, @access_token) }

        it 'finds the pr texts that have been merged' do
          expect(subject.texts_from_merged_pr(new_tag, old_tag)).to include(pull_request_one.body)
        end

        it 'does not find unmerged pr texts' do
          expect(subject.texts_from_merged_pr(new_tag, old_tag)).not_to include(pull_request_two.body)
        end
      end
    end

    context 'when a new tag is created after commits from a branch were merged into another_branch' do
      let(:branch_one) { create_branch }
      let(:branch_two) { create_branch }
      let(:pr_one) { setup_issue_commit_pr(branch_one, branch_two) }
      let(:pr_two) { setup_issue_commit_pr(branch_one, branch_two) }
      let(:old_tag) { @api.find_tag_by_name(find_latest_release) }
      let(:new_tag) { create_new_tag(find_tag_name(latest_tag.name).to_s, commit_sha: tagging_commit(branch: branch_one)) }

      before(:each) { branch_one; branch_two; pr_one; pr_two; old_tag; new_tag }

      subject { ReleaseNotes::Manager.new(@repo, @access_token) }

      describe '#texts_from_merged_pr' do
        it 'finds all the pr texts that have been merged since the old tag' do
          expect(subject.texts_from_merged_pr(new_tag, old_tag)).to include(pr_one.body, pr_two.body)
        end

        context 'when a newer tag is created' do
          let(:pr_three) { setup_issue_commit_pr(branch_one, branch_two) }
          let(:newer_tag) { create_new_tag(find_tag_name(latest_tag.name).to_s, commit_sha: tagging_commit(branch: branch_one)) }

          before(:each) { subject.find_current_release(new_tag.tag); pr_three; newer_tag }

          it 'finds the texts of the merged pull requests since the last tag' do
            expect(subject.texts_from_merged_pr(newer_tag, new_tag)).to include(pr_three.body)
          end

          it 'does not find the texts of merged pull requests from earlier tags' do
            expect(subject.texts_from_merged_pr(newer_tag, new_tag)).not_to include(pr_one.body, pr_two.body)
          end
        end

        context 'when a branch with merged pull requests is then merged into another branch' do
          let(:pr_four) { create_and_merge_pull_request(main_branch: 'master', feature_branch: branch_one) }
          let(:newer_tag) { create_new_tag(find_tag_name(new_tag.tag).to_s, commit_sha: tagging_commit) }

          before(:each) { pr_four; newer_tag }

          it 'finds the texts of merged pull requests since the last tag' do
            expect(subject.texts_from_merged_pr(newer_tag, old_tag)).to include(pr_one.body, pr_two.body, pr_four.body)
          end
        end
      end
    end

    after(:all) do
      puts "delete created repo"
      @test_client.delete_repo(@repo)
    end
  end
end

# Helper Methods
# SETUP
def setup_issue_commit_pr(main_branch, feature_branch, body: 'dummyText')
  issue = create_issue
  closing_commit = create_commit("closing_commit_#{issue.number}", feature_branch)
  create_and_merge_pull_request(main_branch: main_branch, feature_branch: feature_branch, body: body, issue: issue.number)
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
  pr
end

def merge_pull_request(number)
  @test_client.merge_pull_request(@repo, number)
end

def create_new_tag(tag_name, commit_sha: nil)
  commit_sha ||= add_content(tag_name).commit.sha
  new_tag = @test_client.create_tag(@repo, tag_name, 'tag_comment', commit_sha, 'commit', @test_client.user.name, @test_client.user.email, Time.now)
  @test_client.create_ref(@repo, 'tags/' + new_tag.tag, new_tag.sha)
  @api.find_tag_by_name(new_tag.tag)
end

# FIND
def find_tag_name(last_tag_name)
  last_tag_name.to_i + 1
end

def latest_tag
  @test_client.tags(@repo).first
end


def tagging_commit(branch: 'master')
  @test_client.branch(@repo, branch).commit.sha
end

def find_latest_release
  @test_client.latest_release(@repo).tag_name
end

def add_content(tag, branch_name: "master")
  @test_client.create_content(@repo, "lib/test#{tag}.rb", 'AddingContent', 'Closes Issue#1', :branch => branch_name)
end

# CHANGELOG TEXT
def pull_request_body(issue)
  "### Changes- testing_pull_request ### Closes ##{issue} ### Special Handling - [x] Include this PR in the changelog"
end
