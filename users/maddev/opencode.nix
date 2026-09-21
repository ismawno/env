{
  lib,
  pkgs-unstable,
  ...
}:

{
  home.packages = [ pkgs-unstable.opencode ];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";

    # No agent flag: flash at the API's default effort (high).
    model = "deepseek/deepseek-v4-flash";

    # options goes straight into the request body: v4-flash takes all efforts, v4-pro only high/max.
    agent = lib.mapAttrs (_: agent: { mode = "primary"; } // agent) {
      quick = {
        description = "Non-thinking flash. Cheapest and fastest; simple edits, lookups, boilerplate.";
        model = "deepseek/deepseek-v4-flash";
        options.thinking.type = "disabled";
      };

      think = {
        description = "Flash with light reasoning. Everyday work that needs a little planning.";
        model = "deepseek/deepseek-v4-flash";
        options.thinking = {
          type = "enabled";
          reasoning_effort = "low";
        };
      };

      deep = {
        description = "V4 Pro at maximum effort. Hard bugs, architecture, anything worth the tokens.";
        model = "deepseek/deepseek-v4-pro";
        options.thinking = {
          type = "enabled";
          reasoning_effort = "max";
        };
      };
    };
  };
}
