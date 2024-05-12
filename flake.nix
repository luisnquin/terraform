{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    nixpkgs-terraform = {
      url = "github:stackbuilders/nixpkgs-terraform";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = "https://nixpkgs-terraform.cachix.org";
    extra-trusted-public-keys = "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
  };

  outputs = inputs:
    with inputs; let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in {
      devShells = let
        terraform-version = "1.8.1";
      in
        forEachSystem (
          system: let
            pkgs = import nixpkgs {
              overlays = [nixpkgs-terraform.overlays.default];
              config = {
                allowUnfree = true;
              };

              inherit system;
            };
          in {
            default = pkgs.mkShell {
              buildInputs = [
                pkgs.terraform-versions."${terraform-version}"
                pkgs.terraformer
                pkgs.tflint
              ];
            };
          }
        );
    };
}
