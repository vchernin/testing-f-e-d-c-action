#!/bin/bash

if [[ -z "$GITHUB_WORKSPACE" || -z "$GITHUB_REPOSITORY" ]]; then
    echo "Script is not running in GitHub Actions CI"
    exit 1
fi

if [[ -z "$1" ]]; then
    echo "Config file (e.g. flathub.json) not found, will not read from any config files present in repositories"
else
    config_file=$1
fi

if [[ -z "$2" ]]; then
    echo "GitHub organization mode setting not found, assuming updating only an individual repository"
else
    github_org_wide=$2
fi

detect_manifest() {
    repo=${1}
    
    # Todo whether run GitHub-org wide or for an individual repo, this should search for manifests recursively.
    # There is no guarantee it is in the root directory.
    
    # todo for some reason the dir above is always not the expected name, so hardcoding
    # the above suggestion should still fix this properly though
    
    # todo maybe just make the path a required input option...
    
    if [[ -f com.github.wwmm.easyeffects.yml ]]; then
        manifest=com.github.wwmm.easyeffects.yml
    elif [[ -f com.github.wwmm.easyeffects.yaml ]]; then
        manifest=com.github.wwmm.easyeffects.yaml
    elif [[ -f com.github.wwmm.easyeffects.json ]]; then
        manifest=com.github.wwmm.easyeffects.json
    else
        return 1
    fi

    echo $manifest
    
    # check if repo opted out
    # todo is this valid arg check?
    
    if [ -z ${config_file+x} ]; then 
        echo "config option is not defined"; 
    else 
        echo "config file should exist, attempting to read it"; 
        if [[ -f $config_file ]]; then
            if ! jq -e '."disable-external-data-checker" | not' < "$config_file" > /dev/null; then
                return 1
            fi
            if ! jq -e '."end-of-life" or ."end-of-life-rebase" | not' < "$config_file" > /dev/null; then
                return 1
            fi
            if ! jq -e '."require-important-update" | not' < "$config_file" > /dev/null; then
                require_important_update="--require-important-update"
            fi
            # todo this probably won't actually work yet, but is here for later
            if ! jq -e '."automerge-fedc-prs" | not' < "$config_file" > /dev/null; then
                automerge_fedc_prs="--automerge-fedc-prs"
            fi
        else
            echo "config file variable was set, but config file was not found"
        fi
    fi
}

git config --global user.name "$GIT_AUTHOR_NAME" && \
git config --global user.email "$GIT_AUTHOR_EMAIL"

if [ -z ${github_org_wide+x} ]; then 
    echo "GitHub organization mode variable is unset, assuming only need to edit individual current repo"; 
    checker_apps[0]=$(pwd)
else 
    echo "GitHub organization mode is being set, attempting to run for a GitHub organization" 
        
    # assumes the GitHub org follows the Flathub org's structute.
    # i.e., at github.com/$github_org_wide there will be several repos to check
    mkdir "$github_org_wide"
    cd "$github_org_wide"

    gh-ls-org "$github_org_wide" | parallel "git clone --depth 1 {}"
    mapfile -t checker_apps < <( grep -rl -E 'extra-data|x-checker-data|\.AppImage' | cut -d/ -f1 | sort -u )
fi

for repo in ${checker_apps[@]}; do
    manifest=$(detect_manifest "$repo")
    echo "manifest found is: " 
    echo "$manifest"
    if [[ -n $manifest ]]; then
        echo "==> checking ${repo}"
        /app/flatpak-external-data-checker --verbose "$require_important_update" "$automerge_fedc_prs" --update --never-fork "$manifest"
    fi
done
