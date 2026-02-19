-- Update: bold key awards lines in the shared OpenHouse template body

update public.email_templates
set
  body = 'Dear {{first_name}},\n\nI trust this message finds you well. I want to express our sincere gratitude for your presence at our recent Open House event.\n\nShould you have any further inquiries or require additional information, please don''t hesitate to reach out. Your feedback is crucial to us, and we look forward to the possibility of future partnerships.\n\nOnce again, thank you for making our Open House a success. We hope to have the pleasure of hosting you again at our upcoming events.\n\nPlease make sure to review the RECO Information Guide before your real estate agent provides any services or assistance.\n\nLink: https://www.reco.on.ca/about/plans-and-publications/reco-information-guide\n\nWe hope this guide will be helpful for you to gain insights and assistance as you seek real estate services.\n\nBest Regards\n\nMing Ren( 大鸣）\nBroker\n<b># 1 Realtor in Lake Wilcox Area & Top 1% Realtor in GTA*</b>\n<b># 1 Realtor in Re/Max Realtron Realty RH Branch(2020,2021,2022，2023，2024)</b>\n<b>Re/Max Diamond Award Winner</b>\n<b>Re/Max Chairman Award Winner</b>\n<b>Re/Max Hall of Fame Award Winner (位列Re/max 全球名人堂）</b>\nMulti-Channel Marketing Tools, Sell Your Property faster\nRe/Max Realtron Realty (运亨地产）\nCell: 647-779-9186\nBus：905-764-8688\nWeChat: 812298606\nEmail: MingRenRealty@gmail.com\nWebsite: www.MingRenRealty.ca\n老老实实做人，踏踏实实做事\nTrusted Professional, Diligent Work',
  updated_at = now()
where workspace = 'openhouse'
  and name = 'Open House模版'
  and is_archived = false;
