import { withPluginApi } from "discourse/lib/plugin-api";
import LanguageSwitcher from "../components/language-switcher";
import ToggleTranslationButton from "../components/post-menu/toggle-translation-button";
import ShowOriginalContent from "../components/show-original-content";
import TranslatedPost from "../components/translated-post";

function initializeTranslation(api) {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.translator_enabled) {
    return;
  }

  const currentUser = api.getCurrentUser();

  if (
    !currentUser &&
    siteSettings.experimental_anon_language_switcher &&
    siteSettings.automatic_translation_target_languages
  ) {
    api.headerIcons.add(
      "discourse-translator_language-switcher",
      LanguageSwitcher,
      { before: ["search"] }
    );
  }

  if (
    siteSettings.experimental_inline_translation &&
    (currentUser || siteSettings.experimental_anon_language_switcher)
  ) {
    api.renderInOutlet("topic-navigation", ShowOriginalContent);

    api.registerCustomPostMessageCallback(
      "translated_post",
      (topicController, data) => {
        if (
          new URLSearchParams(window.location.search).get("show") === "original"
        ) {
          return;
        }
        const postStream = topicController.get("model.postStream");
        postStream.triggerChangedPost(data.id, data.updated_at).then(() => {
          topicController.appEvents.trigger("post-stream:refresh", {
            id: data.id,
          });
        });
      }
    );
  }

  customizePostMenu(api);
}

function customizePostMenu(api) {
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { firstButtonKey } }) => {
      dag.add("translate", ToggleTranslationButton, { before: firstButtonKey });
    }
  );

  // the plugin outlet is not updated when the post instance is modified unless we register the new properties as
  // tracked
  api.addTrackedPostProperties(
    "detectedLang",
    "isTranslating",
    "isTranslated",
    "translatedText",
    "translatedTitle"
  );

  api.renderBeforeWrapperOutlet("post-menu", TranslatedPost);
}

export default {
  name: "extend-for-translate-button",
  initialize() {
    withPluginApi("1.39.2", (api) => initializeTranslation(api));
  },
};
