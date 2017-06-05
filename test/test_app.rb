ENV['RACK_ENV'] ||= 'test'
ENV['MONGOLAB_URI'] = 'mongodb://localhost:27017/covfefe-test'
require 'minitest/autorun'
require_relative '../app'

describe App do
  include Rack::Test::Methods

  after do
    MONGO.collections.each(&:drop)
  end

  def app
    App
  end

  def last_response_json_body
    JSON.parse last_response.body
  end

  describe 'POST /:name/set' do
    it 'return json' do
      post_json '/sample_name/set', { 'qqq' => 'ppp' }.to_json
      assert last_response_json_body == { 'qqq' => 'ppp' }
    end

    it 'newline' do
      post_json '/sample_name/set', { 'qqq' => "p\np\np" }.to_json
      assert last_response_json_body == { 'qqq' => "p\np\np" }
    end

    describe 'exists' do
      before do
        post_json '/sample_name/set', { 'qqq' => 'ppp' }.to_json
      end

      it 'append' do
        post_json '/sample_name/set', { 'ppp' => 'qqq' }.to_json
        assert last_response_json_body == { 'qqq' => 'ppp', 'ppp' => 'qqq' }
      end

      it 'overwrite' do
        post_json '/sample_name/set', { 'qqq' => '999' }.to_json
        assert last_response_json_body == { 'qqq' => '999' }
      end

      it 'ignore' do
        post_json '/sample_name/set', { '' => 'xxx' }.to_json
        assert last_response_json_body == { 'qqq' => 'ppp' }
      end
    end
  end

  describe 'POST /:name/unset' do
    before do
      post_json '/sample_name/set', { 'a' => 'alpha', 'b' => 'bravo' }.to_json
    end

    it 'return json' do
      post_json '/sample_name/unset', { 'a' => '' }.to_json
      assert last_response_json_body == { 'b' => 'bravo' }
    end

    it 'ignore' do
      post_json '/sample_name/unset', { 'c' => '' }.to_json
      assert last_response_json_body == { 'a' => 'alpha', 'b' => 'bravo' }
    end
  end

  describe 'GET /:name' do
    before do
      post_json '/sample_name/set', { 'a' => 'alpha', 'b' => 'bravo' }.to_json
    end

    it 'json' do
      get '/sample_name'
      assert last_response_json_body == { 'a' => 'alpha', 'b' => 'bravo' }
    end
  end

  def post_json(uri, json)
    post uri, json, 'CONTENT_TYPE' => 'application/json'
  end
end
