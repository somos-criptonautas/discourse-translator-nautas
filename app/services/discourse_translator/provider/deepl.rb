# frozen_string_literal: true

module DiscourseTranslator
module Provider
class Deepl < BaseProvider
DEEPL_FREE_URL = "https://api-free.deepl.com/v2/translate"
DEEPL_PRO_URL = "https://api.deepl.com/v2/translate"
DEEPL_DETECT_URL_FREE = "https://api-free.deepl.com/v2/languages"
DEEPL_DETECT_URL_PRO = "https://api.deepl.com/v2/languages"

  SUPPORTED_LANGUAGES = {
    'ar' => 'AR',
    'bg' => 'BG',
    'cs' => 'CS',
    'da' => 'DA',
    'de' => 'DE',
    'el' => 'EL',
    'en' => 'EN-US',
    'es' => 'ES',
    'et' => 'ET',
    'fi' => 'FI',
    'fr' => 'FR',
    'he' => 'HE',
    'hu' => 'HU',
    'id' => 'ID',
    'it' => 'IT',
    'ja' => 'JA',
    'ko' => 'KO',
    'lt' => 'LT',
    'lv' => 'LV',
    'nb' => 'NB',
    'nl' => 'NL',
    'pl' => 'PL',
    'pt' => 'PT-PT',
    'ro' => 'RO',
    'ru' => 'RU',
    'sk' => 'SK',
    'sl' => 'SL',
    'sv' => 'SV',
    'th' => 'TH',
    'tr' => 'TR',
    'uk' => 'UK',
    'vi' => 'VI',
    'zh' => 'ZH-HANS'
  }.freeze

  def self.configured?
    SiteSetting.translator_deepl_api_key.present?
  end

  def self.translate_supported?(source_lang, target_lang)
    SUPPORTED_LANGUAGES.key?(source_lang) && SUPPORTED_LANGUAGES.key?(target_lang)
  end

  def self.detect_language(text)
    return if text.blank?

    api_key = SiteSetting.translator_deepl_api_key
    url = api_key.end_with?(':fx') ? DEEPL_DETECT_URL_FREE : DEEPL_DETECT_URL_PRO

    response = Faraday.post(url, {
      auth_key: api_key,
      text: text
    })

    if response.status == 200
      result = JSON.parse(response.body)
      detected_lang = result.dig('detections', 0, 'language')&.downcase
      SUPPORTED_LANGUAGES.key?(detected_lang) ? detected_lang : nil
    else
      error_msg = JSON.parse(response.body)['message'] rescue response.body
      raise TranslatorError.new("DeepL API Error: #{error_msg}")
    end
  rescue JSON::ParserError, Faraday::Error => e
    raise TranslatorError.new("DeepL API Error: #{e.message}")
  end

  def self.translate(text, source_lang, target_lang)
    return if text.blank?

    api_key = SiteSetting.translator_deepl_api_key
    url = api_key.end_with?(':fx') ? DEEPL_FREE_URL : DEEPL_PRO_URL

    source_code = SUPPORTED_LANGUAGES[source_lang]
    target_code = SUPPORTED_LANGUAGES[target_lang]

    response = Faraday.post(url, {
      auth_key: api_key,
      text: text,
      source_lang: source_code,
      target_lang: target_code,
      preserve_formatting: '1',
      tag_handling: 'html'
    })

    if response.status == 200
      result = JSON.parse(response.body)
      result.dig('translations', 0, 'text')
    else
      error_msg = JSON.parse(response.body)['message'] rescue response.body
      raise TranslatorError.new("DeepL API Error: #{error_msg}")
    end
  rescue JSON::ParserError, Faraday::Error => e
    raise TranslatorError.new("DeepL API Error: #{e.message}")
  end
end

end
end
