lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'teamwork'
  spec.version       = '1.0.7'
  spec.authors       = ['elkadi']
  spec.email         = ['melkadi@instabug.com']
  spec.description   = %q{Wrapper around Teamwork api}
  spec.summary       = %q{Wrapper around Teamwork api}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.0'

  spec.add_dependency 'rest-client'
  spec.add_dependency 'faraday'
  spec.add_dependency 'faraday_middleware'
  spec.add_dependency 'multi_json'
  spec.add_dependency'multipart-post'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency "rdoc", "~>4.0"
  spec.add_development_dependency 'bundler', '~> 1.3' 
end
