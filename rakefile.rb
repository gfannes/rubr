require('fileutils')

task :default do
    sh 'rake -T'
end

desc 'Run all UTs'
task :ut, %i[filter] do |task, args|
    # FileUtils.rm_rf('.zig-cache')
    sh "zig build test"
    # filter = args[:filter] || '*.zig'
    # FileList.new("src/**/*#{filter}*").each do |fp|
    #     sh "zig test #{fp}"
    # end
end
