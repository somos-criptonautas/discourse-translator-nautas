# frozen_string_literal: true

require_relative 'base'
require 'json'

module DiscourseTranslator
  class Deepl < Base
    TRANSLATE_URI = "https://api-free.deepl.com/v2/translate".freeze
    DETECT_URI = "https://api-free.deepl.com/v2/translate".freeze
    SUPPORT_URI = "https://www.googleapis.com/language/translate/v2/languages".freeze
    MAXLENGTH = 5000

    SUPPORTED_LANG = {
      en: 'EN-US',
      bg: 'BG',
      en_GB: 'EN-GB',
      en_US: 'EN-US',
      cs: 'CS',
      de: 'DE',
      es: 'ES',
      fi: 'FI',
      fr: 'FR',
      it: 'IT',
      et: 'ET',
      hu: 'HU',
      ja: 'JA',
      lt: 'LT',
      lv: 'LV',
      nl: 'NL',
      pl: 'PL',
      pt: 'PT-PT',
      pt_br: 'PT-BR',
      ro: 'RO',
      sk: 'SK',
      sl: 'SL',
      sv: 'SV',
      zh_CN: 'ZH',
      zh_TW: 'ZH'
    }

    def self.access_token_key
      "deepl-translator"
    end

    def self.access_token
      SiteSetting.translator_deepl_api_key || (raise TranslatorError.new("NotFound: deepl Api Key not set."))
    end

    def self.detect(post)
      puts "detect"
      r=result(DETECT_URI,
          { text: post.cooked.truncate(MAXLENGTH, omission: nil),
            target_lang: SUPPORTED_LANG[I18n.locale]
          }
          )
      language = r[0]['detected_source_language']
      puts "Detected language: #{language}"
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= language          
    end

    def self.translate_supported?(source, target)
      puts "supported?"
      SUPPORTED_LANG[target]
      # res = result(SUPPORT_URI, target: SUPPORTED_LANG[target])
      # res["languages"].any? { |obj| obj["language"] == source }
      truef
    end

    def self.translate(post)
      # don't bother with detecting...
      detected_lang = detect(post)

      # raise I18n.t('translator.failed') unless translate_supported?(detected_lang, I18n.locale)

      translated_text = from_custom_fields(post) do
        res = result(TRANSLATE_URI,
          text: post.cooked.truncate(MAXLENGTH, omission: nil),
          #asource_lang: detected_lang,
          tag_handling: "xml",
          target_lang: SUPPORTED_LANG[I18n.locale]
        )
        puts "Translation: #{res[0]['text']}"
        res[0]["text"]
      end

      [detected_lang, translated_text]
    end    

    def self.result(url, body)
      response = Excon.post(url,
      body: URI.encode_www_form(body),
        headers: { "Content-Type" => "application/x-www-form-urlencoded",
                    "Authorization" => "DeepL-Auth-Key #{access_token}"  
        }
      )

      body = nil
      begin
        body = JSON.parse(response.body)
      rescue JSON::ParserError
      end

      if response.status != 200
        raise TranslatorError.new(body || response.inspect)
      else
        body["translations"]
      end
    end
  end
end
