{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.vnc;
  xstartup = pkgs.writeScript "xstartup" ''
    #!/bin/sh
    . /etc/profile
    [ -x $HOME/.profile ] && . $HOME/.profile
    [ -r $HOME/.Xresources ] && ${pkgs.xorg.xrdb}/bin/xrdb $HOME/.Xresources
    ${pkgs.dbus}/bin/dbus-launch --exit-with-session ${cfg.startCmd}
  '';
  vnc_config = pkgs.writeText "config" ''
    localhost
    depth=24
    rfbport=${toString cfg.port}
  '';
in
{

  ###### interface

  options = {

    services.vnc = {

      enable = mkEnableOption "TigerVNC, the VNC server";

      package = mkOption {
        type = types.package;
        default = pkgs.tigervnc;
        defaultText = "pkgs.tigervnc";
        description = ''
          The package to use for the VNC daemon's binary.
        '';
      };

      port = mkOption {
        type = types.int;
        default = 5999;
        description = ''
          Specifies on which port VNC server listens.
        '';
      };

      display = mkOption {
        type = types.int;
        default = 99;
        description = ''
          Specifies display number.
        '';
      };

      startCmd = mkOption {
        type = types.str;
        default = "${pkgs.i3}/bin/i3";
        description = ''
          Desktop/window manager command.
        '';
      };

      password = mkOption {
        type = types.nullOr types.str;
        default = null;
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

      group = mkOption {
        type = types.str;
        description = ''
          VNC service group.
        '';
      };

    };
  };


  ###### implementation

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.xserver.enable = true;
    environment.etc."X11/Xsession".source = config.services.xserver.displayManager.sessionData.wrapper;
    system.activationScripts."vnc-init".text = ''
      mkdir -p /usr/share
      ln -sf ${config.services.xserver.displayManager.sessionData.desktops}/share/* /usr/share/
    '';

    systemd.services.vnc = {
        description = "vnc server";
        after = [ "network.target" ];
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          EnvironmentFile = builtins.toString (pkgs.writeText "vnc.env" ''
            LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
            LC_ALL="${cfg.locale}"
            LANG="${cfg.locale}"
            LANGUAGE="${cfg.locale}"
            PATH="${pkgs.coreutils}/bin:${pkgs.xorg.xinit}/bin:$PATH"
            XDG_DATA_DIRS="${config.services.xserver.displayManager.sessionData.desktops}/share"
            HOME=/var/lib/vnc
          '');
          ExecStartPre = builtins.toString (pkgs.writeScript "vnc-pre-start.sh" ''
            #!${pkgs.stdenv.shell}
            mkdir -p /var/lib/vnc
            ln -fs ${xstartup} /var/lib/vnc/xstartup
            ln -fs ${vnc_config} /var/lib/vnc/config
            ${optionalString (cfg.password != null) ''
              ${cfg.package}/bin/vncpasswd -f <<<"${cfg.password}" >"/var/lib/vnc/passwd"
              chmod 700 "/var/lib/vnc/passwd"
            ''}
          '');
          ExecStart = "${cfg.package}/bin/vncserver :${toString cfg.display}";
        };
    };
  };

}
