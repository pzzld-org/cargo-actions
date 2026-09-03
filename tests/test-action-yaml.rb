#!/usr/bin/env ruby
require "yaml"

root = File.expand_path("..", __dir__)
paths = Dir[File.join(root, "src", "**", "action.yml")].sort
abort "no action manifests found" if paths.empty?

failures = []

def present_string?(value)
  value.is_a?(String) && !value.strip.empty?
end

paths.each do |path|
  relative = path.sub(root + "/", "")

  begin
    document = YAML.safe_load(File.read(path), aliases: false)
  rescue Psych::SyntaxError => error
    failures << "#{relative}: invalid YAML: #{error.message.lines.first.strip}"
    next
  end

  unless document.is_a?(Hash)
    failures << "#{relative}: manifest root must be a mapping"
    next
  end

  failures << "#{relative}: name must be a non-empty string" unless present_string?(document["name"])
  failures << "#{relative}: description must be a non-empty string" unless present_string?(document["description"])
  failures << "#{relative}: author must be a non-empty string" unless present_string?(document["author"])

  inputs = document.fetch("inputs", {})
  unless inputs.is_a?(Hash)
    failures << "#{relative}: inputs must be a mapping"
    inputs = {}
  end

  inputs.each do |name, spec|
    unless spec.is_a?(Hash)
      failures << "#{relative}: input #{name.inspect} must be a mapping"
      next
    end

    failures << "#{relative}: input #{name.inspect} needs a description" unless present_string?(spec["description"])
    if spec.key?("required") && ![true, false].include?(spec["required"])
      failures << "#{relative}: input #{name.inspect} required must be a YAML boolean"
    end
    if spec.key?("default") && !spec["default"].is_a?(String)
      failures << "#{relative}: input #{name.inspect} default must be a string"
    end
  end

  outputs = document.fetch("outputs", {})
  unless outputs.is_a?(Hash)
    failures << "#{relative}: outputs must be a mapping"
    outputs = {}
  end

  outputs.each do |name, spec|
    unless spec.is_a?(Hash)
      failures << "#{relative}: output #{name.inspect} must be a mapping"
      next
    end
    failures << "#{relative}: output #{name.inspect} needs a description" unless present_string?(spec["description"])
    failures << "#{relative}: output #{name.inspect} needs a value expression" unless present_string?(spec["value"])
  end

  runs = document["runs"]
  unless runs.is_a?(Hash) && runs["using"] == "composite"
    failures << "#{relative}: runs.using must be composite"
    next
  end

  steps = runs["steps"]
  unless steps.is_a?(Array) && !steps.empty?
    failures << "#{relative}: composite action needs at least one step"
    next
  end

  ids = []
  steps.each_with_index do |step, index|
    unless step.is_a?(Hash)
      failures << "#{relative}: step #{index + 1} must be a mapping"
      next
    end

    has_uses = step.key?("uses")
    has_run = step.key?("run")
    unless has_uses ^ has_run
      failures << "#{relative}: step #{index + 1} must define exactly one of uses or run"
    end
    if has_run && !present_string?(step["shell"])
      failures << "#{relative}: run step #{index + 1} must declare shell explicitly"
    end
    if step.key?("id")
      unless present_string?(step["id"])
        failures << "#{relative}: step #{index + 1} id must be a non-empty string"
      end
      ids << step["id"]
    end
  end

  duplicates = ids.tally.select { |_id, count| count > 1 }.keys
  failures << "#{relative}: duplicate step ids: #{duplicates.join(', ')}" unless duplicates.empty?
end

unless failures.empty?
  warn failures.join("\n")
  exit 1
end

puts "action YAML schema: ok (#{paths.length} manifests)"
