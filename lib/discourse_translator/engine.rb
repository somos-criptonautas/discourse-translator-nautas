# frozen_string_literal: true
module ::DiscourseTranslator
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseTranslator
  end
end

require_relative "parallel_text_translation"
