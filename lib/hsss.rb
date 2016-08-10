require "hsss/version"
require 'digest/sha1'
require "pry"
module Hsss
  DEFAULT_STRUCT_NAME="redis_lua_scripts_t"
  DEFAULT_ROW_STRUCT_NAME="redis_lua_script_t"
  DEFAULT_HASHES_NAME="redis_lua_hashes"
  DEFAULT_NAMES_NAME="redis_lua_script_names"
  DEFAULT_SCRIPTS_NAME="redis_lua_scripts"
  DEFAULT_COUNT_NAME="redis_lua_scripts_count"
  DEFAULT_ITER_MACRO_NAME="REDIS_LUA_SCRIPTS_EACH"
  
  class COutput
    EXT="lua"
    attr_accessor :struct_name, :hashes_struct, :names_struct, :scripts_struct, :count_name, :iter_macro_name, :row_struct_name
    
    def initialize(files, opt={})
      @scripts={}
      { struct_name: DEFAULT_STRUCT_NAME, 
        row_struct_name: DEFAULT_ROW_STRUCT_NAME,
        hashes_struct: DEFAULT_HASHES_NAME,
        names_struct: DEFAULT_NAMES_NAME,
        scripts_struct: DEFAULT_SCRIPTS_NAME,
        count_name: DEFAULT_COUNT_NAME,
        iter_macro_name: DEFAULT_ITER_MACRO_NAME}.each do |var, default|
        send "#{var}=", opt[var]!=false ? opt[var] || default : false
      end
      
      if opt[:prefix]
        [:struct_name, :hashes_struct, :names_struct, :scripts_struct].each do |var|
          send "#{var}=", "#{opt[:prefix]}#{send var}" if send(var)
        end
      end
      @include_count = !opt[:skip_count]
      @include_iter_macro = !opt[:skip_each]
      
      (Array === files ? files : [ files ]).each do |f|
        begin
          file_contents = IO.read f
          if opt[:no_luac] or check_script(f)
            @scripts[File.basename(f, ".#{EXT}") .to_sym]=file_contents
          end
        rescue Errno::ENOENT => e
          STDERR.puts "Failed to open file #{f}"
          @failed = true
        end
      end
      
      @struct=[]
      @name_table=[]
      @script_table=[]
      @hashed_table=[]
      
      @scripts.sort_by {|k,v| k}.each do |v| 
        name=v.first
        script=v.last
        
        @name_table << name
        
        str=[]
        for l in script.lines do
          cmt=l.match /^--(.*)/
          break unless cmt
          str << "  //#{cmt[1]}"
        end
        str << "  #{script_name_line(name)}\n"
        @struct << str.join("\n")
        
        @script_table << script_string(name, script)
        
        @hashed_table << Digest::SHA1.hexdigest(script)
      end
    end
    
    def check_script(path)
      ret = system "luac -p #{path}"
      @failed = true unless ret
      ret
    end
    
    def cquote(str, line_start="")
      out=[]
      str.each_line do |l|
        l.gsub!("\\", '\\\\\\') #escape backslashes
        l.sub! "\n", "\\n"
        l.gsub! '"', '\"'
        l.gsub! /^(.*)$/, "#{line_start}\"\\1\""
        out << l
      end
      out.join "\n"
    end
    
    def failed?
      @failed
    end
  end
  
  class CSplit < COutput
    
    def initialize(files, opt={})
      super
      @head= <<-EOS.gsub(/^ {8}/, '')
        // don't edit this please, it was auto-generated by hsss
        // https://github.com/slact/hsss
        
        typedef struct {
        %s
        } #{struct_name};
        
      EOS
      @struct_fmt= <<-EOS.gsub(/^ {8}/, '')
        #{opt[:no_static] ? "" : "static "}#{struct_name} %s = {
        %s
        };
        
      EOS
    end
    
    def script_name_line(name)
      "char *#{name};"
    end
    
    def script_string(name, script)
      "  //#{name}\n#{cquote(script, "  ")}"
    end
    
    def to_s
      out = ""
        out << sprintf(@head, @struct.join("\n"))
      if @scripts.count > 0
        out << sprintf(@struct_fmt, hashes_struct, @hashed_table.map{|v|"  \"#{v}\""}.join(",\n")) if hashes_struct
        out << sprintf(@struct_fmt, names_struct, @name_table.map{|v|"  \"#{v}\","}.join("\n")) if names_struct
        out << sprintf(@struct_fmt, scripts_struct, @script_table.join(",\n\n")) if scripts_struct
      else
        out << "//no scrpts\n"
      end
      
      out << "const int #{@count_name}=#{@scripts.count};\n" if @include_count
      
      if @include_iter_macro
        macro = []
        macro << "#define #{iter_macro_name}(script_src, script_name, script_hash) \\"
        macro << "for((script_src)=(char **)&#{scripts_struct}, (script_hash)=(char **)&#{hashes_struct}, (script_name)=(char **)&#{names_struct}; (script_src) < (char **)(&#{scripts_struct} + 1); (script_src)++, (script_hash)++, (script_name)++) "
        out << macro.join("\n")
      end
      
      out
    end
    

  end
  
  
  
  class CWhole < COutput
    EXT="lua"
    
    def initialize(files, opt={})
      super
      @cout= <<-EOS.gsub(/^ {8}/, '')
        // don't edit this please, it was auto-generated by hsss
        // https://github.com/slact/hsss
        
        typedef struct {
          char *name;
          char *hash;
          char *script;
        } #{row_struct_name};
        
        typedef struct {
        %s
        } #{struct_name};
        
        #{opt[:no_static] ? "" : "static "}#{struct_name} #{scripts_struct} = {
        %s
        };
        
      EOS
      
    end
    
    def script_name_line(name) 
      "#{row_struct_name} #{name};"
    end
    def script_string(name, script)
      cquote(script, "   ")
    end
    def to_s
      if @scripts.count > 0
        scrapts=[]
        for i in 0...@scripts.count do
          scrapts<< "  {\"#{@name_table[i]}\", \"#{@hashed_table[i]}\",\n#{@script_table[i]}}"
        end
        out=sprintf @cout, @struct.join("\n"), scrapts.join(",\n\n")
      else
        out="//nothing here\n"
      end
      
      out << "const int #{@count_name}=#{@scripts.count};\n" if @include_count
      
      if @include_iter_macro
        macro = []
        macro << "#define #{iter_macro_name}(script) \\"
        macro << "for((script)=(#{row_struct_name} *)&#{scripts_struct}; (script) < (#{row_struct_name} *)(&#{scripts_struct} + 1); (script)++) "
        out << macro.join("\n")
      end
      
      out
    end
    
    def failed?
      @failed
    end
  end
  
  
end
