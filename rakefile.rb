require('fileutils')

here_dir = File.dirname(__FILE__)

task :default do
    sh 'rake -T'
end

desc 'Run all UTs'
task :ut, %i[filter] do |task, args|
    # FileUtils.rm_rf('.zig-cache')
    sh "zig build test"

    mode = :release
    # mode = :debug
    sh("xmake f -m #{mode}")
    sh("xmake build -v rubr_ut")
    sh("xmake run rubr_ut")
end

desc("Clean")
task :clean do
    sh("xmake clean")
end

desc("Generate .clangd file")
task :clangd do
    File.open('.clangd', 'w') do |fo|
        fo.puts("CompileFlags:")
        fo.puts("    Add: [-std=c++23, -I#{File.join(here_dir, 'src')}]")
    end
end
