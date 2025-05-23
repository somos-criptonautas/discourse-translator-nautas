# frozen_string_literal: true

require "rails_helper"

describe BasicTopicSerializer do
  fab!(:user) { Fabricate(:user, locale: "ja") }
  fab!(:topic)

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.experimental_inline_translation = true
  end

  describe "#fancy_title" do
    let!(:guardian) { Guardian.new(user) }
    let!(:original_title) { "<h1>FUS ROH DAAHHH</h1>" }
    let!(:jap_title) { "<h1>フス・ロ・ダ・ア</h1>" }

    before do
      topic.title = original_title
      SiteSetting.experimental_inline_translation = true
      I18n.locale = "ja"

      SiteSetting.automatic_translation_backfill_rate = 1
      SiteSetting.automatic_translation_target_languages = "ja"
    end

    def serialize_topic(guardian_user: user, cookie: "")
      env = create_request_env.merge("HTTP_COOKIE" => cookie)
      request = ActionDispatch::Request.new(env)
      guardian = Guardian.new(guardian_user, request)
      BasicTopicSerializer.new(topic, scope: guardian)
    end

    it "does not replace fancy_title with translation when experimental_inline_translation is disabled" do
      SiteSetting.experimental_inline_translation = false
      topic.set_translation("ja", jap_title)

      expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
    end

    it "does not replace fancy_title with translation when show_original param is present" do
      topic.set_translation("ja", jap_title)
      expect(
        serialize_topic(
          cookie: DiscourseTranslator::InlineTranslation::SHOW_ORIGINAL_COOKIE,
        ).fancy_title,
      ).to eq(topic.fancy_title)
    end

    it "does not replace fancy_title with translation when no translation exists" do
      expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
    end

    it "does not replace fancy_title when topic is already in correct locale" do
      I18n.locale = "ja"
      topic.set_detected_locale("ja")
      topic.set_translation("ja", jap_title)

      expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
    end

    it "does not replace fancy_title when user's locale is not in target languages" do
      I18n.locale = "es"
      topic.set_detected_locale("en")
      topic.set_translation("es", jap_title)

      expect(serialize_topic.fancy_title).to eq(topic.fancy_title)
    end

    it "returns translated title in fancy_title when translation exists for current locale" do
      topic.set_translation("ja", jap_title)
      expect(serialize_topic.fancy_title).to eq("&lt;h1&gt;フス・ロ・ダ・ア&lt;/h1&gt;")
    end
  end
end
