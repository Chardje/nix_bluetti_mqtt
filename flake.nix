{
  description = "Bluetti MQTT bridge NixOS module";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {

    packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        bluetti-mqtt = pkgs.python3Packages.buildPythonPackage {
          pname = "bluetti_mqtt";
          version = "0.16.1";
          src = ./.;
          pyproject = true;
          build-system = with pkgs.python3Packages; [
            setuptools
            wheel
          ];
          propagatedBuildInputs = with pkgs.python3Packages; [
            paho-mqtt
            bleak
          ];
          doCheck = false;  # ← додати
        };
        default = self.packages.${system}.bluetti-mqtt;
      }
    );

    nixosModules.bluetti-mqtt = { pkgs, ... }: {
      imports = [ ./modules/bluetti-mqtt.nix ];
      _module.args.bluetti-pkg = self.packages.${pkgs.system}.bluetti-mqtt;
    };
    nixosModules.default = self.nixosModules.bluetti-mqtt;
  };
}