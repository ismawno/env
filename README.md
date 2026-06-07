# env
Imagine a tree house with different subhouses inside belonging to different people, with different subhouses inside belonging to different computers. This is our env project. A tree house for people sharing a common NixOS helper project, each with their own dotfiles and hardware configurations that make reproducing our efficient workspaces faster.

In this architecture:
*   **Users:** Administrative identities (e.g., `maddev`) who own specific environments. Configurations are located in `users/<username>/`.
*   **Hosts:** Specific hardware instances identified by their networking hostname. Each host has a dedicated directory in `hosts/<hostname>/` containing hardware-specific overrides like drivers, filesystem IDs, and bootloader themes.

---

## Installation and Setup

Follow these steps sequentially to integrate a new machine into the `env` project.

### 1. Initial NixOS Installation
Install NixOS on your hardware using an official image.
*   **Download:** [NixOS Official Releases](https://nixos.org/download.html)

### 2. Enable Minimum Requirements
Before cloning this project, you must prepare the base system. Edit `/etc/nixos/configuration.nix` to include the following:

*   `networking.hostName = "your-chosen-hostname";`
*   `programs.nano.enable = false;`
*   `programs.git.enable = true;`
*   `nix.settings.experimental-features = [ "nix-command" "flakes" ];`

Apply these changes and reboot:
```bash
sudo nixos-rebuild switch
reboot
```

### 3. Clone and Register
1.  Clone this repository to your home directory:
    ```bash
    git clone <repository-url> ~/env
    ```
2.  **CRITICAL:** Open `~/env/flake.nix`. You must register your machine and user here. Add your networking hostname to the `mkHost` calls and your username to the `mkHome` calls. Without this step, the flake will not recognize your configuration.

### 4. Configure Hardware (The Host Level)
You must now define the hardware specifics for your computer within the project structure.

1.  Identify your hardware IDs (LUKS, FileSystems) located in the auto-generated `/etc/nixos/hardware-configuration.nix`.
2.  Create a directory for your host: `~/env/hosts/<YOUR_NETWORKING_HOSTNAME>/`.
3.  Create a `configuration.nix` in that folder.
    *   *Recommendation:* Copy a template from an existing host in `~/env/hosts/*/configuration.nix`.
    *   *Action:* Tweak the `networking.hostName`, LUKS UUIDs, and filesystem IDs to match the ones you identified in step 1.
    *   *Overrides:* Add any specific hardware needs here (e.g., `services.xserver.videoDrivers = [ "nvidia" ];` or GRUB themes).

### 5. Configure User and Dotfiles
1.  Create your user profile: `~/env/users/<YOUR_USERNAME>/home.nix`.
2.  This file pulls settings from the `dotfiles/` directory. Create your own subdirectory within `dotfiles/` for your personal configurations.
3.  **Etiquette:**
    *   Folders created by others in the `dotfiles/` directory are **read-only**.
    *   Folders you create for yourself are **read-write**.

---

## Host and User Registry

| User | Associated Hosts |
| :--- | :--- |
| **ismawno** | `elder`, `nomad`, `razor` |
| **maddev** | `smalltop`, `bigsys` |
