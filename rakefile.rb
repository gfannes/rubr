require('fileutils')

here_dir = File.dirname(__FILE__)

task :default do
    sh 'rake -T'
end

desc 'Run all UTs'
task :ut, %i[filter] do |task, args|
    filter = (args[:filter]||'').split(':').map{|e|"-Dtest-filter=#{e}"}*' '
    sh "zig build test #{filter}"

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

desc("Export all specified modules into a single file")
task :export do |task,args|
    mods = args.extras
    puts("// Output from `rake export[#{mods.join(',')}]` from https://github.com/gfannes/rubr from #{Time.now.strftime("%Y-%m-%d")}")
    puts("\nconst std = @import(\"std\");")
    prev_empty = false
    mods.each do |m|
        fp = "src/#{m}.zig"
        puts("\npub const #{m} = struct {")
        File.open(fp) do |fi|
            skip_all = false
            fi.each_line do |line|
                line.chomp!
                skip_one = false
                skip_one = true if line[/^const std = @import/]
                skip_all = true if line[/^test /]
                if skip_all and line[/&\}/]
                    skip_all = false
                    skip_one = true
                end
                skip_one = true if skip_all
                next if skip_one

                puts("    #{line}") if !line.empty? || !prev_empty

                prev_empty = line.empty?
            end
        end
        puts("}")
    end
end


desc("Generate .clangd file")
task :clangd do
    File.open('.clangd', 'w') do |fo|
        fo.puts("CompileFlags:")
        fo.puts("    Add: [-std=c++23, -I#{File.join(here_dir, 'src')}]")
    end
end
