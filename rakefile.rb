require('fileutils')

here_dir = File.dirname(__FILE__)

task :default do
  sh 'rake -T'
end

desc 'Run all UTs'
task :ut, %i[filter] do |_task, args|
  sh 'clear'

  filter = (args[:filter] || '').split(':').map { |e| "-Dtest-filter=#{e}" } * ' '
  sh "zig build test #{filter} -freference-trace=10"

  # mode = :release
  # # mode = :debug
  # sh("xmake f -m #{mode}")
  # sh('xmake build -v rubr_ut')
  # sh('xmake run rubr_ut')
end

desc('Clean')
task :clean do
  sh('xmake clean')
end

desc('Export all specified modules into a single file')
task :export do |_task, args|
  mods = args.extras
  require_relative("export.rb")
  export = Export.new()
  mods.each do |m|
    export.add("src/#{m}.zig")
  end
  export.write()
end

desc('Generate .clangd file')
task :clangd do
  File.open('.clangd', 'w') do |fo|
    fo.puts('CompileFlags:')
    fo.puts("    Add: [-std=c++23, -I#{File.join(here_dir, 'src')}]")
  end
end
