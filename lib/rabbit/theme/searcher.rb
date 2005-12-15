require 'rabbit/theme/entry'

module Rabbit
  module Theme
    module Searcher
      def initialize(*args, &blocks)
        @theme_stack = []
        @image_entries = []
        super
      end

      def push_theme(entry)
        @theme_stack.push(entry)
      end

      def pop_theme
        @theme_stack.pop
      end

      def in_theme(entry)
        push_theme(entry)
        yield(entry)
      ensure
        pop_theme
      end

      def add_image_path(name)
        @image_entries << find_theme(name, true)
      end

      # for backward compatibility
      alias add_theme_path add_image_path
      
      module_function
      def theme_dir(base_dir)
        File.join(base_dir, 'rabbit', 'theme')
      end
      
      def image_dir(base_dir)
        File.join(base_dir, 'rabbit', 'image')
      end

      def find_theme(theme_name=name, only_image=false)
        if only_image
          collector = "collect_image_theme"
        else
          collector = "collect_all_theme"
        end
        found_entry = nil
        __send__(collector) do |entry|
          if theme_name == entry.name
            found_entry = entry
            break
          end
        end
        raise LoadError, "can't find theme: #{theme_name}." if found_entry.nil?
        found_entry
      end

      def find_file(target, themes=nil)
        themes ||= @theme_stack + @image_entries
        found_entry = themes.find do |entry|
          entry.have_file?(target)
        end
        if found_entry.nil?
          names = themes.collect {|entry| entry.name}
          raise LoadError,
                "can't find file in themes #{names.inspect}: #{target}."
        end
        found_entry.full_path(target)
      end

      def collect_all_theme(&block)
        collect_theme(&block) + collect_image_theme(&block)
      end

      def collect_theme(&block)
        _collect_theme($LOAD_PATH, &block)
      end

      def collect_image_theme(&block)
        _collect_theme($LOAD_PATH + Config::IMAGE_PATH,
                       "image_dir", :image, &block)
      end
      
      def _collect_theme(path, converter=nil, type=nil, &block)
        converter ||= "theme_dir"
        themes = []
        theme_name = {}
        path.each do |dir|
          base_name = __send__(converter, dir)
          if File.directory?(base_name)
            Dir.foreach(base_name) do |theme|
              next if /\A..?\z/ =~ theme
              entry = Entry.new(File.join(File.expand_path(base_name), theme),
                                type)
              if entry.available? and !theme_name.has_key?(theme)
                block.call(entry) if block
                themes << entry
                theme_name[theme] = true
              end
            end
          end
        end
        themes.sort
      end
    end
  end
end
