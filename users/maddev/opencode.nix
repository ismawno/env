{
  pkgs-unstable,
  ...
}:

# DEEPSEEK_API_KEY and the aliases come from dotfiles/shub/zsh/.zshrc.
#
# `options` is passed straight into the request body:
#   thinking.type             "enabled" | "disabled"   (default enabled)
#   thinking.reasoning_effort "low" | "high" | "max"   (default high)
# v4-flash takes all three efforts; v4-pro only "high" and "max".

{
  home.packages = [ pkgs-unstable.opencode ];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";

    # No agent flag: flash at the API's default effort (high).
    model = "deepseek/deepseek-v4-flash";

    agent = {
      quick = {
        description = "Non-thinking flash. Cheapest and fastest; simple edits, lookups, boilerplate.";
        mode = "primary";
        model = "deepseek/deepseek-v4-flash";
        options.thinking.type = "disabled";
      };

      think = {
        description = "Flash with light reasoning. Everyday work that needs a little planning.";
        mode = "primary";
        model = "deepseek/deepseek-v4-flash";
        options.thinking = {
          type = "enabled";
          reasoning_effort = "low";
        };
      };

      deep = {
        description = "V4 Pro at maximum effort. Hard bugs, architecture, anything worth the tokens.";
        mode = "primary";
        model = "deepseek/deepseek-v4-pro";
        options.thinking = {
          type = "enabled";
          reasoning_effort = "max";
        };
      };
    };
  };
}
