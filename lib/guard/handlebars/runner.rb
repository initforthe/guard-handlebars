module Guard
  class Handlebars
    module Runner
      class << self

        def run(files, watchers, options = {})
          notify_start(files, options)
          changed_files, errors = compile_files(files, options, watchers)
          notify_result(changed_files, errors, options)

          changed_files
        end

      private

        def notify_start(files, options)
          message = options[:message] || "Compile #{ files.join(', ') }"
          Formatter.info(message, :reset => true)
        end

        def compile_files(files, options, watchers)
          errors        = []
          changed_files = []
          directories   = detect_nested_directories(watchers, files, options)

          directories.each do |directory, scripts|
            scripts.each do |file|
              begin
                content = compile(file, options)
                changed_files << process_compile_result(content, file, directory)
              rescue RuntimeError => e
                error_message = file + ': ' + e.message.to_s
                errors << error_message
                Formatter.error(error_message)
              end
            end
          end

          [changed_files.compact, errors]
        end

        def compile(file, options)
          path = options[:input] ? file.sub(%r(^#{options[:input]}/?), '') : file
          template = Template.new(path.sub(/\.handlebars$/, ''), File.read(file), options)
          template.compile
        end

        def process_compile_result(content, file, directory)
          FileUtils.mkdir_p(File.expand_path(directory)) if !File.directory?(directory)
          filename = File.join(directory, File.basename(file.gsub(/handlebars$/, 'js')))
          File.open(File.expand_path(filename), 'w') { |f| f.write(content) }

          filename
        end

        def detect_nested_directories(watchers, files, options)
          return { options[:output] => files } if options[:shallow]

          directories = {}

          watchers.product(files).each do |watcher, file|
            if matches = file.match(watcher.pattern)
              target = matches[1] ? File.join(options[:output], File.dirname(matches[1])).gsub(/\/\.$/, '') : options[:output]
              if directories[target]
                directories[target] << file
              else
                directories[target] = [file]
              end
            end
          end

          directories
        end

        def notify_result(changed_files, errors, options = {})
          if !errors.empty?
            Formatter.notify(errors.join("\n"), :title => 'Handlebars results', :image => :failed)
          elsif !options[:hide_success]
            message = "Successfully generated #{ changed_files.join(', ') }"
            Formatter.success(message)
            Formatter.notify(message, :title => 'Handlebars results')
          end
        end

      end
    end
  end
end
