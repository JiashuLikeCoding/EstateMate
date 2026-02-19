-- Update the shared/default OpenHouse template (per-user rows)
-- Rename to "Open House模版" and update subject/body as requested.

update public.email_templates
set
  name = 'Open House模版',
  subject = 'Thank you for attending our Open House event at {{address}}',
  body = 'Dear {{first_name}}, I trust this message finds you well. I want to express our sincere gratitude for your presence at our recent Open House event. Should you have any further inquiries or require additional information, please don''t hesitate to reach out. Your feedback is crucial to us, and we look forward to the possibility of future partnerships. Once again, thank you for making our Open House a success. We hope to have the pleasure of hosting you again at our upcoming events. Please make sure to review the RECO Information Guide before your real estate agent provides any services or assistance. Link: https://www.reco.on.ca/about/plans-and-publications/reco-information-guide We hope this guide will be helpful for you to gain insights and assistance as you seek real estate services. Best Regards Ming Ren( 大鸣） Broker # 1 Realtor in Lake Wilcox Area & Top 1% Realtor in GTA* # 1 Realtor in Re/Max Realtron Realty RH Branch(2020,2021,2022) Re/Max Diamond Award Winner Re/Max Chairman Award Winner Re/Max Hall of Fame Award Winner (位列Re/max 全球名人堂） Multi-Channel Marketing Tools, Sell Your Property faster Re/Max Realtron Realty (运亨地产） Cell: 647-779-9186 Bus：905-764-8688 WeChat: 812298606 Email: MingRenRealty@gmail.com Website: www.MingRenRealty.ca 老老实实做人，踏踏实实做事 Trusted Professional, Diligent Work',
  from_name = case
    when coalesce(trim(from_name), '') = '' then 'Ming Ren Realty'
    else from_name
  end,
  updated_at = now()
where workspace = 'openhouse'
  and name in ('Open House', 'Open House模版')
  and is_archived = false;
