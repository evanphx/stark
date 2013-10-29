# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "stark"
  s.version = "0.9.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Evan Phoenix"]
  s.date = "2013-10-29"
  s.description = "Optimized thrift bindings for ruby."
  s.email = ["evan@phx.io"]
  s.executables = ["stark"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.md", "examples/README.md"]
  s.files = [".autotest", ".gemtest", ".travis.yml", "History.txt", "Manifest.txt", "README.md", "Rakefile", "bin/stark", "examples/README.md", "examples/client.rb", "examples/health.thrift", "examples/server.rb", "lib/stark.rb", "lib/stark/ast.rb", "lib/stark/client.rb", "lib/stark/exception.rb", "lib/stark/log_transport.rb", "lib/stark/parser.rb", "lib/stark/processor.rb", "lib/stark/protocol_helpers.rb", "lib/stark/raw_parser.rb", "lib/stark/ruby.rb", "lib/stark/struct.rb", "lib/stark/thrift.kpeg", "stark.gemspec", "test/ThriftSpec.thrift", "test/blah.thrift", "test/comments.thrift", "test/gen-rb/profile_constants.rb", "test/gen-rb/profile_types.rb", "test/gen-rb/user_storage.rb", "test/include_blah.thrift", "test/leg.rb", "test/legacy_profile/profile_constants.rb", "test/legacy_profile/profile_types.rb", "test/legacy_profile/user_storage.rb", "test/parsing_error.thrift", "test/profile.thrift", "test/properties.thrift", "test/test_client.rb", "test/test_coerce_strings.rb", "test/test_helper.rb", "test/test_marshal.rb", "test/test_parser.rb", "test/test_ruby.rb", "test/test_server.rb", "test/test_stark.rb", "test/types.thrift", "test/users.thrift"]
  s.homepage = "http://github.com/evanphx/stark"
  s.licenses = ["MIT"]
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "stark"
  s.rubygems_version = "1.8.23"
  s.summary = "Optimized thrift bindings for ruby."
  s.test_files = ["test/test_client.rb", "test/test_coerce_strings.rb", "test/test_helper.rb", "test/test_marshal.rb", "test/test_parser.rb", "test/test_ruby.rb", "test/test_server.rb", "test/test_stark.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<thrift>, ["!= 0.9.1", "~> 0.9.0"])
      s.add_development_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_development_dependency(%q<hoe>, ["~> 3.7"])
    else
      s.add_dependency(%q<thrift>, ["!= 0.9.1", "~> 0.9.0"])
      s.add_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_dependency(%q<hoe>, ["~> 3.7"])
    end
  else
    s.add_dependency(%q<thrift>, ["!= 0.9.1", "~> 0.9.0"])
    s.add_dependency(%q<rdoc>, ["~> 4.0"])
    s.add_dependency(%q<hoe>, ["~> 3.7"])
  end
end
