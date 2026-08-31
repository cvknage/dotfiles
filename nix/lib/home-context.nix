let
  is = expected: config: config.home.sessionVariables.HOME_CONFIGURATION_CONTEXT == expected;
in {
  isPrivate = is "private";
  isWork = is "work";
}
