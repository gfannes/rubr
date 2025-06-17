require('pathname')

# Support for exporting a set of Zig modules into a single module
# This takes recursive @imports into account, albeit with following constraints:
# - The name of an @import must match with its file basename
# - An @import must immediately end with a ';'
# - The name of an @import cannot be used somewhere else to reduce shadowing issues

class Mod
  attr_reader(:fp, :path, :lines)
  def initialize(fp)
    @fp = fp.cleanpath
    @path = @fp.sub_ext('').to_s.split('/')
    @path.shift # Remove 'src'
    @lines = parse_()
  end

  def name()
    @path.last
  end

  def imports(&cb)
    @lines.each do |line|
      if Hash === line
        cb.(line[:fp])
      end
    end
  end

  def parse_()
    lines = []
    is_test = false
    prev_is_empty = true
    File.open(@fp) do |fi|
      fi.each_line do |line|
        line.chomp!
        if md = /^const (.+) = @import\("(.+)"\);/.match(line)
          name, file = md[1], md[2]
          if file != 'std'
            fp = (@fp.dirname/file).cleanpath
            basename = File.basename(fp, '.zig')
            raise("Expected name '#{name}' to be the same as the basename '#{basename}'") unless basename == name
            lines << {what: :import, name:, fp:}
          end
        else
          raise("Found unhandled import in '#{@fp}'") if line['@import']
          is_test = true if line[/^test .*{/]
          if is_test
            is_test = false if line[/^}/]
          else
            is_empty = line.empty?()
            lines << line if (!is_empty || !prev_is_empty)
            prev_is_empty = is_empty
          end
        end
      end
    end
    lines
  end
end

class Export
  def initialize()
    @add_std = true
    @adds = []
    @mods = []
  end

  def add(fp)
    if md = /^src\/(.+)\.zig$/.match(fp)
      @adds << md[1]
    end

    stage = [Pathname.new(fp)]
    while !stage.empty?()
      new_stage = []

      stage.each do |fp|
        mod = Mod.new(fp)
        if @mods.none?{|m|m.path == mod.path}
          @mods << mod
          mod.imports do |fp|
            new_stage << fp
          end
        end
      end

      stage = new_stage
    end
  end

  def write()
    @lines = []
    @lines << "// Output from `rake export[#{@adds.join(',')}]` from https://github.com/gfannes/rubr from #{Time.now.strftime('%Y-%m-%d')}"
    @lines << '' << 'const std = @import("std");' if @add_std

    path = %w[]
    write_mods_(path)

    @lines.each do |line|
      puts(line)
    end
  end

  def write_mods_(path)
    @mods.each do |mod|
      if mod.path[0...mod.path.size-1] == path
        indent = '    '*path.size
        @lines << '' << indent+"// Export from '#{mod.fp}'" << indent+"pub const #{mod.name} = struct {"
        mod.lines.each do |line|
          if Hash === line
          else
            @lines << indent+'    '+line
          end
        end
        write_mods_(mod.path)
        @lines << indent+"};"
      end
    end
  end
end
