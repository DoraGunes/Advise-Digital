# Manual campaign workflows
Version 16.2.0+19. Generative AI and automated replies are not part of this workflow.

Research references:
- WhatsApp's official small-business ad guide describes media, audience, daily budget, review, and changing one variable at a time: https://whatsappbusiness.com/resources/resource-library/ads-that-click-to-whatsapp-smb-guide/
- Buffer separates saved drafts, dates, explicit queue approval, and performance review: https://support.buffer.com/en-us/articles/saving-and-scheduling-draft-posts-CBLXg1yFXp
- Meta's official SDK schemas list creative call_to_action and ad-set targeting fields: https://github.com/facebook/facebook-python-business-sdk

Implementation:
- Five configuration presets, not copy prompts or native Meta message templates.
- WhatsApp only, explicit area, 50–120 TRY daily per ad and 200 TRY account guard; PAUSED creation.
- No greeting, question flow, bot, message-template or automatic reply payload.
- Existing Instagram media is selected separately; a preset never publishes media.
- Device/account-scoped saved configurations survive restart.
- Requested 200 km radius must pass a read-only provider delivery estimate before any campaign write. No wider fallback. Supported area depends on the provider; UI allows explicitly selecting a different radius or provinces.
- A new backend capability is required for preset creation. Older production backends reject the client action before POST.
- Memory can fall back to authenticated GET posts on older servers, preserving own text/record history without fabricated paid metrics.

Deployment is separate. Release builds do not change .env, OAuth, runtime data, cron, or production code. APK currently uses the project's existing debug signing configuration, so it is a sideload test package, not a Play Store publication.
