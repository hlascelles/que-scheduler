shared_examples "when checking we cannot use code" do |str, except_in = nil|
  it "#{str} is not used explicitly" do
    Dir.glob("lib/**/*").select { |file| File.file?(file) }.each do |file|
      expect(File.open(file).grep(/#{str}/)).to be_empty unless File.basename(file) == except_in
    end
  end
end
