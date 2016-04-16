require "hsss/version"
require 'digest/sha1'

module Hsss
  DEFAULT_STRUCT_NAME="redis_lua_script_t"
  DEFAULT_HASHES_NAME="redis_lua_hashes"
  DEFAULT_NAMES_NAME="redis_lua_script_names"
  DEFAULT_SCRIPTS_NAME="redis_lua_scripts"
  DEFAULT_COUNT_NAME="redis_lua_scripts_count"
  
  class Hsss
    EXT="lua"
    
    attr_accessor :struct_name, :hashes_struct, :names_struct, :scripts_struct, :count_name
    def initialize(files, opt={})
      @scripts={}
      
      { struct_name: DEFAULT_STRUCT_NAME, 
        hashes_struct: DEFAULT_HASHES_NAME,
        names_struct: DEFAULT_NAMES_NAME,
        scripts_struct: DEFAULT_SCRIPTS_NAME,
        count_name: DEFAULT_COUNT_NAME}.each do |var, default|
        send "#{var}=", opt[var] || default
      end
      
      if opt[:prefix]
        [:struct_name, :hashes_struct, :names_struct, :scripts_struct].each do |var|
          send "#{var}=", "#{opt[:prefix]}#{send var}"
        end
      end
      @include_count = !opt[:skip_count]
      
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
      
      @cout= <<-EOS.gsub(/^ {8}/, '')
        //don't edit this please, it was auto-generated
        
        typedef struct {
        %s
        } #{struct_name};
        
        static #{struct_name} #{hashes_struct} = {
        %s
        };
        
        static #{struct_name} #{names_struct} = {
        %s
        };
        
        static #{struct_name} #{scripts_struct} = {
        %s
        };
        
      EOS
      
      @struct=[]
      @name_table=[]
      @script_table=[]
      @hashed_table=[]
      
      @scripts.sort_by {|k,v| k}.each do |v| 
        name=v.first
        script=v.last
        
        @name_table << "  \"#{name}\","
        
        str=[]
        for l in script.lines do
          cmt=l.match /^--(.*)/
          break unless cmt
          str << "  //#{cmt[1]}"
        end
        str << "  char *#{name};\n"
        @struct << str.join("\n")
        
        @script_table << "  //#{name}\n#{cquote(script)}"
        
        @hashed_table << "  \"#{Digest::SHA1.hexdigest script}\""
      end
      
    end
    
    def check_script(path)
      ret = system "luac -p #{path}"
      @failed = true unless ret
      ret
    end
    
    def cquote(str)
      out=[]
      str.each_line do |l|
        l.sub! "\n", "\\n"
        l.gsub! '"', '\"'
        l.gsub! /^(.*)$/, "  \"\\1\""
        out << l
      end
      out.join "\n"
    end
    
    def to_s
      if @scripts.count > 0
        out=sprintf @cout, @struct.join("\n"), @hashed_table.join(",\n"),  @name_table.join("\n"), @script_table.join(",\n\n")
      else
        out="//nothing here\n"
      end
      
      out<< "const int #{@count_name}=#{@scripts.count};\n" if @include_count
      out
    end
    
    def failed?
      @failed
    end
  end
end
