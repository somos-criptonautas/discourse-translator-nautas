# frozen_string_literal: true

module DiscourseTranslator
module Provider
class BaseProvider
  def self.key_prefix
    "#{PLUGIN_NAME}:".freeze
  end

  def self.access_token_key
    raise "Not Implemented"
  end

  def self.cache_key
    "#{key_prefix}#{access_token_key}"
  end

  def self.translate(text, source_lang, target_lang)
    raise "Not Implemented"
  end

  def self.detect_language(text)
    raise "Not Implemented"
  end

  def self.configured?
    raise "Not Implemented"
  end

  def self.translate_supported?(source_lang, target_lang)
    raise "Not Implemented"
  end
end
end
end
