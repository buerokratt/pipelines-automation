#!/bin/bash

append=${1:-false}; [ "$append" = "true" ] && append=true || append=false

env_file=$(<release.env)

REMOTE_URL=$(git config --get remote.origin.url)

if [[ $REMOTE_URL == git@* ]]; then
    REPO_NAME=$(echo $REMOTE_URL | sed -E 's/git@([^:]+):(.*).git/\1\/\2/')
    REPO_URL="https://$REPO_NAME"
else
    REPO_URL=${REMOTE_URL%.git}
fi

current_branch="dev" #$(git branch --show-current)
current_version=""

# Get version based on current branch
found_branch=false
while IFS= read -r line; do
    if [ "$line" == "$current_branch" ]; then
        found_branch=true
    elif [ "$found_branch" == true ]; then
        if [[ "$line" == MAJOR=* || "$line" == MINOR=* || "$line" == PATCH=* ]]; then
            eval "$line"
        else
            break
        fi
    fi
done <<< "$env_file"

if [ "$found_branch" == true ]; then
    current_version="$MAJOR.$MINOR.$PATCH "
fi

# Prepare the changelog content
changelog_content=$(cat <<EOF
### $current_version($(date +"%d-%m-%Y"))
EOF
)

features=()
fixes=()
docs=()
styles=()
refactors=()
tests=()
chores=()
others=()

commit_log=$(git log --pretty=format:"%s by [<u>@%an</u>](https://www.github.com/) in [#%h]($REPO_URL/commit/%h)")

while read -r line; do
    pattern="^([^(:]+)\(([^)]+)\): (.*)"
    
    if [[ $line =~ $pattern ]]; then
        type="${BASH_REMATCH[1]}"
        scope="${BASH_REMATCH[2]}"
        description="${BASH_REMATCH[3]}"
        rest_of_line="**$scope**: $description"
    else
        type="others"
        rest_of_line="$line"
    fi

    case $type in  
        "feat") features+=("- $rest_of_line");;
        "fix")  fixes+=("- $rest_of_line");;
        "docs") docs+=("- $rest_of_line");;
        "style") styles+=("- $rest_of_line");;
        "refactor") refactors+=("- $rest_of_line");;
        "test") tests+=("- $rest_of_line");;
        "chore") chores+=("- $rest_of_line");;
        *) others+=("- $rest_of_line");;
    esac
done <<< "$commit_log"

[[ ${#features[@]} -gt 0 ]] && changelog_content+="\n## Features\n$(printf "%s\n" "${features[@]}")"
[[ ${#fixes[@]} -gt 0 ]] && changelog_content+="\n## Fixes\n$(printf "%s\n" "${fixes[@]}")"
[[ ${#docs[@]} -gt 0 ]] && changelog_content+="\n## Documentation\n$(printf "%s\n" "${docs[@]}")"
[[ ${#styles[@]} -gt 0 ]] && changelog_content+="\n## Style\n$(printf "%s\n" "${styles[@]}")"
[[ ${#refactors[@]} -gt 0 ]] && changelog_content+="\n## Refactor\n$(printf "%s\n" "${refactors[@]}")"
[[ ${#tests[@]} -gt 0 ]] && changelog_content+="\n## Tests\n$(printf "%s\n" "${tests[@]}")"
[[ ${#chores[@]} -gt 0 ]] && changelog_content+="\n## Chores\n$(printf "%s\n" "${chores[@]}")"
[[ ${#others[@]} -gt 0 ]] && changelog_content+="\n## Others\n$(printf "%s\n" "${others[@]}")"

# Append or overwrite the changelog file based on the append variable
if [ "$append" = "true" ]; then
    echo -e "$changelog_content" >> "CHANGELOG.md"
else
    echo -e "$changelog_content" > "CHANGELOG.md"
fi
