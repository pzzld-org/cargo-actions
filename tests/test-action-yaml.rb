#!/usr/bin/env ruby
require "yaml"

root = File.expand_path("..", __dir__)
paths = Dir[File.join(root, "src", "**", "action.yml")].sort
abort "no action manifests found" if paths.empty?

paths.each do |path|
  begin
    document = YAML.safe_load(File.read(path), aliases: false)
  rescue Psych::SyntaxError => error
    warn "invalid YAML: #{path.sub(root + "/", "")}: #{error.message}"
    exit 1
  end

  unless document.is_a?(Hash) && document["runs"].is_a?(Hash)
    warn "invalid action manifest root: #{path.sub(root + "/", "")}"
    exit 1
  end
end

puts "action YAML parse: ok (#{paths.length} manifests)"
