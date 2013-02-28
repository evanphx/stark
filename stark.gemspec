# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "stark"
  s.version = "0.5.0.20130227233247"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Evan Phoenix"]
  s.date = "2013-02-28"
  s.description = "Optimized thrift bindings for ruby"
  s.email = ["evan@phx.io"]
  s.executables = ["stark"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = [".autotest", "History.txt", "Manifest.txt", "README.txt", "Rakefile", "bin/stark", "lib/stark.rb", "test/test_stark.rb", "test/test_client.rb", "test/test_parser.rb", "test/test_server.rb", ".gemtest"]
  s.homepage = "http://github.com/evanphx/stark"
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "stark"
  s.rubygems_version = "1.8.25"
  s.summary = "Optimized thrift bindings for ruby"
  s.test_files = ["test/test_client.rb", "test/test_parser.rb", "test/test_server.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<thrift>, ["~> 0.9.0"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.10"])
      s.add_development_dependency(%q<hoe>, ["~> 3.5"])
    else
      s.add_dependency(%q<thrift>, ["~> 0.9.0"])
      s.add_dependency(%q<rdoc>, ["~> 3.10"])
      s.add_dependency(%q<hoe>, ["~> 3.5"])
    end
  else
    s.add_dependency(%q<thrift>, ["~> 0.9.0"])
    s.add_dependency(%q<rdoc>, ["~> 3.10"])
    s.add_dependency(%q<hoe>, ["~> 3.5"])
  end
end
