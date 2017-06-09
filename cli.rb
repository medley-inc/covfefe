# frozon_string_literal: true
require 'uri'
require 'net/https'
require 'json'
require 'optparse'
require 'fileutils'

class CLI
  def initialize(argv)
    @argv = Array(argv)
    @name = ENV.fetch('COVFEFE_APPNAME', nil)
    @endpoint = ENV.fetch('COVFEFE_ENDPOINT', nil)
  end

  def perform
    case @argv.first
    when 'set'
      parser = OptionParser.new do |opts|
        common_options opts
      end
      remainings = parser.parse @argv[1..-1]
      Set.new(build_requestor, @name, remainings).perform
    when 'unset'
      parser = OptionParser.new do |opts|
        common_options opts
      end
      remainings = parser.parse @argv[1..-1]
      Unset.new(build_requestor, @name, remainings).perform
    else
      options = { format: :json }
      parser = OptionParser.new do |opts|
        common_options opts
        opts.on('-s') { options[:format] = :shell }
        opts.on('-d OUTPUT_PATH') do |v|
          options[:format] = :envdir
          options[:path] = v
        end
        opts.on('-j') { options[:format] = :json_array }
      end
      parser.parse @argv
      Show.new(build_requestor, { name: @name }.merge(options)).perform
    end
  end

  def build_requestor
    Requestor.new @endpoint
  end

  def common_options(opts)
    opts.on('-a NAME') { |v| @name = v }
    opts.on('-e ENDPOINT') { |v| @endpoint = v }
    opts
  end

  class Show
    attr_reader :requestor, :options

    def initialize(requestor, options)
      @requestor = requestor
      @options = options
    end

    def perform
      response = request
      exit! unless response.code == '200'

      response_body = JSON.parse response.body
      case options[:format]
      when :json
        puts JSON.pretty_generate response_body
      when :json_array
        puts JSON.pretty_generate(response_body.map { |name, value| { name: name, value: value } })
      when :shell
        puts response_body.map { |key, val|
          if val.empty?
            %(#{key}=)
          else
            %(#{key}='#{val}')
          end
        }.join("\n") << "\n"
      when :envdir
        path = File.expand_path options[:path]
        FileUtils.mkdir_p path
        response_body.each do |key, val|
          File.binwrite File.join(path, key), val
        end
      end
    end

    def request
      requestor.perform Net::HTTP::Get.new "/#{options[:name]}"
    end
  end

  class Set
    attr_reader :requestor, :name, :data

    def initialize(requestor, name, data)
      @requestor = requestor
      @name = name
      @data = data
    end

    def perform
      response = request
      exit! unless response.code == '200'
      puts JSON.pretty_generate JSON.parse(response.body)
    end

    def request
      requestor.perform generate_request
    end

    def generate_request
      Net::HTTP::Post.new("/#{name}/set").tap do |request|
        request.body = generate_body
      end
    end

    def generate_body
      data.map { |datum| datum.split('=', 2).map(&:to_s) }.to_h.to_json
    end
  end

  class Unset
    attr_reader :requestor, :name, :data

    def initialize(requestor, name, data)
      @requestor = requestor
      @name = name
      @data = data
    end

    def perform
      response = request
      exit! unless response.code == '200'
      puts JSON.pretty_generate JSON.parse(response.body)
    end

    def request
      requestor.perform generate_request
    end

    def generate_request
      Net::HTTP::Post.new("/#{name}/unset").tap do |request|
        request.body = generate_body
      end
    end

    def generate_body
      data.map { |datum| [datum, ''] }.to_h.to_json
    end
  end

  class Requestor
    attr_reader :uri

    def initialize(endpoint)
      @uri = URI(endpoint)
    end

    def perform(request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |client|
        request.basic_auth(uri.user.to_s, uri.password.to_s) if uri.user || uri.password
        client.request request
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  CLI.new(ARGV).perform
end
