# frozen_string_literal: true

describe Jobs::AutomaticTranslationBackfill do
  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator_provider = "Google"
    SiteSetting.translator_google_api_key = "api_key"
  end

  def expect_google_check_language
    Excon
      .expects(:post)
      .with(DiscourseTranslator::Google::SUPPORT_URI, anything, anything)
      .returns(
        Struct.new(:status, :body).new(
          200,
          %{ { "data": { "languages": [ { "language": "es" }, { "language": "de" }] } } },
        ),
      )
      .at_least_once
  end

  def expect_google_detect(locale)
    Excon
      .expects(:post)
      .with(DiscourseTranslator::Google::DETECT_URI, anything, anything)
      .returns(
        Struct.new(:status, :body).new(
          200,
          %{ { "data": { "detections": [ [ { "language": "#{locale}" } ] ] } } },
        ),
      )
      .once
  end

  def expect_google_translate(text)
    Excon
      .expects(:post)
      .with(DiscourseTranslator::Google::TRANSLATE_URI, body: anything, headers: anything)
      .returns(
        Struct.new(:status, :body).new(
          200,
          %{ { "data": { "translations": [ { "translatedText": "#{text}" } ] } } },
        ),
      )
  end

  describe "backfilling" do
    it "does not backfill if translator is disabled" do
      SiteSetting.translator_enabled = false
      expect_any_instance_of(Jobs::AutomaticTranslationBackfill).not_to receive(:process_batch)
      described_class.new.execute
    end

    it "does not backfill if backfill languages are not set" do
      SiteSetting.automatic_translation_target_languages = ""
      expect_any_instance_of(Jobs::AutomaticTranslationBackfill).not_to receive(:process_batch)
      described_class.new.execute
    end

    it "does not backfill if backfill limit is set to 0" do
      SiteSetting.automatic_translation_backfill_rate = 1
      SiteSetting.automatic_translation_target_languages = "de"
      SiteSetting.automatic_translation_backfill_rate = 0
      expect_any_instance_of(Jobs::AutomaticTranslationBackfill).not_to receive(:process_batch)
    end

    describe "with two locales ['de', 'es']" do
      before do
        SiteSetting.automatic_translation_backfill_rate = 100
        SiteSetting.automatic_translation_target_languages = "de|es"
        SiteSetting.automatic_translation_backfill_limit_to_public_content = true
        SiteSetting.automatic_translation_backfill_max_age_days = 5
        expect_google_check_language
      end

      it "backfills if topic is not in target languages" do
        expect_google_detect("de")
        expect_google_translate("hola")
        topic = Fabricate(:topic)

        described_class.new.execute

        expect(topic.translations.pluck(:locale, :translation)).to eq([%w[es hola]])
      end

      it "backfills both topics and posts" do
        post = Fabricate(:post)
        topic = post.topic

        topic.set_detected_locale("de")
        post.set_detected_locale("es")

        expect_google_translate("hola")
        expect_google_translate("hallo")

        described_class.new.execute

        expect(topic.translations.pluck(:locale, :translation)).to eq([%w[es hola]])
        expect(post.translations.pluck(:locale, :translation)).to eq([%w[de hallo]])
      end

      it "backfills only public content when limit_to_public_content is true" do
        post = Fabricate(:post)
        topic = post.topic

        private_category = Fabricate(:private_category, name: "Staff", group: Group[:staff])
        private_topic = Fabricate(:topic, category: private_category)
        private_post = Fabricate(:post, topic: private_topic)

        topic.set_detected_locale("de")
        post.set_detected_locale("es")
        private_topic.set_detected_locale("de")
        private_post.set_detected_locale("es")

        expect_google_translate("hola")
        expect_google_translate("hallo")

        SiteSetting.automatic_translation_backfill_limit_to_public_content = true
        described_class.new.execute

        expect(topic.translations.pluck(:locale, :translation)).to eq([%w[es hola]])
        expect(post.translations.pluck(:locale, :translation)).to eq([%w[de hallo]])

        expect(private_topic.translations).to eq([])
        expect(private_post.translations).to eq([])
      end

      it "translate only content newer than automatic_translation_backfill_max_age_days" do
        old_post = Fabricate(:post)
        old_topic = old_post.topic
        new_post = Fabricate(:post)
        new_topic = new_post.topic

        old_topic.set_detected_locale("de")
        new_topic.set_detected_locale("de")
        old_post.set_detected_locale("es")
        new_post.set_detected_locale("es")

        old_topic.created_at = 5.days.ago
        old_topic.save!
        old_post.created_at = 5.days.ago
        old_post.save!
        new_topic.created_at = 1.days.ago
        new_topic.save!
        new_post.created_at = 1.days.ago
        new_post.save!

        expect_google_translate("hola")
        expect_google_translate("hallo")

        SiteSetting.automatic_translation_backfill_max_age_days = 3
        described_class.new.execute

        expect(old_post.translations).to eq([])
        expect(new_post.translations.pluck(:locale, :translation)).to eq([%w[de hallo]])
      end
    end

    describe "with just one locale ['de']" do
      before do
        SiteSetting.automatic_translation_backfill_rate = 100
        SiteSetting.automatic_translation_target_languages = "de"
        expect_google_check_language
      end

      it "backfills all (1) topics and (4) posts as it is within the maximum per job run" do
        topic = Fabricate(:topic)
        posts = Fabricate.times(4, :post, topic: topic)

        topic.set_detected_locale("es")
        posts.each { |p| p.set_detected_locale("es") }

        expect_google_translate("hallo").times(5)

        described_class.new.execute

        expect(topic.translations.pluck(:locale, :translation)).to eq([%w[de hallo]])
        expect(posts.map { |p| p.translations.pluck(:locale, :translation).flatten }).to eq(
          [%w[de hallo]] * 4,
        )
      end
    end
  end

  describe ".fetch_untranslated_model_ids" do
    fab!(:posts_1) { Fabricate.times(2, :post) }
    fab!(:post_1) { Fabricate(:post) }
    fab!(:post_2) { Fabricate(:post) }
    fab!(:post_3) { Fabricate(:post) }
    fab!(:posts_2) { Fabricate.times(2, :post) }
    fab!(:post_4) { Fabricate(:post) }
    fab!(:post_5) { Fabricate(:post) }
    fab!(:post_6) { Fabricate(:post) }
    fab!(:post_7) { Fabricate(:post) }
    fab!(:posts_3) { Fabricate.times(2, :post) }

    before do
=begin
This is the scenario we are testing for:
    | Post ID | detected_locale | translations | selected? | Why? |
    |---------|-----------------|--------------|-----------|------|
    |   1     | en              | none         | YES       | source not de
    |   2     | null            | es           | YES       | missing de translation
    |   3     | null            | de           | NO        | has de translation
    |   4     | de              | es           | NO        | source is de and has es translation
    |   5     | de              | de           | NO        | both source and translation is de, missing es translation
    |   6     | null            | none         | YES       | no detected locale nor translation
=end

      [posts_1, posts_2, posts_3].flatten.each { |post| post.set_detected_locale("de") }

      post_1.set_detected_locale("en")
      post_4.set_detected_locale("de")
      post_5.set_detected_locale("de")

      post_2.set_translation("es", "hola")
      post_3.set_translation("de", "hallo")
      post_4.set_translation("es", "hola")
      post_5.set_translation("de", "hallo")
    end

    it "returns correct post ids needing translation in descending updated_at" do
      # based on the table above, we will return post_6, post_2, post_1
      # but we will jumble its updated_at to test if it is sorted correctly
      post_6.update!(updated_at: 1.day.ago)
      post_1.update!(updated_at: 2.days.ago)
      post_2.update!(updated_at: 3.days.ago)

      result = described_class.new.fetch_untranslated_model_ids(Post, "raw", 50, "de")
      expect(result).to include(post_6.id, post_1.id, post_2.id)
    end

    it "does not return posts that are deleted" do
      post_1.trash!
      result = described_class.new.fetch_untranslated_model_ids(Post, "raw", 50, "de")
      expect(result).not_to include(post_1.id)
    end

    it "does not return posts that are empty" do
      post_1.raw = ""
      post_1.save!(validate: false)
      result = described_class.new.fetch_untranslated_model_ids(Post, "raw", 50, "de")
      expect(result).not_to include(post_1.id)
    end

    it "does not return posts by bots" do
      post_1.update(user: Discourse.system_user)

      result = described_class.new.fetch_untranslated_model_ids(Post, "raw", 50, "de")

      expect(result).not_to include(post_1.id)
    end
  end
end
