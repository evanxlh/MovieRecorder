Pod::Spec.new do |s|
    s.name = 'MovieRecorder'
    s.version = '0.1'
    s.license = 'MIT'
    s.summary = 'A flexible, versatile movie recorder using Metal for iOS.'
    s.homepage = 'https://github.com/evanxlh/MovieRecorder'
    s.authors = { 'Evan Xie' => 'evanxie.mr@foxmail.com' }
    s.source = { :git => 'https://github.com/evanxlh/MovieRecorder.git', :tag => s.version }

    s.platform = :ios, "10.0"

    s.swift_version = '5.0'

    s.source_files = 'Source/*.swift'

end
