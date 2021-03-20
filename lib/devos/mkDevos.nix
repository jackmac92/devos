{ self, nixos, inputs, ... }:
let
  devos = self;
in

{ self
, hosts ? "${self}/hosts"
, packages ? "${self}/pkgs"
, modules ? import "${self}/modules/module-list.nix"
, userModules ? import "${self}/users/modules/module-list.nix"
, suites ? import "${self}/suites"
, extern ? import "${self}/extern"
, overlays ? "${self}/overlays"
, overrides ? import "${self}/overrides"
, users ? "${self}/users"
, profiles ? "${self}/profiles"
, userProfiles ? "${self}/users/profiles"
, ...
}:
let
  inherit (self) lib;
  inherit (lib) os;

  inherit (inputs) utils deploy;

  external = extern { inherit inputs; };

  multiPkgs = os.mkPkgs { inherit overrides; extern = external; };

  allSuites = os.mkSuites { inherit users profiles userProfiles suites; };

  outputs = {
    nixosConfigurations = os.mkHosts {
      inherit multiPkgs overrides;
      extern = external;
      suites = allSuites;
      dir = hosts;
    };

    homeConfigurations = os.mkHomeConfigurations;

    nixosModules = lib.pathsToImportedAttrs modules;

    homeModules = lib.pathsToImportedAttrs userModules;

    overlay = import packages;
    overlays = lib.pathsToImportedAttrs (lib.pathsIn overlays);

    lib = import "${devos}/lib" { inherit self nixos inputs; };

    templates.flk = {
      path = builtins.toPath self;
      description = "flk template";
    };
      /*mkdevos =
        # Folders that aren't necessary with mkDevos method
        let excludes = [ "lib" "tests" "nix" ]; in
        {
          path = builtins.filterSource (f: ! (builtins.elem f excludes)) self;
          description = "template used for mkdevos";
        }; */
    defaultTemplate = self.templates.flk;

    deploy.nodes = os.mkNodes deploy self.nixosConfigurations;
  };

  systemOutputs = utils.lib.eachDefaultSystem (system:
    let pkgs = multiPkgs.${system}; in
    {
      checks =
        let
          tests = nixos.lib.optionalAttrs (system == "x86_64-linux")
            (import "${devos}/tests" { inherit self pkgs; });
          deployHosts = nixos.lib.filterAttrs
            (n: _: self.nixosConfigurations.${n}.config.nixpkgs.system == system) self.deploy.nodes;
          deployChecks = deploy.lib.${system}.deployChecks { nodes = deployHosts; };
        in
        nixos.lib.recursiveUpdate tests deployChecks;

      packages = utils.lib.flattenTreeSystem system
        (os.mkPackages { inherit pkgs; });

      devShell = import "${devos}/shell" {
        inherit self pkgs system;
      };
    });
in
 nixos.lib.recursiveUpdate outputs systemOutputs

