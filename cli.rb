# frozon_string_literal: true
require 'uri'
require 'net/https'
require 'json'
require 'optparse'

class CLI
  def initialize(argv)
    @argv = Array(argv)
    @name = ''
    @format = ''
    @endpoint = 'http://localhost:9393'
  end

  def perform
    case @argv.first
    when 'set'
      remainings = common_options(OptionParser.new).parse(@argv[1..-1])
      Set.new(@name, @endpoint, remainings).perform
    when 'unset'
      remainings = common_options(OptionParser.new).parse(@argv[1..-1])
      Unset.new(@name, @endpoint, remainings).perform
    else
      parser = OptionParser.new do |opts|
        common_options opts
        opts.on('-s') { @format = '.sh' }
      end
      parser.parse @argv
      Show.new(@name, @format, @endpoint).perform
    end
  end

  def common_options(opts)
    opts.on('-a NAME') { |v| @name = v }
    opts.on('-e ENDPOINT') { |v| @endpoint = v }
    opts
  end

  class Unset
    attr_accessor :name, :format, :endpoint
    attr_reader :uri, :data

    def initialize(name, endpoint, data)
      @name = name
      @endpoint = endpoint
      @uri = URI(endpoint)
      @data = data
    end

    def generate_body
      data.map { |datum| [datum, ''] }.to_h.to_json
    end

    def perform
      klass = uri.scheme == 'https' ? Net::HTTPS : Net::HTTP
      klass.start(uri.host, uri.port) do |client|
        request = Net::HTTP::Post.new "/#{name}/unset"
        request.body = generate_body
        client.request(request) do |response|
          puts response.body
        end
      end
    end
  end

  class Set
    attr_accessor :name, :format, :endpoint
    attr_reader :uri, :data

    def initialize(name, endpoint, data)
      @name = name
      @endpoint = endpoint
      @uri = URI(endpoint)
      @data = data
    end

    def generate_body
      result = {}
      data.each do |datum|
        key, val = datum.split('=', 2)
        result[key.to_s] = val.to_s
      end
      result.to_json
    end

    def perform
      klass = uri.scheme == 'https' ? Net::HTTPS : Net::HTTP
      klass.start(uri.host, uri.port) do |client|
        request = Net::HTTP::Post.new "/#{name}/set"
        request.body = generate_body
        client.request(request) do |response|
          puts response.body
        end
      end
    end
  end

  class Show
    attr_accessor :name, :format, :endpoint
    attr_reader :uri

    def initialize(name, format, endpoint)
      @name = name
      @format = format
      @endpoint = endpoint
      @uri = URI(endpoint)
    end

    def perform
      klass = uri.scheme == 'https' ? Net::HTTPS : Net::HTTP
      klass.start(uri.host, uri.port) do |client|
        request = Net::HTTP::Get.new "/#{name}#{format}"
        client.request(request) do |response|
          puts response.body
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  CLI.new(ARGV).perform
end
