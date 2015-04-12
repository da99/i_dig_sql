# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "i_dig_sql"
  spec.version       = `cat VERSION`.strip
  spec.authors       = ["da99"]
  spec.email         = ["i-hate-spam-1234567@mailinator.com"]
  spec.summary       = %q{Yet another way of generating Postgresql 9.2+ in Ruby.}
  spec.description   = %q{
  You probably want another gem: arel. Use that
  to generate SQL using Ruby.
  This gem only generates SELECT and WITH (ie CTE) statements/expressions.
  }
  spec.homepage      = "https://github.com/da99/i_dig_sql"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep("bin/#{spec.name}") { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"            , "> 1.5"
  spec.add_development_dependency "bacon"              , '> 1.0'
  spec.add_development_dependency "Bacon_Colored"      , '> 0'
  spec.add_development_dependency "pry"                , '> 0'
  spec.add_development_dependency "awesome_print"      , '> 0'
  spec.add_development_dependency "rouge" , '> 0.0.0'
  spec.add_development_dependency "unindent" , '> 0.0.0'
end
