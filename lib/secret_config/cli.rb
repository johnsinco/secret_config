require 'optparse'
require 'fileutils'
require 'erb'
require 'yaml'
require 'json'
require 'securerandom'
require 'irb'

module SecretConfig
  class CLI
    attr_reader :path, :region, :provider,
                :export, :no_filter,
                :import, :key_id, :random_size, :prune, :overwrite,
                :copy_path,
                :console,
                :show_version

    PROVIDERS = %i[ssm].freeze

    def self.run!(argv)
      new(argv).run!
    end

    def initialize(argv)
      @export       = false
      @import       = false
      @path         = nil
      @key_id       = nil
      @region       = ENV['AWS_REGION']
      @provider     = :ssm
      @random_size  = 32
      @no_filter    = false
      @prune        = false
      @replace      = false
      @copy_path    = nil
      @show_version = false
      @console      = false

      if argv.empty?
        puts parser
        exit(-10)
      end
      parser.parse!(argv)
    end

    def run!
      if show_version
        puts "Secret Config v#{VERSION}"
        puts "Region: #{region}"
      elsif console
        run_console
      elsif export
        run_export(export, filtered: !no_filter)
      elsif import
        run_import(import)
      elsif copy_path
        run_copy(copy_path, path)
      else
        puts parser
      end
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = <<~BANNER
          Secret Config v#{VERSION}

            For more information, see: https://rocketjob.github.io/secret_config/

          secret_config [options]
        BANNER

        opts.on '-e', '--export [FILE_NAME]', 'Export configuration to a file or stdout if no file_name supplied.' do |file_name|
          @export = file_name || STDOUT
        end

        opts.on '-i', '--import [FILE_NAME]', 'Import configuration from a file or stdin if no file_name supplied.' do |file_name|
          @import = file_name || STDIN
        end

        opts.on '-c', '--copy SOURCE_PATH', 'Import configuration from a file or stdin if no file_name supplied.' do |path|
          @copy_path = path
        end

        opts.on '-i', '--console', 'Start interactive console.' do
          @console = true
        end

        opts.on '-p', '--path PATH', 'Path to import from / export to.' do |path|
          @path = path
        end

        opts.on '-P', '--provider PROVIDER', 'Provider to use. [ssm | file]. Default: ssm' do |provider|
          @provider = provider.to_sym
        end

        opts.on '-U', '--no-filter', 'Do not filter passwords and keys.' do
          @no_filter = true
        end

        # TODO:
        # opts.on '-Q', '--prune', 'During import delete all existing keys for which their is no key in the import file' do
        #   @prune = true
        # end
        #
        # opts.on '-r', '--replace', 'During import replace existing keys if present' do
        #   @replace = true
        # end

        opts.on '-k', '--key_id KEY_ID', 'AWS KMS Key id or Key Alias to use when importing configuration values. Default: AWS Default key.' do |key_id|
          @key_id = key_id
        end

        opts.on '-r', '--region REGION', 'AWS Region to use. Default: AWS_REGION env var.' do |region|
          @region = region
        end

        opts.on '-R', '--random_size INTEGER', 'Size to use when generating random values. Whenever $random is encountered during an import. Default: 32' do |region|
          @random_size = random_size
        end

        opts.on '-v', '--version', 'Display Symmetric Encryption version.' do
          @show_version = true
        end

        opts.on('-h', '--help', 'Prints this help.') do
          puts opts
          exit
        end
      end
    end

    private

    def provider_instance
      @provider_instance ||= begin
        case provider
        when :ssm
          Providers::Ssm.new(key_id: key_id)
        else
          raise ArgumentError, "Invalid provider: #{provider}"
        end
      end
    end

    def run_export(file_name, filtered: true)
      config = fetch_config(path, filtered: filtered)

      format = file_format(file_name)
      data   = render(config, format)
      write_file(file_name, data)

      puts("Exported #{path} from #{provider} to #{file_name}") if file_name.is_a?(String)
    end

    def run_import(file_name)
      format = file_format(file_name)
      data   = read_file(file_name)
      config = parse(data, format)
      set_config(config, path)

      puts("Imported #{file_name} to #{provider} at #{path}") if file_name.is_a?(String)
    end

    def run_copy(source_path, target_path)
      config = fetch_config(source_path, filtered: false)

      set_config(config, target_path)

      puts "Copied #{source_path} to #{target_path} using #{provider}"
    end

    def run_console
      IRB.start
    end

    def set_config(config, path)
      # TODO: prune, replace
      Utils.flatten_each(config, path) do |key, value|
        next if value.nil?

        value = random_password if value.to_s.strip == '$random'
        puts "Setting: #{key}"
        provider_instance.set(key, value)
      end
    end

    def fetch_config(path, filtered: true)
      registry = Registry.new(path: path, provider: provider_instance)
      filtered ? registry.configuration : registry.configuration(filters: nil)
    end

    def read_file(file_name_or_io)
      return file_name_or_io.read unless file_name_or_io.is_a?(String)

      ::File.new(file_name_or_io).read
    end

    def write_file(file_name_or_io, data)
      return file_name_or_io.write(data) unless file_name_or_io.is_a?(String)

      output_path = ::File.dirname(file_name_or_io)
      FileUtils.mkdir_p(output_path) unless ::File.exist?(output_path)

      ::File.open(file_name_or_io, 'w') { |io| io.write(data) }
    end

    def render(hash, format)
      case format
      when :yml
        hash.to_yaml
      when :json
        hash.to_json
      else
        raise ArgumentError, "Invalid format: #{format.inspect}"
      end
    end

    def parse(data, format)
      case format
      when :yml
        YAML.load(ERB.new(data).result)
      when :json
        JSON.parse(data)
      else
        raise ArgumentError, "Invalid format: #{format.inspect}"
      end
    end

    def file_format(file_name)
      return :yml unless file_name.is_a?(String)

      case File.extname(file_name).downcase
      when '.yml', '.yaml'
        :yml
      when '.json'
        :json
      else
        raise ArgumentError, "Import/Export file name must end with '.yml' or '.json'"
      end
    end

    def random_password
      SecureRandom.urlsafe_base64(random_size)
    end
  end
end
