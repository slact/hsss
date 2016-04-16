# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hsss/version'

Gem::Specification.new do |spec|
  spec.name          = "hsss"
  spec.version       = Hsss::VERSION
  spec.authors       = ["Leo P."]
  spec.email         = ["junk@slact.net"]

  spec.summary       = %q{Hash-Safe Script Splinter}
  spec.description   = %q{Transforms Lua files into structs of C-strings and associated headers. Great for embedding Redis Lua scripts.}
  spec.homepage      = "https://github.com/slact/hsss"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  dependencies = [
    #[:runtime, ""],
    [:development, "bundler"],
    [:development, "rake"],
    [:development, "pry"],
    [:development, "pry-debundle"]
  ]

  dependencies.each do |type, name, version|
    if spec.respond_to?("add_#{type}_dependency")
      spec.send("add_#{type}_dependency", name, version)
    else
      spec.add_dependency(name, version)
    end
  end
  
end
