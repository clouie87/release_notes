require 'release_notes'

describe ReleaseNotes::ChangelogParser do

  describe '#assemble_changelog' do
    subject { ReleaseNotes::ChangelogParser }

    let(:changes) { "### Changes - testing_pull_request " }
    let(:closes) {  "### Closes #1" }
    let(:default_result) { ["### Changes\n \n- testing_pull_request ", "### Closes\n #1"] }
    let(:nothing_added) { ["### Changes\nNo Changes included in the log", "### Closes\nNothing Closed"] }

    describe 'special_handling' do
      it 'does not include merged_prs that have not checked Include this PR in changelog' do
        change_notes = [ changes + closes + "### Special Handling - [] Include this PR in the changelog"]
        expect(subject.assemble_changelog(change_notes)).to eq(nothing_added)
      end

      it 'does not include merged_prs without special_handling specified' do
        change_notes = [ changes ]
        expect(subject.assemble_changelog(change_notes)).to eq(nothing_added)
      end

      it 'does not update the changelog if no merged_prs are passed' do
        change_notes = []
        expect(subject.assemble_changelog(change_notes)).to eq(nothing_added)
      end

      it 'includes merged_prs that are checked to Include this PR in changelog' do
        change_notes = [ changes + closes + "### Special Handling - [x] Include this PR in the changelog" ]
        expect(subject.assemble_changelog(change_notes)).to eq(default_result)
      end
    end

    describe 'parsing' do
      let(:special_handling) { "### Special Handling - [x] Include this PR in the changelog" }
      let(:closes_two) {  "### Closes #3" }

      it 'parses when given notes from multiple prs' do
        change_notes = [ changes + closes + special_handling, changes + closes_two + special_handling ]
        result = ["### Changes\n \n- testing_pull_request \n \n- testing_pull_request ", "### Closes\n #1, #3"]
        expect(subject.assemble_changelog(change_notes)).to eq(result)
      end

      it 'reorders the content correctly when passed change_notes out of order' do
        change_notes = [ special_handling + changes + closes ]
        expect(subject.assemble_changelog(change_notes)).to eq(default_result)
      end

      it 'returns content when some template data is missing' do
        change_notes = [ changes + special_handling ]
        result = ["### Changes\n \n- testing_pull_request ", "### Closes\nNothing Closed"]
        expect(subject.assemble_changelog(change_notes)).to eq(result)
      end

      it 'returns content correctly when change_notes have ##' do
        change_notes = ["## Changes - testing_pull_request " + closes + special_handling]
        expect(subject.assemble_changelog(change_notes)).to eq(default_result)
      end

      it 'returns content correctly when change_notes have #' do
        change_notes = ["# Changes - testing_pull_request " + closes + special_handling]
        expect(subject.assemble_changelog(change_notes)).to eq(default_result)
      end
    end
  end
end
