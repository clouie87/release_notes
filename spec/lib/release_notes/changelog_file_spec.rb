require 'release_notes'

describe ReleaseNotes::ChangelogFile do

  describe "#remove_files" do
    subject { ReleaseNotes::ChangelogFile.new('prod', "prod_changelog.md", "api") }

    before(:each) do
      allow(subject).to receive(:github_file).and_return(nil)
      subject.update_changelog("First Deploy")
    end

    it "should have the files created on update_changelog" do
      expect(File.exist?("prod_changelog.md")).to be true
    end

    it "should remove the files created on update changelog" do
      subject.remove_files
      expect(File.exist?("prod_changelog.md")).to be false
    end
  end
end
