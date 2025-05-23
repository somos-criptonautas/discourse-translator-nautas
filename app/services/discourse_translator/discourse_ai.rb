# frozen_string_literal: true

module DiscourseTranslator
  class DiscourseAi < Base
    MAX_DETECT_LOCALE_TEXT_LENGTH = 1000
    def self.language_supported?(detected_lang)
      locale_without_region = I18n.locale.to_s.split("_").first
      detected_lang != locale_without_region
    end

    def self.detect!(topic_or_post)
      unless required_settings_enabled
        raise TranslatorError.new(
                I18n.t(
                  "translator.discourse_ai.ai_helper_required",
                  { base_url: Discourse.base_url },
                ),
              )
      end

      ::DiscourseAi::LanguageDetector.new(text_for_detection(topic_or_post)).detect
    end

    def self.translate!(translatable, target_locale_sym = I18n.locale)
      unless required_settings_enabled
        raise TranslatorError.new(
                I18n.t(
                  "translator.discourse_ai.ai_helper_required",
                  { base_url: Discourse.base_url },
                ),
              )
      end

      language = get_language_name(target_locale_sym)
      translated =
        case translatable.class.name
        when "Post"
          text = text_for_translation(translatable, raw: true)
          chunks = DiscourseTranslator::ContentSplitter.split(text)
          chunks
            .map { |chunk| ::DiscourseAi::PostTranslator.new(chunk, target_locale_sym).translate }
            .join("")
        when "Topic"
          ::DiscourseAi::TopicTranslator.new(text_for_translation(translatable), language).translate
        end

      DiscourseTranslator::TranslatedContentNormalizer.normalize(translatable, translated)
    end

    private

    def self.required_settings_enabled
      SiteSetting.translator_enabled && SiteSetting.translator_provider == "DiscourseAi" &&
        SiteSetting.discourse_ai_enabled && SiteSetting.ai_helper_enabled
    end

    def self.get_language_name(target_locale_sym)
      LocaleSiteSetting.language_names.dig(target_locale_sym.to_s, "name") ||
        "locale \"#{target_locale_sym}\""
    end
  end
end
