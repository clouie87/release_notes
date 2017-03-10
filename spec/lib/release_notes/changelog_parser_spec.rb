require 'release_notes'

describe ReleaseNotes::ChangelogParser do
  mattr_accessor :uniq_number

  describe '#assemble_changelog' do
    subject { ReleaseNotes::ChangelogParser }

    let(:change_one) { "- updates tests" }
    let(:issue_one) { "#3" }
    let(:pr_one) { create_merged_pr(change_one, issue_one) }
    let(:default_result) { "#### Closed PRS:" + create_result(pr_one, change_one, issue_one) }
    let(:default_changelog) { ["Closed PR: ##{pr_one[:number]} - #{pr_one[:title]} Closes:  #{issue_one} "] }
    let(:nothing_added) { "No Closed PRS" }

    describe 'special_handling' do
      it 'does not include merged_prs that have not checked Include this PR in changelog with bullet' do
        pr_one[:text].gsub!('### Special Handling - [x] Include this PR in the changelog', '### Special Handling - [] Include this PR in the changelog')
        expect(subject.assemble_changelog([pr_one])).to eq(nothing_added)
      end

      it 'does not update the changelog if no merged_prs are passed' do
        prs = []
        expect(subject.assemble_changelog(prs)).to eq(nothing_added)
      end

      it 'includes merged_prs that are checked to Include this PR in changelog with bullet' do
        expect(subject.assemble_changelog([pr_one])).to eq(default_result)
      end

      it 'includes merged_prs that have not checked Include this PR in changelog without bullet' do
        pr_one[:text].gsub!('### Special Handling - [x] Include this PR in the changelog', '### Special Handling [x] Include this PR in the changelog')
        expect(subject.assemble_changelog([pr_one])).to eq(default_result)
      end
    end

    describe "#changelog_summary" do
      it 'does not include merged_prs that have not checked Include this PR in changelog with bullet' do
        pr_one[:text].gsub!('### Special Handling - [x] Include this PR in the changelog', '### Special Handling - [] Include this PR in the changelog')
        expect(subject.changelog_summary([pr_one])).to eq([nothing_added])
      end

      it 'does not update the changelog if no merged_prs are passed' do
        prs = []
        expect(subject.changelog_summary(prs)).to eq([nothing_added])
      end

      it 'includes merged_prs that are checked to Include this PR in changelog with bullet' do
        expect(subject.changelog_summary([pr_one])).to eq(default_changelog)
      end

      it 'includes merged_prs that have not checked Include this PR in changelog without bullet' do
        pr_one[:text].gsub!('### Special Handling - [x] Include this PR in the changelog', '### Special Handling [x] Include this PR in the changelog')
        expect(subject.changelog_summary([pr_one])).to eq(default_changelog)
      end
    end

    describe 'parsing' do
      it 'parses when given notes from multiple prs' do
        change_two = "- adds map"
        issue_two = "#20"
        pr_two = create_merged_pr(change_two, issue_two)
        expect(subject.assemble_changelog([pr_one, pr_two])).to eq("#### Closed PRS:" + create_result(pr_one, change_one, issue_one) + create_result(pr_two, change_two, issue_two))
      end

      it 'parses content with # in them' do
        change_two = "- adds map using `#some_method`"
        issue_two = "#20"
        pr_two = create_merged_pr(change_two, issue_two)
        expect(subject.assemble_changelog([pr_one, pr_two])).to include("#{change_two}")
      end

      it 'returns content to inform nothing was closed when issue data is missing' do
        pr = pr_one.merge(text: "### Changes #{change_one} ### Special Handling - [x] Include this PR in the changelog")
        expect(subject.assemble_changelog([pr])).to include("Nothing Closed")
      end

      it 'returns content to inform nothing was changed when template data is missing' do
        pr = pr_one.merge(text: "### Closes #{issue_one} ### Special Handling - [x] Include this PR in the changelog")
        expect(subject.assemble_changelog([pr])).to include("No Changes included in the log")
      end

      it 'returns content correctly when change_notes have ##' do
        pr = pr_one.merge(text: "## Changes #{change_one} ### Closes #{issue_one} ### Special Handling - [x] Include this PR in the changelog")
        expect(subject.assemble_changelog([pr])).to eq(default_result)
      end
    end
  end

  def create_merged_pr(changes, closes)
    { number: create_uniq_number, title: "AnyTitle", text: "### Changes #{changes} ### Closes #{closes} ### Special Handling - [x] Include this PR in the changelog" }
  end

  def create_uniq_number
    self.uniq_number ||= 0
    self.uniq_number +=1
  end

  def create_result(pr, change, issue)
    "\n\n###### ##{pr[:number]} - #{pr[:title]}\n\n###### Changes\n\r \n#{change} \n\n\n###### Closes:\n #{issue} "
  end
end
