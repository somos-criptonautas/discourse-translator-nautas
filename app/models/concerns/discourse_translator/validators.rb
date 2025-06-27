# frozen_string_literal: true

module DiscourseTranslator
  module Validators
    extend ActiveSupport::Concern

    class TranslatorSelectionValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        valid_providers = %w[Microsoft Google Amazon Yandex Deepl LibreTranslate DeepL]
        unless valid_providers.include?(value)
          record.errors.add(attribute, (options[:message] || :invalid_translator_provider))
        end
      end
    end
  end
end
