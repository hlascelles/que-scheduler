appraise "rails-8-0" do
  gem "activejob", "~> 8.0.0"
  gem "activesupport", "~> 8.0.0"
  gem "pg", "~> 1.4"
end

appraise "rails-8-1" do
  gem "activejob", "~> 8.1.0"
  gem "activesupport", "~> 8.1.0"
  # que 2.4.1 passes create_additions to JSON.parse, which json 3 removed
  gem "json", "< 3"
  gem "pg", "~> 1.4"
end
