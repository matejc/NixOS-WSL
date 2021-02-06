{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.vnc;
  vnc_config = pkgs.writeText "config" ''
    localhost
    depth=24
  '';
  runvncserver = builtins.fetchGit {
    url = git://github.com/sebestyenistvan/runvncserver;
  };
  vnc_passwd = pkgs.runCommand "" {
    buildInputs = [ cfg.package ];
  } ''
    vncpasswd -f <<<"${cfg.password}" >$out
  '';
  xsessionrc = pkgs.writeScript "xsessionrc" ''
    export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
    export LC_ALL="${cfg.locale}"
    export LANG="${cfg.locale}"
    export LANGUAGE="${cfg.locale}"
    ${runvncserver}/startvnc start >/dev/null 2>&1
  '';
in
{

  ###### interface

  options = {

    programs.vnc = {

      enable = mkEnableOption "TigerVNC, the VNC server";

      package = mkOption {
        type = types.package;
        default = pkgs.tigervnc;
        defaultText = "pkgs.tigervnc";
        description = ''
          The package to use for the VNC daemon's binary.
        '';
      };

      password = mkOption {
        type = types.str;
        description = ''
          VNC password.
        '';
      };

      locale = mkOption {
        type = types.str;
        default = "en_US.UTF-8";
        description = ''
          VNC Locale.
        '';
      };

      user = mkOption {
        type = types.str;
        description = ''
          VNC service user.
        '';
      };
    };
  };


  ###### implementation

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".vnc/passwd".source = "${vnc_passwd}";
    home.file.".vnc/config".source = "${vnc_config}";
    home.file.".xsessionrc".source = "${xsessionrc}";
  };

}
