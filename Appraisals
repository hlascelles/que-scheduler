# Que changes some of its config if Rails is present. We should run a test that config:
# https://github.com/que-rb/que/blob/45e68691f2599c13b401e2d70cde6f6fbfcac708/lib/que/railtie.rb#L10
appraise "rails-6-que-0-14" do
  gem "rails", "~> 6.0.3"
  gem "que", "~> 0.14"
end

appraise "activesupport-5-que-0-14" do
  gem "activesupport", "~> 5.0"
  gem "que", "~> 0.14"
end

appraise "activesupport-5-que-0-14-activejob" do
  gem "activesupport", "~> 5.0"
  gem "que", "~> 0.14"
  gem "activejob", "~> 5.0"
end

appraise "activesupport-6-que-0-14" do
  gem "activesupport", "~> 6.0.3"
  gem "que", "~> 0.14"
end

appraise "activesupport-6-without-queue-names-que-0-14-activejob" do
  gem "activesupport", "~> 6.0.3"
  gem "que", "~> 0.14"
  gem "activejob", "6.0.3"
end

appraise "activesupport-6-with-queue-names-que-0-14-activejob" do
  gem "activesupport", "~> 6.0.3"
  gem "que", "~> 0.14"
  gem "activejob", "~> 6.0.3"
end

appraise "activesupport-5-que-1-x" do
  gem "activesupport", "~> 5.0"
  gem "que", "1.4.0"
end

appraise "activesupport-5-que-1-x-activejob" do
  gem "activesupport", "~> 5.0"
  gem "que", "1.4.0"
  gem "activejob", "~> 5.0"
end

appraise "activesupport-6-que-1-x" do
  gem "activesupport", "~> 6.0.3"
  gem "que", "1.4.0"
end

appraise "activesupport-6-without-queue-names-1-x-activejob" do
  gem "activesupport", "~> 6.0.3"
  gem "que", "1.4.0"
  gem "activejob", "6.0.3"
end

appraise "activesupport-6-with-queue-names-que-1-x-activejob" do
  gem "activesupport", "~> 6.0.3"
  gem "que", "1.4.0"
  gem "activejob", "~> 6.0.3"
end

appraise "activesupport-6-que-2-x" do
  gem "activesupport", "~> 6.0.3"
  gem "que", "2.0.0.beta1"
end
