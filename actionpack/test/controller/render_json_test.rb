# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"
require "active_support/logger"
require "active_support/core_ext/object/with"

class RenderJsonTest < ActionController::TestCase
  class JsonRenderable
    def as_json(options = {})
      hash = { a: :b, c: :d, e: :f }
      hash.except!(*options[:except]) if options[:except]
      hash
    end

    def to_json(options = {})
      super except: [:c, :e]
    end
  end

  class InspectOptions
    def as_json(options = {})
      { options: options }
    end
  end

  class TestController < ActionController::Base
    protect_from_forgery

    def self.controller_path
      "test"
    end

    def render_json_nil
      render json: nil
    end

    def render_json_hello_world
      render json: ActiveSupport::JSON.encode(hello: "world")
    end

    def render_json_hello_world_with_status
      render json: ActiveSupport::JSON.encode(hello: "world"), status: 401
    end

    def render_json_hello_world_with_callback
      render json: ActiveSupport::JSON.encode(hello: "world"), callback: "alert"
    end

    def render_json_unsafe_chars_with_callback
      render json: { hello: "\u2028\u2029<script>" }, callback: "alert"
    end

    def render_json_unsafe_chars_without_callback
      render json: { hello: "\u2028\u2029<script>" }
    end

    def render_json_with_custom_content_type
      render json: ActiveSupport::JSON.encode(hello: "world"), content_type: "text/javascript"
    end

    def render_symbol_json
      render json: ActiveSupport::JSON.encode(hello: "world")
    end

    def render_json_with_render_to_string
      render json: { hello: render_to_string(partial: "partial") }
    end

    def render_json_with_extra_options
      render json: JsonRenderable.new, except: [:c, :e]
    end

    def render_json_without_options
      render json: JsonRenderable.new
    end

    def render_json_inspect_options
      render json: InspectOptions.new
    end
  end

  tests TestController

  def setup
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    super
    @controller.logger = ActiveSupport::Logger.new(nil)

    @request.host = "www.nextangle.com"
  end

  def test_render_json_nil
    get :render_json_nil
    assert_equal "null", @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json
    get :render_json_hello_world
    assert_equal '{"hello":"world"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_with_status
    get :render_json_hello_world_with_status
    assert_equal '{"hello":"world"}', @response.body
    assert_equal 401, @response.status
  end

  def test_render_json_with_callback
    get :render_json_hello_world_with_callback, xhr: true
    assert_equal '/**/alert({"hello":"world"})', @response.body
    assert_equal "text/javascript", @response.media_type
  end

  def test_render_json_with_callback_escapes_js_chars
    get :render_json_unsafe_chars_with_callback, xhr: true
    assert_equal '/**/alert({"hello":"\\u2028\\u2029\\u003cscript\\u003e"})', @response.body
    assert_equal "text/javascript", @response.media_type
  end

  def test_render_json_with_new_default_and_without_callback_does_not_escape_js_chars
    msg = <<~MSG.squish
      Setting action_controller.escape_json_responses = true is deprecated and will have no effect in Rails 8.2.
      Set it to `false`, or remove the config.
    MSG

    assert_deprecated(msg, ActionController.deprecator) do
      TestController.with(escape_json_responses: false) do
        get :render_json_unsafe_chars_without_callback
        assert_equal %({"hello":"\u2028\u2029<script>"}), @response.body
        assert_equal "application/json", @response.media_type
      end
    end
  end

  def test_render_json_with_optional_escape_option_is_not_deprecated
    @before_escape_json_responses = @controller.class.escape_json_responses

    assert_not_deprecated(ActionController.deprecator) do
      @controller.class.escape_json_responses = false
    end

    get :render_json_unsafe_chars_without_callback
    assert_equal %({"hello":"\u2028\u2029<script>"}), @response.body
    assert_equal "application/json", @response.media_type
  ensure
    ActionController.deprecator.silence do
      @controller.class.escape_json_responses = @before_escape_json_responses
    end
  end

  def test_render_json_with_redundant_escape_option_is_deprecated
    @before_escape_json_responses = @controller.class.escape_json_responses

    msg = <<~MSG.squish
      Setting action_controller.escape_json_responses = true is deprecated and will have no effect in Rails 8.2.
      Set it to `false`, or remove the config.
    MSG

    assert_deprecated(msg, ActionController.deprecator) do
      @controller.class.escape_json_responses = true
    end

    get :render_json_unsafe_chars_without_callback
    assert_equal '{"hello":"\\u2028\\u2029\\u003cscript\\u003e"}', @response.body
    assert_equal "application/json", @response.media_type
  ensure
    ActionController.deprecator.silence do
      @controller.class.escape_json_responses = @before_escape_json_responses
    end
  end

  def test_set_escape_json_responses_class_method_is_deprecated
    @before_escape_json_responses = @controller.class.escape_json_responses

    msg = <<~MSG.squish
      Setting action_controller.escape_json_responses = true is deprecated and will have no effect in Rails 8.2.
      Set it to `false`, or remove the config.
    MSG

    assert_deprecated(msg, ActionController.deprecator) do
      @controller.class.escape_json_responses = true
    end

    get :render_json_unsafe_chars_without_callback
    assert_equal '{"hello":"\\u2028\\u2029\\u003cscript\\u003e"}', @response.body
    assert_equal "application/json", @response.media_type
  ensure
    ActionController.deprecator.silence do
      @controller.class.escape_json_responses = @before_escape_json_responses
    end
  end

  def test_set_escape_json_responses_controller_method_is_deprecated
    @before_escape_json_responses = @controller.class.escape_json_responses

    msg = <<~MSG.squish
      Setting action_controller.escape_json_responses = true is deprecated and will have no effect in Rails 8.2.
      Set it to `false`, or remove the config.
    MSG

    assert_deprecated(msg, ActionController.deprecator) do
      @controller.class.escape_json_responses = true
    end

    get :render_json_unsafe_chars_without_callback
    assert_equal '{"hello":"\\u2028\\u2029\\u003cscript\\u003e"}', @response.body
    assert_equal "application/json", @response.media_type
  ensure
    ActionController.deprecator.silence do
      @controller.class.escape_json_responses = @before_escape_json_responses
    end
  end

  def test_render_json_with_custom_content_type
    get :render_json_with_custom_content_type, xhr: true
    assert_equal '{"hello":"world"}', @response.body
    assert_equal "text/javascript", @response.media_type
  end

  def test_render_symbol_json
    get :render_symbol_json
    assert_equal '{"hello":"world"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_with_render_to_string
    get :render_json_with_render_to_string
    assert_equal '{"hello":"partial html"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_forwards_extra_options
    get :render_json_with_extra_options
    assert_equal '{"a":"b"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_calls_to_json_from_object
    get :render_json_without_options
    assert_equal '{"a":"b"}', @response.body
  end

  def test_render_json_avoids_view_options
    get :render_json_inspect_options
    assert_equal '{"options":{}}', @response.body
  end
end
