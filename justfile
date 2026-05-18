default:
    @just --list

# Report installed SaaS AI tools
tell-ai-tools:
    bash tell/tell_ai_tools.sh

# Report installed Homebrew casks
tell-casks:
    bash tell/tell_casks.sh

# Report shell RC files
tell-rcs:
    bash tell/tell_rcs.sh

# Report cloned skill repos under ~/skills
tell-skills:
    bash tell/tell_skills.sh

# Generate shell aliases for every installed Homebrew cask
generate-cask-aliases:
    bash generate/generate_cask-aliases.sh

# Wire up latest_release and git checkout release* intercept
install-checkout-release:
    bash install/install_checkout_release.sh
