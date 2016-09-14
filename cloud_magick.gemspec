# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cloud_magick/version'

Gem::Specification.new do |spec|
  spec.name          = 'cloud_magick'
  spec.version       = CloudMagick::VERSION
  spec.authors       = ['pataiji']
  spec.email         = ['pataiji@gmail.com']

  spec.summary       = 'Build image resizing server on AWS'
  spec.description   = 'Build image resizing server on AWS'
  spec.homepage      = "https://github.com/pataiji/cloud_magick"
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-core', '~> 2.6'
  spec.add_dependency 'rubyzip', '>= 1.0.0'

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
end
