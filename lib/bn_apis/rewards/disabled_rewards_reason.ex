defmodule BnApis.Rewards.DisabledRewardsReasons do
  @disabled_rewards_reasons [
    "Project active on SV rewards",
    "Project is active only for Invoicing/Advance Brokerage",
    "Project sold out",
    "4BN service pricing Issue",
    "Wallet recharge in discussion with Developer",
    "4BN decided to discontinue",
    "Project mandate given to another company",
    "Developer unhappy with services",
    "Other"
  ]

  def get_all_reasons() do
    @disabled_rewards_reasons
  end
end
