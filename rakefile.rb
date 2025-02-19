task :default do
    sh 'rake -T'
end

desc 'Run all UTs'
task :test do
    FileList.new('src/*.zig').each do |fp|
        sh "zig test #{fp}"
    end
end
